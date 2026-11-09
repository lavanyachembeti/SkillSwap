from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import AdminAuditLog, User
from chat.models import Conversation, Message, MessagingPolicy, UserMessagingRestriction
from requests.models import SkillRequest
from skills.models import Skill


class ChatAuthorizationAndPolicyTests(APITestCase):
    def setUp(self):
        self.admin_user = User.objects.create_user(
            username='chat_admin',
            email='chat_admin@example.com',
            password='Password123!',
            role='admin',
            is_staff=True,
        )
        self.user_a = User.objects.create_user(
            username='alice_chat',
            email='alice_chat@example.com',
            password='Password123!',
            role='student',
        )
        self.user_b = User.objects.create_user(
            username='bob_chat',
            email='bob_chat@example.com',
            password='Password123!',
            role='professional',
        )
        self.user_c = User.objects.create_user(
            username='charlie_chat',
            email='charlie_chat@example.com',
            password='Password123!',
            role='student',
        )
        self.skill = Skill.objects.create(
            name='Flutter Development',
            category='Mobile',
        )
        self.conversations_url = reverse('conversation-list-create')

    def test_cannot_start_new_conversation_without_accepted_request(self):
        self.client.force_authenticate(user=self.user_a)
        resp = self.client.post(self.conversations_url, {'user_id': self.user_b.id}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(Conversation.objects.count(), 0)

        # Even with pending request, new conversation cannot be created
        req = SkillRequest.objects.create(
            requester=self.user_a,
            target=self.user_b,
            requested_skill=self.skill,
            status='pending',
        )
        resp_pending = self.client.post(self.conversations_url, {'user_id': self.user_b.id}, format='json')
        self.assertEqual(resp_pending.status_code, status.HTTP_403_FORBIDDEN)

        # Once accepted, conversation can be started and messages can be sent
        req.status = 'accepted'
        req.save(update_fields=['status'])

        resp_accepted = self.client.post(self.conversations_url, {'user_id': self.user_b.id}, format='json')
        self.assertEqual(resp_accepted.status_code, status.HTTP_201_CREATED)
        conv_id = resp_accepted.data['id']
        self.assertTrue(resp_accepted.data['can_send_messages'])
        self.assertEqual(resp_accepted.data['conversation_status'], 'active')

        msg_url = reverse('conversation-messages', kwargs={'conversation_id': conv_id})
        send_resp = self.client.post(msg_url, {'message': 'Hi Bob! Ready to start?'}, format='json')
        self.assertEqual(send_resp.status_code, status.HTTP_201_CREATED)

    def test_legacy_conversation_is_preserved_and_read_only_until_authorized(self):
        # Create a legacy conversation without an accepted SkillRequest
        legacy_conv = Conversation.objects.create(user1=self.user_a, user2=self.user_c)
        Message.objects.create(
            conversation=legacy_conv,
            sender=self.user_a,
            message='Legacy message from earlier session',
        )

        self.client.force_authenticate(user=self.user_a)

        # Legacy message history is preserved and readable by participants
        msg_url = reverse('conversation-messages', kwargs={'conversation_id': legacy_conv.id})
        get_resp = self.client.get(msg_url)
        self.assertEqual(get_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(get_resp.data), 1)
        self.assertEqual(get_resp.data[0]['message'], 'Legacy message from earlier session')

        # Sending a new message in an unauthorized legacy conversation is blocked (read-only)
        post_resp = self.client.post(msg_url, {'message': 'Trying to send in legacy chat'}, format='json')
        self.assertEqual(post_resp.status_code, status.HTTP_403_FORBIDDEN)

        # Admin explicitly authorizes the legacy conversation
        self.client.force_authenticate(user=self.admin_user)
        status_url = reverse('admin-conversation-status', kwargs={'pk': legacy_conv.id})
        auth_resp = self.client.post(status_url, {
            'action': 'authorize_legacy',
            'reason': 'Verified legacy mentoring pair',
        }, format='json')
        self.assertEqual(auth_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(auth_resp.data['conversation']['admin_authorized'])
        self.assertEqual(auth_resp.data['conversation']['conversation_status'], 'authorized_legacy')

        # Now participant can send messages in the authorized legacy conversation
        self.client.force_authenticate(user=self.user_a)
        post_after_auth = self.client.post(msg_url, {'message': 'Thanks admin for authorizing!'}, format='json')
        self.assertEqual(post_after_auth.status_code, status.HTTP_201_CREATED)

    def test_unauthorized_user_cannot_read_or_send_messages(self):
        req = SkillRequest.objects.create(
            requester=self.user_a,
            target=self.user_b,
            requested_skill=self.skill,
            status='accepted',
        )
        conv = Conversation.objects.create(
            user1=self.user_a,
            user2=self.user_b,
            skill_request=req,
        )
        msg_url = reverse('conversation-messages', kwargs={'conversation_id': conv.id})

        # user_c is not part of this conversation
        self.client.force_authenticate(user=self.user_c)
        self.assertEqual(self.client.get(msg_url).status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(
            self.client.post(msg_url, {'message': 'Intruder'}, format='json').status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_messaging_policy_defaults_and_admin_configuration(self):
        policy_url = reverse('admin-messaging-policy')

        # Normal user denied
        self.client.force_authenticate(user=self.user_a)
        self.assertEqual(self.client.get(policy_url).status_code, status.HTTP_403_FORBIDDEN)

        # Admin gets default policy values
        self.client.force_authenticate(user=self.admin_user)
        get_resp = self.client.get(policy_url)
        self.assertEqual(get_resp.status_code, status.HTTP_200_OK)
        policy_data = get_resp.data['policy']
        self.assertEqual(policy_data['max_messages_per_minute'], 5)
        self.assertEqual(policy_data['max_messages_per_conversation_per_day'], 50)
        self.assertEqual(policy_data['max_messages_per_user_per_day'], 100)
        self.assertEqual(policy_data['warning_threshold_percent'], 80)
        self.assertEqual(policy_data['cooldown_minutes'], 15)

        # Admin updates policy
        put_resp = self.client.put(policy_url, {
            'max_messages_per_minute': 8,
            'max_messages_per_conversation_per_day': 60,
            'max_messages_per_user_per_day': 120,
            'warning_threshold_percent': 75,
            'cooldown_minutes': 10,
            'reason': 'Adjusted messaging policy for peak study hours',
        }, format='json')
        self.assertEqual(put_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(put_resp.data['policy']['max_messages_per_minute'], 8)
        self.assertEqual(put_resp.data['policy']['cooldown_minutes'], 10)

        # Verify audit log recorded
        self.assertTrue(
            AdminAuditLog.objects.filter(action='messaging_policy_update').exists()
        )

    def test_rate_limit_enforces_warning_and_cooldown_without_permanent_ban(self):
        req = SkillRequest.objects.create(
            requester=self.user_a,
            target=self.user_b,
            requested_skill=self.skill,
            status='accepted',
        )
        conv = Conversation.objects.create(
            user1=self.user_a,
            user2=self.user_b,
            skill_request=req,
        )
        msg_url = reverse('conversation-messages', kwargs={'conversation_id': conv.id})

        self.client.force_authenticate(user=self.user_a)

        # Default policy: 5 messages/min, warning at 80% (4th message)
        for i in range(1, 4):
            r = self.client.post(msg_url, {'message': f'Message #{i}'}, format='json')
            self.assertEqual(r.status_code, status.HTTP_201_CREATED)
            self.assertNotIn('warning', r.data)

        # 4th message hits 80% warning threshold (4/5 = 80%)
        r4 = self.client.post(msg_url, {'message': 'Message #4'}, format='json')
        self.assertEqual(r4.status_code, status.HTTP_201_CREATED)
        self.assertIn('warning', r4.data)

        # 5th message is allowed (5/5 = 100%)
        r5 = self.client.post(msg_url, {'message': 'Message #5'}, format='json')
        self.assertEqual(r5.status_code, status.HTTP_201_CREATED)

        # 6th message within a minute triggers 429 cooldown
        r6 = self.client.post(msg_url, {'message': 'Message #6 spam'}, format='json')
        self.assertEqual(r6.status_code, status.HTTP_429_TOO_MANY_REQUESTS)

        # User is NOT permanently banned or suspended
        self.user_a.refresh_from_db()
        self.assertFalse(self.user_a.is_suspended)
        self.assertTrue(self.user_a.is_active)

        # Temporary restriction was created
        restriction = UserMessagingRestriction.objects.filter(user=self.user_a, is_active=True).first()
        self.assertIsNotNone(restriction)
        self.assertEqual(restriction.restriction_type, 'cooldown')

        # Admin can release the restriction
        self.client.force_authenticate(user=self.admin_user)
        release_url = reverse('admin-messaging-restriction-release', kwargs={'pk': restriction.id})
        rel_resp = self.client.post(release_url, {'reason': 'Cleared cooldown after review'}, format='json')
        self.assertEqual(rel_resp.status_code, status.HTTP_200_OK)
        restriction.refresh_from_db()
        self.assertFalse(restriction.is_active)


from asgiref.sync import async_to_sync
from channels.testing import WebsocketCommunicator
from django.core.exceptions import ImproperlyConfigured
from django.test import SimpleTestCase, TransactionTestCase, override_settings
from rest_framework_simplejwt.tokens import AccessToken

from accounts.models import Notification
from config.asgi import application
from config.settings import (
    build_middleware,
    resolve_allowed_hosts,
    resolve_channel_layers,
    resolve_csrf_trusted_origins,
    resolve_database_config,
    resolve_debug,
    resolve_production_security_settings,
    resolve_secret_key,
)


class DeploymentSecurityConfigTests(SimpleTestCase):
    def test_debug_defaults_to_false_when_unset(self):
        self.assertFalse(resolve_debug({}))
        self.assertFalse(resolve_debug({'DJANGO_DEBUG': 'False'}))
        self.assertTrue(resolve_debug({'DJANGO_DEBUG': 'True'}))

    def test_secret_key_fails_safely_when_missing_or_weak_in_production(self):
        with self.assertRaises(ImproperlyConfigured):
            resolve_secret_key({}, debug=False)

        with self.assertRaises(ImproperlyConfigured):
            resolve_secret_key({'DJANGO_SECRET_KEY': 'django-insecure-short'}, debug=False)

        with self.assertRaises(ImproperlyConfigured):
            resolve_secret_key(
                {'DJANGO_SECRET_KEY': 'replace-with-a-secure-random-50-character-secret-key'},
                debug=False,
            )

        valid_key = 'a' * 50
        self.assertEqual(
            resolve_secret_key({'DJANGO_SECRET_KEY': valid_key}, debug=False),
            valid_key,
        )

    def test_allowed_hosts_required_in_production(self):
        with self.assertRaises(ImproperlyConfigured):
            resolve_allowed_hosts({}, debug=False)

        self.assertEqual(
            resolve_allowed_hosts({'DJANGO_ALLOWED_HOSTS': 'api.skillswap.example.com'}, debug=False),
            ['api.skillswap.example.com'],
        )

    def test_database_config_requires_credentials_and_supports_database_url(self):
        with self.assertRaises(ImproperlyConfigured):
            resolve_database_config({})

        cfg = resolve_database_config({
            'DATABASE_URL': 'postgresql://dbuser:dbpass@db.example.com:5433/skillswap_prod',
        })
        self.assertEqual(cfg['ENGINE'], 'django.db.backends.postgresql')
        self.assertEqual(cfg['NAME'], 'skillswap_prod')
        self.assertEqual(cfg['USER'], 'dbuser')
        self.assertEqual(cfg['PASSWORD'], 'dbpass')
        self.assertEqual(cfg['HOST'], 'db.example.com')
        self.assertEqual(cfg['PORT'], '5433')

    def test_channel_layers_requires_redis_in_production_and_uses_inmemory_in_dev(self):
        # Local dev without REDIS_URL uses InMemoryChannelLayer
        dev_layers = resolve_channel_layers({}, debug=True)
        self.assertEqual(
            dev_layers['default']['BACKEND'],
            'channels.layers.InMemoryChannelLayer',
        )

        # Production without REDIS_URL fails with ImproperlyConfigured
        with self.assertRaises(ImproperlyConfigured):
            resolve_channel_layers({}, debug=False)

        # Production with REDIS_URL uses RedisChannelLayer
        prod_layers = resolve_channel_layers(
            {'REDIS_URL': 'redis://redis.example.com:6379/0'},
            debug=False,
        )
        self.assertEqual(
            prod_layers['default']['BACKEND'],
            'channels_redis.core.RedisChannelLayer',
        )
        self.assertEqual(
            prod_layers['default']['CONFIG']['hosts'],
            ['redis://redis.example.com:6379/0'],
        )

    def test_whitenoise_and_production_security_settings(self):
        mw = build_middleware(has_whitenoise=True)
        self.assertEqual(mw[0], 'django.middleware.security.SecurityMiddleware')
        self.assertEqual(mw[1], 'whitenoise.middleware.WhiteNoiseMiddleware')

        csrf_origins = resolve_csrf_trusted_origins(
            {'CSRF_TRUSTED_ORIGINS': 'https://skillswap.example.com, https://app.skillswap.example.com'},
            debug=False,
        )
        self.assertEqual(
            csrf_origins,
            ['https://skillswap.example.com', 'https://app.skillswap.example.com'],
        )

        prod_sec = resolve_production_security_settings({}, debug=False)
        self.assertEqual(prod_sec['SECURE_PROXY_SSL_HEADER'], ('HTTP_X_FORWARDED_PROTO', 'https'))
        self.assertTrue(prod_sec['SECURE_SSL_REDIRECT'])
        self.assertTrue(prod_sec['SESSION_COOKIE_SECURE'])
        self.assertTrue(prod_sec['CSRF_COOKIE_SECURE'])

        dev_sec = resolve_production_security_settings({}, debug=True)
        self.assertIsNone(dev_sec['SECURE_PROXY_SSL_HEADER'])
        self.assertFalse(dev_sec['SECURE_SSL_REDIRECT'])
        self.assertFalse(dev_sec['SESSION_COOKIE_SECURE'])
        self.assertFalse(dev_sec['CSRF_COOKIE_SECURE'])


@override_settings(
    CHANNEL_LAYERS={
        'default': {
            'BACKEND': 'channels.layers.InMemoryChannelLayer',
        },
    }
)
class ChatWebSocketSecurityTests(TransactionTestCase):
    def setUp(self):
        self.user_a = User.objects.create_user(
            username='ws_alice',
            email='ws_alice@example.com',
            password='Password123!',
            role='student',
        )
        self.user_b = User.objects.create_user(
            username='ws_bob',
            email='ws_bob@example.com',
            password='Password123!',
            role='professional',
        )
        self.intruder = User.objects.create_user(
            username='ws_intruder',
            email='ws_intruder@example.com',
            password='Password123!',
            role='student',
        )
        self.skill = Skill.objects.create(name='WebSockets', category='Backend')
        self.accepted_req = SkillRequest.objects.create(
            requester=self.user_a,
            target=self.user_b,
            requested_skill=self.skill,
            status='accepted',
        )
        self.conv = Conversation.objects.create(
            user1=self.user_a,
            user2=self.user_b,
            skill_request=self.accepted_req,
        )

    def test_rejects_unauthenticated_and_non_participant_websocket_connections(self):
        async def run_scenario():
            # 1. Unauthenticated connection rejected
            unauth_comm = WebsocketCommunicator(
                application,
                f'/ws/chat/{self.conv.id}/',
            )
            connected, _ = await unauth_comm.connect()
            self.assertFalse(connected)
            await unauth_comm.disconnect()

            # 2. Invalid token connection rejected
            bad_token_comm = WebsocketCommunicator(
                application,
                f'/ws/chat/{self.conv.id}/?token=invalid.jwt.token',
            )
            connected_bad, _ = await bad_token_comm.connect()
            self.assertFalse(connected_bad)
            await bad_token_comm.disconnect()

            # 3. Authenticated non-participant rejected
            intruder_token = str(AccessToken.for_user(self.intruder))
            intruder_comm = WebsocketCommunicator(
                application,
                f'/ws/chat/{self.conv.id}/?token={intruder_token}',
            )
            connected_intruder, _ = await intruder_comm.connect()
            self.assertFalse(connected_intruder)
            await intruder_comm.disconnect()

            # 4. Empty ?token= rejected without falling back to pre-populated scope['user']
            empty_query_comm = WebsocketCommunicator(
                application,
                f'/ws/chat/{self.conv.id}/?token=',
            )
            empty_query_comm.scope['user'] = self.user_a
            connected_empty_query, _ = await empty_query_comm.connect()
            self.assertFalse(connected_empty_query)
            await empty_query_comm.disconnect()

            # 5. Empty Authorization: Bearer header rejected without falling back to session user
            empty_bearer_comm = WebsocketCommunicator(
                application,
                f'/ws/chat/{self.conv.id}/',
                headers=[(b'authorization', b'Bearer   ')],
            )
            empty_bearer_comm.scope['user'] = self.user_a
            connected_empty_bearer, _ = await empty_bearer_comm.connect()
            self.assertFalse(connected_empty_bearer)
            await empty_bearer_comm.disconnect()

            # 6. Valid session/scope user succeeds when no token credential was supplied
            session_comm = WebsocketCommunicator(
                application,
                f'/ws/chat/{self.conv.id}/',
            )
            session_comm.scope['user'] = self.user_a
            connected_session, _ = await session_comm.connect()
            self.assertTrue(connected_session)
            await session_comm.disconnect()

        async_to_sync(run_scenario)()

    def test_authorized_participant_prevents_sender_spoofing_and_enforces_locks_and_legacy_policy(self):
        async def run_scenario():
            bob_token = str(AccessToken.for_user(self.user_b))
            bob_comm = WebsocketCommunicator(
                application,
                f'/ws/chat/{self.conv.id}/?token={bob_token}',
            )
            connected, _ = await bob_comm.connect()
            self.assertTrue(connected)

            # Bob (user2) sends a message while attempting to spoof sender_id as Alice (user1)
            await bob_comm.send_json_to({
                'message': 'Hello from Bob!',
                'sender_id': self.user_a.id,
                'sender': self.user_a.username,
            })
            response = await bob_comm.receive_json_from()
            self.assertEqual(response['message'], 'Hello from Bob!')
            self.assertEqual(response['sender_id'], self.user_b.id)
            self.assertEqual(response['sender_username'], self.user_b.username)

            await bob_comm.disconnect()

        async_to_sync(run_scenario)()

        # Verify database record saved Bob (user2) as sender and notified Alice (user1)
        msg = Message.objects.get(conversation=self.conv)
        self.assertEqual(msg.sender_id, self.user_b.id)
        self.assertTrue(
            Notification.objects.filter(
                user=self.user_a,
                notification_type='new_message',
            ).exists()
        )

        # Lock conversation and verify WebSocket blocks message creation
        self.conv.is_locked = True
        self.conv.save(update_fields=['is_locked'])

        async def run_locked_scenario():
            alice_token = str(AccessToken.for_user(self.user_a))
            alice_comm = WebsocketCommunicator(
                application,
                f'/ws/chat/{self.conv.id}/?token={alice_token}',
            )
            connected, _ = await alice_comm.connect()
            self.assertTrue(connected)

            await alice_comm.send_json_to({'message': 'Should be blocked while locked'})
            err_resp = await alice_comm.receive_json_from()
            self.assertIn('error', err_resp)
            await alice_comm.disconnect()

        async_to_sync(run_locked_scenario)()
        self.assertEqual(Message.objects.filter(conversation=self.conv).count(), 1)

        # Legacy conversation without accepted request is read-only over WebSocket
        legacy_conv = Conversation.objects.create(
            user1=self.user_a,
            user2=self.intruder,
        )

        async def run_legacy_scenario():
            alice_token = str(AccessToken.for_user(self.user_a))
            legacy_comm = WebsocketCommunicator(
                application,
                f'/ws/chat/{legacy_conv.id}/?token={alice_token}',
            )
            connected, _ = await legacy_comm.connect()
            self.assertTrue(connected)

            await legacy_comm.send_json_to({'message': 'Trying to write to read-only legacy chat'})
            err_resp = await legacy_comm.receive_json_from()
            self.assertIn('error', err_resp)
            await legacy_comm.disconnect()

        async_to_sync(run_legacy_scenario)()
        self.assertEqual(Message.objects.filter(conversation=legacy_conv).count(), 0)
