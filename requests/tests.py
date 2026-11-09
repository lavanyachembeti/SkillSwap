from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from accounts.models import User
from skills.models import Skill
from requests.models import SkillRequest
from chat.models import Conversation


class SkillRequestConversationTests(APITestCase):
    def setUp(self):
        self.user_a = User.objects.create_user(
            username='usera',
            email='usera@example.com',
            password='Password123!'
        )
        self.user_b = User.objects.create_user(
            username='userb',
            email='userb@example.com',
            password='Password123!'
        )
        self.skill = Skill.objects.create(
            name='Python Development',
            category='Tech'
        )
        self.request = SkillRequest.objects.create(
            requester=self.user_a,
            target=self.user_b,
            requested_skill=self.skill,
            status='pending'
        )
        self.action_url = reverse('request-action', kwargs={'pk': self.request.id})

    def test_accept_request_creates_conversation(self):
        self.client.force_authenticate(user=self.user_b)
        response = self.client.put(self.action_url, {'status': 'accepted'}, format='json')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], 'accepted')

        # Check conversation was created
        conv = Conversation.objects.filter(user1=self.user_a, user2=self.user_b).first()
        self.assertIsNotNone(conv)

    def test_accept_request_does_not_duplicate_existing_conversation(self):
        # Pre-create conversation in reverse ordering
        Conversation.objects.create(user1=self.user_b, user2=self.user_a)
        self.assertEqual(Conversation.objects.count(), 1)

        self.client.force_authenticate(user=self.user_b)
        response = self.client.put(self.action_url, {'status': 'accepted'}, format='json')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Verify no duplicate conversation was created
        self.assertEqual(Conversation.objects.count(), 1)

    def test_reject_request_does_not_create_conversation(self):
        self.client.force_authenticate(user=self.user_b)
        response = self.client.put(self.action_url, {'status': 'rejected'}, format='json')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(Conversation.objects.count(), 0)
