from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from django.db import IntegrityError
from django.db.models import Q

from .models import SkillRequest
from .serializers import SkillRequestSerializer
from discovery.models import UserBlock
from accounts.models import Notification
from chat.models import Conversation


class SkillRequestListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        sent = SkillRequest.objects.filter(
            requester=request.user
        )

        received = SkillRequest.objects.filter(
            target=request.user
        )

        return Response({
            'sent': SkillRequestSerializer(
                sent,
                many=True
            ).data,
            'received': SkillRequestSerializer(
                received,
                many=True
            ).data,
        })

    def post(self, request):
        serializer = SkillRequestSerializer(
            data=request.data
        )

        if serializer.is_valid():
            target_user = serializer.validated_data['target']

            # Check whether either user has blocked the other
            if UserBlock.objects.filter(
                blocker=request.user,
                blocked_user=target_user
            ).exists() or UserBlock.objects.filter(
                blocker=target_user,
                blocked_user=request.user
            ).exists():

                return Response(
                    {
                        'error': 'You cannot send a skill request to this user.'
                    },
                    status=status.HTTP_403_FORBIDDEN
                )

            # Create skill request
            skill_request = serializer.save(
                requester=request.user
            )

            # Notify target user
            Notification.objects.create(
                user=target_user,
                notification_type='skill_request',
                title='New Skill Request',
                message=f'{request.user.username} sent you a skill request.'
            )

            return Response(
                SkillRequestSerializer(
                    skill_request
                ).data,
                status=status.HTTP_201_CREATED
            )

        return Response(
            serializer.errors,
            status=status.HTTP_400_BAD_REQUEST
        )


class SkillRequestActionView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request, pk):
        try:
            skill_request = SkillRequest.objects.get(
                id=pk,
                target=request.user
            )

        except SkillRequest.DoesNotExist:
            return Response(
                {'error': 'Request not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        new_status = request.data.get('status')

        if new_status not in ['accepted', 'rejected']:
            return Response(
                {
                    'error': 'Status must be accepted or rejected'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if skill_request.status != 'pending':
            return Response(
                {
                    'error': 'Only pending requests can be updated'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Update request status
        skill_request.status = new_status
        skill_request.save()

        # Notify requester and ensure conversation exists
        if new_status == 'accepted':
            # Create or get existing conversation between requester and target
            # Handling both user orderings safely to prevent duplicate conversations
            u1 = skill_request.requester
            u2 = skill_request.target
            conversation = Conversation.objects.filter(
                (Q(user1=u1, user2=u2) | Q(user1=u2, user2=u1))
            ).first()

            if not conversation:
                try:
                    conversation = Conversation.objects.create(
                        user1=u1,
                        user2=u2,
                        skill_request=skill_request
                    )
                except IntegrityError:
                    conversation = Conversation.objects.filter(
                        (Q(user1=u1, user2=u2) | Q(user1=u2, user2=u1))
                    ).first()

            if conversation and conversation.skill_request_id != skill_request.id:
                conversation.skill_request = skill_request
                conversation.save(update_fields=['skill_request'])

            Notification.objects.create(
                user=skill_request.requester,
                notification_type='request_accepted',
                title='Skill Request Accepted',
                message=(
                    f'{request.user.username} accepted '
                    'your skill request.'
                )
            )

        elif new_status == 'rejected':

            Notification.objects.create(
                user=skill_request.requester,
                notification_type='request_rejected',
                title='Skill Request Rejected',
                message=(
                    f'{request.user.username} rejected '
                    'your skill request.'
                )
            )

        return Response(
            SkillRequestSerializer(
                skill_request
            ).data,
            status=status.HTTP_200_OK
        )
