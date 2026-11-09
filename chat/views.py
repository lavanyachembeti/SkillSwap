from datetime import timedelta
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status

from .models import Conversation, Message, MessagingPolicy, UserMessagingRestriction
from .serializers import ConversationSerializer, MessageSerializer
from accounts.models import User
from requests.models import SkillRequest


class ConversationListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        conversations = Conversation.objects.filter(
            Q(user1=request.user) | Q(user2=request.user)
        ).select_related('user1', 'user2', 'skill_request').order_by('-updated_at')

        serializer = ConversationSerializer(
            conversations,
            many=True
        )

        return Response(serializer.data)

    def post(self, request):
        other_user_id = request.data.get('user_id')

        if not other_user_id:
            return Response(
                {'error': 'user_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            other_user = User.objects.get(
                id=other_user_id,
                is_active=True
            )
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        if other_user.id == request.user.id:
            return Response(
                {'error': 'You cannot create a conversation with yourself'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check if conversation already exists (preserve legacy conversations)
        conversation = Conversation.objects.filter(
            (Q(user1=request.user, user2=other_user) |
             Q(user1=other_user, user2=request.user))
        ).first()

        accepted_request = SkillRequest.objects.filter(
            (Q(requester=request.user, target=other_user) |
             Q(requester=other_user, target=request.user)),
            status='accepted'
        ).order_by('-updated_at').first()

        if conversation:
            # Link accepted request if not linked yet
            if accepted_request and not conversation.skill_request_id:
                conversation.skill_request = accepted_request
                conversation.save(update_fields=['skill_request'])
            return Response(
                ConversationSerializer(conversation).data,
                status=status.HTTP_201_CREATED
            )

        # Only accepted skill-swap participants (or admins if policy allows) can start new conversations
        policy = MessagingPolicy.get_policy()
        if policy.enforce_accepted_request and not accepted_request and not request.user.is_administrator:
            return Response(
                {
                    'error': 'Only participants with an accepted skill-swap request can start a new conversation.'
                },
                status=status.HTTP_403_FORBIDDEN
            )

        conversation = Conversation.objects.create(
            user1=request.user,
            user2=other_user,
            skill_request=accepted_request
        )

        return Response(
            ConversationSerializer(conversation).data,
            status=status.HTTP_201_CREATED
        )


class ConversationMessagesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, conversation_id):
        try:
            conversation = Conversation.objects.select_related('user1', 'user2', 'skill_request').get(
                id=conversation_id
            )
        except Conversation.DoesNotExist:
            return Response(
                {'error': 'Conversation not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        if request.user.id not in [
            conversation.user1_id,
            conversation.user2_id
        ]:
            return Response(
                {'error': 'You are not part of this conversation'},
                status=status.HTTP_403_FORBIDDEN
            )

        messages = Message.objects.filter(
            conversation=conversation
        ).select_related('sender').order_by('created_at')

        serializer = MessageSerializer(
            messages,
            many=True
        )

        return Response(serializer.data)

    def post(self, request, conversation_id):
        try:
            conversation = Conversation.objects.select_related('user1', 'user2', 'skill_request').get(
                id=conversation_id
            )
        except Conversation.DoesNotExist:
            return Response(
                {'error': 'Conversation not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        if request.user.id not in [
            conversation.user1_id,
            conversation.user2_id
        ]:
            return Response(
                {'error': 'You are not part of this conversation'},
                status=status.HTTP_403_FORBIDDEN
            )

        if conversation.is_locked:
            return Response(
                {'error': 'This conversation has been restricted by an administrator.'},
                status=status.HTTP_403_FORBIDDEN
            )

        policy = MessagingPolicy.get_policy()

        # Legacy conversations without an accepted request are read-only unless explicitly authorized by an administrator
        if policy.enforce_accepted_request and not conversation.can_send_messages:
            return Response(
                {
                    'error': 'This legacy conversation is read-only because there is no accepted skill-swap request. An administrator must authorize messaging or a skill-swap request must be accepted.'
                },
                status=status.HTTP_403_FORBIDDEN
            )

        serializer = MessageSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                serializer.errors,
                status=status.HTTP_400_BAD_REQUEST
            )

        # Enforce quotas safely under row-level lock on sender to prevent concurrent race conditions
        with transaction.atomic():
            locked_user = User.objects.select_for_update().get(pk=request.user.id)
            now = timezone.now()

            # Auto-expire any elapsed restrictions for this user
            UserMessagingRestriction.objects.filter(
                user=locked_user,
                is_active=True,
                expires_at__lte=now
            ).update(is_active=False)

            # Check active restriction/cooldown
            active_restriction = UserMessagingRestriction.objects.filter(
                user=locked_user,
                is_active=True
            ).filter(
                Q(conversation__isnull=True) | Q(conversation=conversation)
            ).filter(
                Q(expires_at__isnull=True) | Q(expires_at__gt=now)
            ).first()

            if active_restriction:
                return Response(
                    {
                        'error': 'Messaging is temporarily restricted due to rate-limit cooldown or moderation policy.',
                        'reason': active_restriction.reason,
                        'restriction_type': active_restriction.restriction_type,
                        'cooldown_expires_at': active_restriction.expires_at,
                    },
                    status=status.HTTP_429_TOO_MANY_REQUESTS
                )

            warning_msg = None
            quota_usage = {}

            if policy.enable_rate_limiting:
                one_min_ago = now - timedelta(minutes=1)
                day_ago = now - timedelta(days=1)

                msgs_last_minute = Message.objects.filter(
                    sender=locked_user,
                    created_at__gte=one_min_ago
                ).count()

                if msgs_last_minute >= policy.max_messages_per_minute:
                    expires_at = now + timedelta(minutes=policy.cooldown_minutes)
                    UserMessagingRestriction.objects.create(
                        user=locked_user,
                        conversation=conversation,
                        restriction_type='cooldown',
                        reason=f'Exceeded maximum messages per minute ({policy.max_messages_per_minute}/min). Temporary {policy.cooldown_minutes}-minute cooldown applied.',
                        is_active=True,
                        expires_at=expires_at,
                    )
                    return Response(
                        {
                            'error': f'Rate limit exceeded ({policy.max_messages_per_minute} messages/minute). A temporary {policy.cooldown_minutes}-minute cooldown has been applied.',
                            'cooldown_minutes': policy.cooldown_minutes,
                            'cooldown_expires_at': expires_at,
                        },
                        status=status.HTTP_429_TOO_MANY_REQUESTS
                    )

                msgs_conv_today = Message.objects.filter(
                    conversation=conversation,
                    created_at__gte=day_ago
                ).count()

                if msgs_conv_today >= policy.max_messages_per_conversation_per_day:
                    return Response(
                        {
                            'error': f'Daily conversation message limit ({policy.max_messages_per_conversation_per_day} messages/day) reached.',
                        },
                        status=status.HTTP_429_TOO_MANY_REQUESTS
                    )

                msgs_user_today = Message.objects.filter(
                    sender=locked_user,
                    created_at__gte=day_ago
                ).count()

                if msgs_user_today >= policy.max_messages_per_user_per_day:
                    return Response(
                        {
                            'error': f'Daily user message limit ({policy.max_messages_per_user_per_day} messages/day) reached.',
                        },
                        status=status.HTTP_429_TOO_MANY_REQUESTS
                    )

                # Calculate after-send counts for warning threshold check
                new_min_count = msgs_last_minute + 1
                new_conv_count = msgs_conv_today + 1
                new_user_count = msgs_user_today + 1

                threshold_ratio = policy.warning_threshold_percent / 100.0
                warnings = []
                if policy.max_messages_per_minute > 0 and (new_min_count / policy.max_messages_per_minute) >= threshold_ratio:
                    warnings.append(f'{new_min_count}/{policy.max_messages_per_minute} messages per minute')
                if policy.max_messages_per_conversation_per_day > 0 and (new_conv_count / policy.max_messages_per_conversation_per_day) >= threshold_ratio:
                    warnings.append(f'{new_conv_count}/{policy.max_messages_per_conversation_per_day} messages in this conversation today')
                if policy.max_messages_per_user_per_day > 0 and (new_user_count / policy.max_messages_per_user_per_day) >= threshold_ratio:
                    warnings.append(f'{new_user_count}/{policy.max_messages_per_user_per_day} total messages today')

                if warnings:
                    warning_msg = f"Approaching messaging quota ({policy.warning_threshold_percent}% threshold): " + ", ".join(warnings)

                quota_usage = {
                    'minute_used': new_min_count,
                    'minute_limit': policy.max_messages_per_minute,
                    'conversation_day_used': new_conv_count,
                    'conversation_day_limit': policy.max_messages_per_conversation_per_day,
                    'user_day_used': new_user_count,
                    'user_day_limit': policy.max_messages_per_user_per_day,
                }

            message = serializer.save(
                conversation=conversation,
                sender=locked_user
            )
            conversation.save(update_fields=['updated_at'])

        response_data = dict(MessageSerializer(message).data)
        if warning_msg:
            response_data['warning'] = warning_msg
        if quota_usage:
            response_data['quota_usage'] = quota_usage

        return Response(
            response_data,
            status=status.HTTP_201_CREATED
        )
