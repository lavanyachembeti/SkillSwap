from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from accounts.models import User


class RegistrationAPITests(APITestCase):
    def setUp(self):
        self.register_url = reverse('register')
        self.valid_payload = {
            'username': 'johndoe',
            'email': 'john@example.com',
            'password': 'SecurePassword123!',
            'password2': 'SecurePassword123!',
            'role': 'student',
            'phone': '+1234567890',
        }

    def test_registration_success(self):
        response = self.client.post(self.register_url, self.valid_payload, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('message', response.data)
        self.assertIn('user', response.data)
        self.assertEqual(response.data['user']['username'], 'johndoe')
        self.assertEqual(response.data['user']['email'], 'john@example.com')
        self.assertEqual(response.data['user']['role'], 'student')

        # Verify user is persisted in the database and password is encrypted
        user = User.objects.get(username='johndoe')
        self.assertTrue(user.check_password('SecurePassword123!'))
        self.assertEqual(user.phone, '+1234567890')

    def test_registration_success_default_role(self):
        payload = self.valid_payload.copy()
        payload.pop('role')
        payload['username'] = 'defaultroleuser'
        payload['email'] = 'default@example.com'

        response = self.client.post(self.register_url, payload, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['user']['role'], 'student')
        user = User.objects.get(username='defaultroleuser')
        self.assertEqual(user.role, 'student')

    def test_registration_mismatched_passwords(self):
        payload = self.valid_payload.copy()
        payload['password2'] = 'DifferentPassword456!'

        response = self.client.post(self.register_url, payload, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('password', response.data)
        self.assertIn('Passwords do not match.', str(response.data['password']))
        self.assertFalse(User.objects.filter(username='johndoe').exists())

    def test_registration_missing_password_confirmation(self):
        payload = self.valid_payload.copy()
        payload.pop('password2')

        response = self.client.post(self.register_url, payload, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('password2', response.data)
        self.assertFalse(User.objects.filter(username='johndoe').exists())

    def test_registration_short_password(self):
        payload = self.valid_payload.copy()
        payload['password'] = 'short'
        payload['password2'] = 'short'

        response = self.client.post(self.register_url, payload, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('password', response.data)
        self.assertFalse(User.objects.filter(username='johndoe').exists())

    def test_registration_duplicate_username(self):
        User.objects.create_user(
            username='johndoe',
            email='existing@example.com',
            password='OldPassword123!',
        )

        response = self.client.post(self.register_url, self.valid_payload, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('username', response.data)

    def test_registration_missing_required_fields(self):
        response = self.client.post(self.register_url, {}, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('username', response.data)
        self.assertIn('email', response.data)
        self.assertIn('password', response.data)
        self.assertIn('password2', response.data)

    def test_registration_cannot_assign_admin_role(self):
        payload = self.valid_payload.copy()
        payload['role'] = 'admin'

        response = self.client.post(self.register_url, payload, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('role', response.data)
        self.assertFalse(User.objects.filter(username='johndoe').exists())


class AdminPermissionAndUserManagementTests(APITestCase):
    def setUp(self):
        self.student = User.objects.create_user(
            username='student_alice',
            email='alice@example.com',
            password='Password123!',
            role='student',
            phone='+1111111111'
        )
        self.professional = User.objects.create_user(
            username='prof_bob',
            email='bob@example.com',
            password='Password123!',
            role='professional',
            phone='+2222222222'
        )
        self.admin_user = User.objects.create_user(
            username='admin_charlie',
            email='charlie@example.com',
            password='Password123!',
            role='admin',
            phone='+3333333333'
        )
        # Compatible with existing database superuser (role='student', is_staff=True, is_superuser=True)
        self.lavanya_super_admin = User.objects.create_user(
            username='lavanya_admin',
            email='lavanya@example.com',
            password='Password123!',
            role='student',
            is_staff=True,
            is_superuser=True,
            phone='+4444444444'
        )
        self.users_url = reverse('admin-user-list')

    def test_unauthenticated_cannot_access_admin_users(self):
        response = self.client.get(self.users_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_student_cannot_access_admin_users(self):
        self.client.force_authenticate(user=self.student)
        response = self.client.get(self.users_url)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_professional_cannot_access_admin_users(self):
        self.client.force_authenticate(user=self.professional)
        response = self.client.get(self.users_url)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_role_can_access_admin_users(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(self.users_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('count', response.data)
        self.assertIn('results', response.data)

    def test_lavanya_superuser_retains_admin_access(self):
        # Verifies existing account compatibility without altering user role
        self.client.force_authenticate(user=self.lavanya_super_admin)
        response = self.client.get(self.users_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(self.lavanya_super_admin.is_administrator)

    def test_student_cannot_elevate_role_via_profile(self):
        self.client.force_authenticate(user=self.student)
        profile_url = reverse('profile')

        response = self.client.put(profile_url, {'role': 'admin'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.student.refresh_from_db()
        self.assertEqual(self.student.role, 'student')
        self.assertFalse(self.student.is_administrator)

    def test_admin_search_users(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.get(self.users_url, {'search': 'alice'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data['results']
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['username'], 'student_alice')

    def test_admin_filter_users_by_role(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.get(self.users_url, {'role': 'professional'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data['results']
        self.assertTrue(all(u['role'] == 'professional' for u in results))

    def test_admin_user_detail_view(self):
        self.client.force_authenticate(user=self.admin_user)
        detail_url = reverse('admin-user-detail', kwargs={'pk': self.student.id})

        response = self.client.get(detail_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['username'], 'student_alice')
        self.assertIn('skills_teaching', response.data)
        self.assertIn('skills_learning', response.data)
        self.assertIn('sent_requests_count', response.data)

    def test_admin_verify_user_action_and_audit_log(self):
        self.client.force_authenticate(user=self.admin_user)
        verify_url = reverse('admin-user-verify', kwargs={'pk': self.student.id})

        response = self.client.post(verify_url, {'is_verified': True, 'reason': 'Identity verified via documents'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['is_verified'])

        self.student.refresh_from_db()
        self.assertTrue(self.student.is_verified)

        # Check audit log was created
        from accounts.models import AdminAuditLog
        log = AdminAuditLog.objects.filter(target_id=str(self.student.id), action='user_verify').first()
        self.assertIsNotNone(log)
        self.assertEqual(log.admin_user, self.admin_user)
        self.assertEqual(log.reason, 'Identity verified via documents')

    def test_admin_suspend_and_reactivate_user(self):
        self.client.force_authenticate(user=self.admin_user)
        status_url = reverse('admin-user-status', kwargs={'pk': self.student.id})

        # Suspend
        suspend_resp = self.client.post(status_url, {
            'action': 'suspend',
            'reason': 'Inappropriate community behavior',
            'duration_days': 7
        }, format='json')
        self.assertEqual(suspend_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(suspend_resp.data['is_suspended'])
        self.assertEqual(suspend_resp.data['account_status'], 'suspended')

        self.student.refresh_from_db()
        self.assertTrue(self.student.is_suspended)
        self.assertEqual(self.student.account_status, 'suspended')
        self.assertIsNotNone(self.student.suspended_until)

        # Reactivate
        reactivate_resp = self.client.post(status_url, {
            'action': 'reactivate',
            'reason': 'Appeal reviewed and accepted'
        }, format='json')
        self.assertEqual(reactivate_resp.status_code, status.HTTP_200_OK)
        self.assertFalse(reactivate_resp.data['is_suspended'])

        self.student.refresh_from_db()
        self.assertFalse(self.student.is_suspended)
        self.assertIsNone(self.student.suspended_until)

    def test_admin_cannot_suspend_self(self):
        self.client.force_authenticate(user=self.admin_user)
        status_url = reverse('admin-user-status', kwargs={'pk': self.admin_user.id})

        response = self.client.post(status_url, {
            'action': 'suspend',
            'reason': 'Accidental self-suspension'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)

    def test_admin_audit_logs_list(self):
        self.client.force_authenticate(user=self.admin_user)
        # Perform an action to generate a log
        verify_url = reverse('admin-user-verify', kwargs={'pk': self.student.id})
        self.client.post(verify_url, {'is_verified': True}, format='json')

        logs_url = reverse('admin-audit-logs')
        response = self.client.get(logs_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(response.data['count'], 1)


class AdminComprehensiveManagementTests(APITestCase):
    def setUp(self):
        # Admin User
        self.admin_user = User.objects.create_user(
            username='admin_boss',
            email='boss@example.com',
            password='Password123!',
            role='admin',
            is_staff=True,
        )

        # Superuser Lavanya (role=student, staff=True, superuser=True)
        self.lavanya_admin = User.objects.create_superuser(
            username='lavanya_super',
            email='lavanya@example.com',
            password='Password123!',
            role='student',
        )

        # Regular Student & Professional
        self.student = User.objects.create_user(
            username='student_alice',
            email='alice@example.com',
            password='Password123!',
            role='student',
            is_verified=True,
        )
        self.pro = User.objects.create_user(
            username='pro_bob',
            email='bob@example.com',
            password='Password123!',
            role='professional',
            is_verified=False,
        )

        # Create Skills
        from skills.models import Skill, UserSkill
        self.skill_python = Skill.objects.create(name='Python Programming', category='Technology')
        self.skill_design = Skill.objects.create(name='UI/UX Design', category='Design')
        self.skill_unused = Skill.objects.create(name='Unused Skill', category='Misc')

        # Link user skill
        UserSkill.objects.create(user=self.pro, skill=self.skill_python, skill_type='teach')
        UserSkill.objects.create(user=self.student, skill=self.skill_python, skill_type='learn')

        # Create SkillRequest
        from requests.models import SkillRequest
        self.request_pending = SkillRequest.objects.create(
            requester=self.student,
            target=self.pro,
            requested_skill=self.skill_python,
            status='pending',
        )

        # Create Conversation & Message
        from chat.models import Conversation, Message
        self.conversation = Conversation.objects.create(user1=self.student, user2=self.pro)
        self.msg = Message.objects.create(
            conversation=self.conversation,
            sender=self.student,
            message='Hello Bob, excited to learn Python!',
        )

        # Create UserReport
        from discovery.models import UserReport
        self.report = UserReport.objects.create(
            reporter=self.student,
            reported_user=self.pro,
            reason='spam',
            description='Sending repeated promotional links',
            status='pending',
        )

    # 1. Dashboard Statistics Tests
    def test_admin_dashboard_stats_success(self):
        self.client.force_authenticate(user=self.admin_user)
        url = reverse('admin-dashboard-stats')
        response = self.client.get(url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        expected_keys = [
            'total_users', 'total_students', 'total_professionals', 'total_administrators',
            'active_users', 'inactive_users', 'suspended_users', 'verified_users',
            'unverified_users', 'total_skills', 'pending_requests', 'accepted_requests',
            'rejected_requests', 'total_conversations', 'total_messages', 'pending_reports',
        ]
        for key in expected_keys:
            self.assertIn(key, response.data)

        # Validate exact live DB values
        self.assertEqual(response.data['total_users'], User.objects.count())
        self.assertEqual(response.data['total_students'], 2)  # student_alice, lavanya_super
        self.assertEqual(response.data['total_professionals'], 1)  # pro_bob
        self.assertEqual(response.data['total_administrators'], 2)  # admin_boss, lavanya_super
        self.assertEqual(response.data['total_skills'], 3)
        self.assertEqual(response.data['pending_requests'], 1)
        self.assertEqual(response.data['total_conversations'], 1)
        self.assertEqual(response.data['total_messages'], 1)
        self.assertEqual(response.data['pending_reports'], 1)

    def test_lavanya_superuser_can_access_dashboard_stats(self):
        self.client.force_authenticate(user=self.lavanya_admin)
        url = reverse('admin-dashboard-stats')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(response.data['total_users'], 4)

    def test_student_and_pro_denied_dashboard_stats(self):
        url = reverse('admin-dashboard-stats')

        self.client.force_authenticate(user=self.student)
        self.assertEqual(self.client.get(url).status_code, status.HTTP_403_FORBIDDEN)

        self.client.force_authenticate(user=self.pro)
        self.assertEqual(self.client.get(url).status_code, status.HTTP_403_FORBIDDEN)

    # 2. Skill Management Tests
    def test_admin_can_list_and_create_skill(self):
        self.client.force_authenticate(user=self.admin_user)
        url = reverse('admin-skills')

        # List skills
        list_resp = self.client.get(url)
        self.assertEqual(list_resp.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(list_resp.data['count'], 3)

        # Create new skill
        create_resp = self.client.post(url, {
            'name': 'Data Science & Machine Learning',
            'category': 'AI',
            'description': 'Advanced ML and analytics',
        }, format='json')
        self.assertEqual(create_resp.status_code, status.HTTP_201_CREATED)
        self.assertEqual(create_resp.data['name'], 'Data Science & Machine Learning')

    def test_admin_deleting_referenced_skill_deactivates_safely(self):
        self.client.force_authenticate(user=self.admin_user)
        # skill_python is referenced by UserSkill and SkillRequest
        url = reverse('admin-skill-detail', kwargs={'pk': self.skill_python.id})
        response = self.client.delete(url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['action_taken'], 'deactivated')

        # Verify not deleted in DB, but is_active is now False
        from skills.models import Skill
        self.skill_python.refresh_from_db()
        self.assertFalse(self.skill_python.is_active)
        self.assertTrue(Skill.objects.filter(id=self.skill_python.id).exists())

    def test_admin_deleting_unreferenced_skill_removes_from_db(self):
        self.client.force_authenticate(user=self.admin_user)
        url = reverse('admin-skill-detail', kwargs={'pk': self.skill_unused.id})
        response = self.client.delete(url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['action_taken'], 'deleted')

        from skills.models import Skill
        self.assertFalse(Skill.objects.filter(id=self.skill_unused.id).exists())

    # 3. Request Management Tests
    def test_admin_can_list_and_override_request_status(self):
        self.client.force_authenticate(user=self.admin_user)
        list_url = reverse('admin-requests')
        list_resp = self.client.get(list_url)
        self.assertEqual(list_resp.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(list_resp.data['count'], 1)

        # Override status to accepted
        status_url = reverse('admin-request-status', kwargs={'pk': self.request_pending.id})
        override_resp = self.client.post(status_url, {
            'status': 'accepted',
            'reason': 'Administrative dispute resolution',
        }, format='json')
        self.assertEqual(override_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(override_resp.data['status'], 'accepted')

        self.request_pending.refresh_from_db()
        self.assertEqual(self.request_pending.status, 'accepted')

    # 4. Chat Moderation (Read-Only) Tests
    def test_admin_conversation_moderation_read_only(self):
        self.client.force_authenticate(user=self.admin_user)
        conv_url = reverse('admin-conversations')
        conv_resp = self.client.get(conv_url)
        self.assertEqual(conv_resp.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(conv_resp.data['count'], 1)

        msg_url = reverse('admin-conversation-messages', kwargs={'pk': self.conversation.id})
        msg_resp = self.client.get(msg_url)
        self.assertEqual(msg_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(msg_resp.data['count'], 1)
        self.assertEqual(msg_resp.data['messages'][0]['message'], 'Hello Bob, excited to learn Python!')

    def test_student_cannot_access_chat_moderation(self):
        self.client.force_authenticate(user=self.student)
        self.assertEqual(
            self.client.get(reverse('admin-conversations')).status_code,
            status.HTTP_403_FORBIDDEN
        )
        self.assertEqual(
            self.client.get(reverse('admin-conversation-messages', kwargs={'pk': self.conversation.id})).status_code,
            status.HTTP_403_FORBIDDEN
        )

    # 5. Report Management & User Suspension Tests
    def test_admin_can_resolve_report_and_suspend_user(self):
        self.client.force_authenticate(user=self.admin_user)
        report_url = reverse('admin-reports')
        reports_resp = self.client.get(report_url)
        self.assertEqual(reports_resp.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(reports_resp.data['count'], 1)

        # Resolve report and suspend reported user
        resolve_url = reverse('admin-report-resolve', kwargs={'pk': self.report.id})
        resolve_resp = self.client.post(resolve_url, {
            'action': 'resolve',
            'admin_notes': 'Confirmed violation of community guidelines. User suspended.',
            'suspend_user': True,
        }, format='json')

        self.assertEqual(resolve_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resolve_resp.data['status'], 'resolved')
        self.assertTrue(resolve_resp.data['user_suspended'])

        # Verify reported user (pro_bob) is suspended and deactivated
        self.pro.refresh_from_db()
        self.assertTrue(self.pro.is_suspended)
        self.assertFalse(self.pro.is_active)

    def test_suspended_user_cannot_access_api_with_jwt_token(self):
        # Generate token for student while active
        from rest_framework_simplejwt.tokens import RefreshToken
        refresh = RefreshToken.for_user(self.student)
        access_token = str(refresh.access_token)

        # Suspend student via admin API
        self.client.force_authenticate(user=self.admin_user)
        status_url = reverse('admin-user-status', kwargs={'pk': self.student.id})
        self.client.post(status_url, {
            'action': 'suspend',
            'reason': 'Terms violation',
        }, format='json')

        # Now try accessing authenticated profile endpoint using the existing JWT token
        self.client.force_authenticate(user=None)  # Clear session
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')

        profile_resp = self.client.get(reverse('profile'))
        # Must be rejected because is_active is False
        self.assertEqual(profile_resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_admin_extended_dashboard_statistics_and_details(self):
        self.client.force_authenticate(user=self.admin_user)
        stats_resp = self.client.get(reverse('admin-dashboard-stats'))
        self.assertEqual(stats_resp.status_code, status.HTTP_200_OK)

        extended_keys = [
            'recently_registered_users', 'recent_users',
            'active_skills', 'inactive_skills',
            'total_users_teaching_skills', 'total_users_learning_skills',
            'total_requests', 'cancelled_requests',
            'recent_messages', 'recent_messages_list', 'reported_conversations',
            'total_reports', 'under_review_reports', 'resolved_reports', 'dismissed_reports',
            'total_audit_logs', 'recent_admin_activities',
        ]
        for key in extended_keys:
            self.assertIn(key, stats_resp.data)

        self.assertEqual(stats_resp.data['active_skills'], 3)
        self.assertEqual(stats_resp.data['inactive_skills'], 0)
        self.assertEqual(stats_resp.data['total_users_teaching_skills'], 1)
        self.assertEqual(stats_resp.data['total_users_learning_skills'], 1)
        self.assertEqual(stats_resp.data['total_requests'], 1)
        self.assertEqual(stats_resp.data['reported_conversations'], 1)

        # Skill detail view includes teaching_users and learning_users
        skill_detail_url = reverse('admin-skill-detail', kwargs={'pk': self.skill_python.id})
        skill_resp = self.client.get(skill_detail_url)
        self.assertEqual(skill_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(skill_resp.data['teaching_users']), 1)
        self.assertEqual(skill_resp.data['teaching_users'][0]['username'], 'pro_bob')
        self.assertEqual(len(skill_resp.data['learning_users']), 1)
        self.assertEqual(skill_resp.data['learning_users'][0]['username'], 'student_alice')

        # Report under_review action
        resolve_url = reverse('admin-report-resolve', kwargs={'pk': self.report.id})
        review_resp = self.client.post(resolve_url, {
            'action': 'under_review',
            'admin_notes': 'Investigating reported links',
        }, format='json')
        self.assertEqual(review_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(review_resp.data['status'], 'under_review')
