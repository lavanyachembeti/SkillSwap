from datetime import timedelta
import json
from urllib.parse import parse_qs

from channels.auth import AuthMiddlewareStack
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.contrib.auth.models import AnonymousUser
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import AccessToken

from accounts.models import Notification, User
from .models import Conversation, Message, MessagingPolicy, UserMessagingRestriction


@database_sync_to_async
def get_user_from_jwt(raw_token: str):
    """Validate a SimpleJWT access token and return an active, non-suspended User or AnonymousUser."""
    try:
        validated_token = AccessToken(raw_token)
        user_id = validated_token.get('user_id')
        if not user_id:
            return AnonymousUser()
        user = User.objects.filter(pk=user_id, is_active=True).first()
        if not user or user.is_suspended:
            return AnonymousUser()
        return user
    except (InvalidToken, TokenError, Exception):
        return AnonymousUser()


class JWTWebSocketAuthMiddleware:
    """
    ASGI middleware that authenticates WebSocket connections via:
    1. `Authorization: Bearer <token>` header, or
    2. `?token=<token>` query parameter, or
    3. Pre-authenticated `scope['user']` / Django session via AuthMiddlewareStack.
    """

    def __init__(self, inner):
        self.inner = inner
        self.session_auth = AuthMiddlewareStack(inner)

    async def __call__(self, scope, receive, send):
        headers = dict(scope.get('headers') or [])
        token_credential_supplied = False
        raw_token = None

        if b'authorization' in headers:
            auth_header = headers.get(b'authorization', b'').decode('utf-8', errors='ignore').strip()
            if auth_header.lower().startswith('bearer'):
                token_credential_supplied = True
                raw_token = auth_header[6:].strip()
            elif auth_header:
                # Non-empty authorization header with unsupported scheme
                token_credential_supplied = True
                raw_token = ''

        if not token_credential_supplied:
            query_string = (scope.get('query_string') or b'').decode('utf-8', errors='ignore')
            query_params = parse_qs(query_string, keep_blank_values=True)
            if 'token' in query_params:
                token_credential_supplied = True
                token_list = query_params.get('token') or ['']
                raw_token = token_list[0].strip()

        if token_credential_supplied:
            scope = dict(scope)
            if not raw_token:
                scope['user'] = AnonymousUser()
            else:
                scope['user'] = await get_user_from_jwt(raw_token)
            return await self.inner(scope, receive, send)

        existing_user = scope.get('user')
        if existing_user is not None and getattr(existing_user, 'is_authenticated', False):
            return await self.inner(scope, receive, send)

        return await self.session_auth(scope, receive, send)


class ChatConsumer(AsyncWebsocketConsumer):

    async def connect(self):
        self.room_group_name = None
        self.user = None
        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']

        scope_user = self.scope.get('user')
        auth_status, db_user = await self.authorize_connection(scope_user, self.conversation_id)

        if auth_status != 'ok':
            close_code = 4001 if auth_status == 'unauthenticated' else 4003
            await self.close(code=close_code)
            return

        self.user = db_user
        self.room_group_name = f'chat_{self.conversation_id}'

        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name,
        )

        await self.accept()

    async def disconnect(self, close_code):
        if getattr(self, 'room_group_name', None) and self.channel_layer is not None:
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name,
            )

    async def receive(self, text_data=None, bytes_data=None):
        if not getattr(self, 'user', None) or not getattr(self.user, 'is_authenticated', False):
            await self.close(code=4001)
            return

        if not text_data:
            return

        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            await self.send(text_data=json.dumps({'error': 'Invalid JSON payload.'}))
            return

        if not isinstance(data, dict):
            await self.send(text_data=json.dumps({'error': 'Invalid message format.'}))
            return

        raw_message = data.get('message')
        message_text = raw_message.strip() if isinstance(raw_message, str) else ''

        if not message_text:
            return

        # Sender identity is strictly bound to the authenticated WebSocket user (self.user.id).
        # Client-supplied sender/sender_id/user_id fields are ignored to prevent spoofing.
        result = await self.save_message(self.user.id, message_text)

        if not result.get('ok'):
            await self.send(
                text_data=json.dumps({
                    'error': result.get('error', 'Unable to send message.'),
                })
            )
            return

        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',
                'message': message_text,
                'sender_id': result['sender_id'],
                'sender_username': result['sender_username'],
            },
        )

        # Send notification to the other participant
        await self.create_message_notification(
            result['receiver_id'],
            result['sender_username'],
        )

    async def chat_message(self, event):
        payload = {
            'message': event['message'],
        }
        if 'sender_id' in event:
            payload['sender_id'] = event['sender_id']
        if 'sender_username' in event:
            payload['sender_username'] = event['sender_username']
        await self.send(text_data=json.dumps(payload))

    @database_sync_to_async
    def authorize_connection(self, scope_user, conversation_id):
        if not scope_user or not getattr(scope_user, 'is_authenticated', False):
            return 'unauthenticated', None

        db_user = User.objects.filter(pk=scope_user.pk, is_active=True).first()
        if not db_user or db_user.is_suspended:
            return 'unauthenticated', None

        conversation = Conversation.objects.filter(pk=conversation_id).first()
        if not conversation:
            return 'not_found', None

        if db_user.id not in (conversation.user1_id, conversation.user2_id):
            return 'forbidden', None

        return 'ok', db_user

    @database_sync_to_async
    def save_message(self, authenticated_user_id: int, message_text: str):
        conversation = Conversation.objects.select_related(
            'user1', 'user2', 'skill_request'
        ).filter(id=self.conversation_id).first()

        if not conversation:
            return {'ok': False, 'error': 'Conversation not found.'}

        if authenticated_user_id not in (conversation.user1_id, conversation.user2_id):
            return {'ok': False, 'error': 'You are not part of this conversation.'}

        if conversation.is_locked:
            return {
                'ok': False,
                'error': 'This conversation has been restricted by an administrator.',
            }

        policy = MessagingPolicy.get_policy()
        if policy.enforce_accepted_request and not conversation.can_send_messages:
            return {
                'ok': False,
                'error': (
                    'This legacy conversation is read-only because there is no accepted '
                    'skill-swap request. An administrator must authorize messaging or a '
                    'skill-swap request must be accepted.'
                ),
            }

        with transaction.atomic():
            locked_user = User.objects.select_for_update().filter(
                pk=authenticated_user_id,
                is_active=True,
            ).first()

            if not locked_user or locked_user.is_suspended:
                return {'ok': False, 'error': 'Account is inactive or suspended.'}

            now = timezone.now()

            # Auto-expire elapsed restrictions for this user
            UserMessagingRestriction.objects.filter(
                user=locked_user,
                is_active=True,
                expires_at__lte=now,
            ).update(is_active=False)

            # Check active restriction or cooldown
            active_restriction = (
                UserMessagingRestriction.objects.filter(
                    user=locked_user,
                    is_active=True,
                )
                .filter(Q(conversation__isnull=True) | Q(conversation=conversation))
                .filter(Q(expires_at__isnull=True) | Q(expires_at__gt=now))
                .first()
            )

            if active_restriction:
                return {
                    'ok': False,
                    'error': 'Messaging is temporarily restricted due to rate-limit cooldown or moderation policy.',
                }

            if policy.enable_rate_limiting:
                one_min_ago = now - timedelta(minutes=1)
                day_ago = now - timedelta(days=1)

                msgs_last_minute = Message.objects.filter(
                    sender=locked_user,
                    created_at__gte=one_min_ago,
                ).count()

                if msgs_last_minute >= policy.max_messages_per_minute:
                    expires_at = now + timedelta(minutes=policy.cooldown_minutes)
                    UserMessagingRestriction.objects.create(
                        user=locked_user,
                        conversation=conversation,
                        restriction_type='cooldown',
                        reason=(
                            f'Exceeded maximum messages per minute ({policy.max_messages_per_minute}/min). '
                            f'Temporary {policy.cooldown_minutes}-minute cooldown applied.'
                        ),
                        is_active=True,
                        expires_at=expires_at,
                    )
                    return {
                        'ok': False,
                        'error': (
                            f'Rate limit exceeded ({policy.max_messages_per_minute} messages/minute). '
                            f'A temporary {policy.cooldown_minutes}-minute cooldown has been applied.'
                        ),
                    }

                msgs_conv_today = Message.objects.filter(
                    conversation=conversation,
                    created_at__gte=day_ago,
                ).count()

                if msgs_conv_today >= policy.max_messages_per_conversation_per_day:
                    return {
                        'ok': False,
                        'error': (
                            f'Daily conversation message limit '
                            f'({policy.max_messages_per_conversation_per_day} messages/day) reached.'
                        ),
                    }

                msgs_user_today = Message.objects.filter(
                    sender=locked_user,
                    created_at__gte=day_ago,
                ).count()

                if msgs_user_today >= policy.max_messages_per_user_per_day:
                    return {
                        'ok': False,
                        'error': (
                            f'Daily user message limit '
                            f'({policy.max_messages_per_user_per_day} messages/day) reached.'
                        ),
                    }

            # Strictly use the authenticated user as sender; never trust client input
            sender = locked_user
            if sender.id == conversation.user1_id:
                receiver = conversation.user2
            else:
                receiver = conversation.user1

            message = Message.objects.create(
                conversation=conversation,
                sender=sender,
                message=message_text,
            )
            conversation.save(update_fields=['updated_at'])

        return {
            'ok': True,
            'message_id': message.id,
            'sender_id': sender.id,
            'sender_username': sender.username,
            'receiver_id': receiver.id,
        }

    @database_sync_to_async
    def create_message_notification(self, receiver_id, sender_username):
        Notification.objects.create(
            user_id=receiver_id,
            notification_type='new_message',
            title='New Message',
            message=f'{sender_username} sent you a new message.',
        )
