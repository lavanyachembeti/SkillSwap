from django.db.models import Q
from rest_framework import serializers
from .models import User, AdminAuditLog


def _get_user_full_name(user):
    full = f"{user.first_name or ''} {user.last_name or ''}".strip()
    return full if full else user.username


def _get_user_last_activity(user):
    candidates = [dt for dt in [user.last_login, user.date_joined] if dt is not None]
    try:
        last_msg = user.sent_messages.order_by('-created_at').values_list('created_at', flat=True).first()
        if last_msg:
            candidates.append(last_msg)
    except Exception:
        pass
    try:
        last_req = user.sent_requests.order_by('-created_at').values_list('created_at', flat=True).first()
        if last_req:
            candidates.append(last_req)
    except Exception:
        pass
    return max(candidates) if candidates else user.date_joined


class RegisterSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(required=True)
    password = serializers.CharField(write_only=True, min_length=8)
    password2 = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = [
            'username',
            'email',
            'password',
            'password2',
            'role',
            'phone',
        ]

    def validate(self, data):
        if data.get('role') == 'admin':
            raise serializers.ValidationError({
                'role': 'Cannot register as an administrator.'
            })

        if data['password'] != data['password2']:
            raise serializers.ValidationError({
                'password': 'Passwords do not match.'
            })

        return data

    def create(self, validated_data):
        validated_data.pop('password2')

        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            role=validated_data.get('role', 'student'),
            phone=validated_data.get('phone')
        )

        return user


class ProfileSerializer(serializers.ModelSerializer):
    is_admin = serializers.BooleanField(source='is_administrator', read_only=True)
    account_status = serializers.CharField(read_only=True)
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'first_name',
            'last_name',
            'full_name',
            'email',
            'role',
            'phone',
            'bio',
            'profile_image',
            'is_verified',
            'is_staff',
            'is_superuser',
            'is_admin',
            'is_suspended',
            'account_status',
            'date_joined',
            'last_login',
        ]
        read_only_fields = [
            'id',
            'username',
            'full_name',
            'role',
            'is_verified',
            'is_staff',
            'is_superuser',
            'is_admin',
            'is_suspended',
            'account_status',
            'date_joined',
            'last_login',
        ]

    def get_full_name(self, obj):
        return _get_user_full_name(obj)


class AdminUserListSerializer(serializers.ModelSerializer):
    is_admin = serializers.BooleanField(source='is_administrator', read_only=True)
    account_status = serializers.CharField(read_only=True)
    full_name = serializers.SerializerMethodField()
    last_activity = serializers.SerializerMethodField()
    skills_teaching_count = serializers.SerializerMethodField()
    skills_learning_count = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'first_name',
            'last_name',
            'full_name',
            'email',
            'role',
            'phone',
            'bio',
            'profile_image',
            'is_verified',
            'is_active',
            'is_suspended',
            'suspended_until',
            'suspension_reason',
            'account_status',
            'is_staff',
            'is_superuser',
            'is_admin',
            'date_joined',
            'last_login',
            'last_activity',
            'skills_teaching_count',
            'skills_learning_count',
        ]

    def get_full_name(self, obj):
        return _get_user_full_name(obj)

    def get_last_activity(self, obj):
        return _get_user_last_activity(obj)

    def get_skills_teaching_count(self, obj):
        return obj.user_skills.filter(skill_type='teach').count()

    def get_skills_learning_count(self, obj):
        return obj.user_skills.filter(skill_type='learn').count()


class AdminUserDetailSerializer(serializers.ModelSerializer):
    is_admin = serializers.BooleanField(source='is_administrator', read_only=True)
    account_status = serializers.CharField(read_only=True)
    full_name = serializers.SerializerMethodField()
    last_activity = serializers.SerializerMethodField()
    skills_teaching = serializers.SerializerMethodField()
    skills_learning = serializers.SerializerMethodField()
    sent_requests_count = serializers.SerializerMethodField()
    received_requests_count = serializers.SerializerMethodField()
    sent_requests = serializers.SerializerMethodField()
    received_requests = serializers.SerializerMethodField()
    conversations_count = serializers.SerializerMethodField()
    reports_received_count = serializers.SerializerMethodField()
    account_activity = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'first_name',
            'last_name',
            'full_name',
            'email',
            'role',
            'phone',
            'bio',
            'profile_image',
            'is_verified',
            'is_active',
            'is_suspended',
            'suspended_until',
            'suspension_reason',
            'account_status',
            'is_staff',
            'is_superuser',
            'is_admin',
            'date_joined',
            'last_login',
            'last_activity',
            'skills_teaching',
            'skills_learning',
            'sent_requests_count',
            'received_requests_count',
            'sent_requests',
            'received_requests',
            'conversations_count',
            'reports_received_count',
            'account_activity',
        ]

    def get_full_name(self, obj):
        return _get_user_full_name(obj)

    def get_last_activity(self, obj):
        return _get_user_last_activity(obj)

    def get_skills_teaching(self, obj):
        return [
            {
                'id': us.id,
                'skill_id': us.skill.id,
                'name': us.skill.name,
                'category': us.skill.category,
                'proficiency': us.proficiency,
                'is_active': us.skill.is_active,
            }
            for us in obj.user_skills.filter(skill_type='teach').select_related('skill')
        ]

    def get_skills_learning(self, obj):
        return [
            {
                'id': us.id,
                'skill_id': us.skill.id,
                'name': us.skill.name,
                'category': us.skill.category,
                'proficiency': us.proficiency,
                'is_active': us.skill.is_active,
            }
            for us in obj.user_skills.filter(skill_type='learn').select_related('skill')
        ]

    def get_sent_requests_count(self, obj):
        return obj.sent_requests.count()

    def get_received_requests_count(self, obj):
        return obj.received_requests.count()

    def get_sent_requests(self, obj):
        return [
            {
                'id': req.id,
                'target_id': req.target_id,
                'target_username': req.target.username,
                'requested_skill_id': req.requested_skill_id,
                'requested_skill_name': req.requested_skill.name,
                'offered_skill_id': req.offered_skill_id,
                'offered_skill_name': req.offered_skill.name if req.offered_skill else None,
                'message': req.message,
                'learning_goal': req.learning_goal,
                'status': req.status,
                'created_at': req.created_at,
            }
            for req in obj.sent_requests.select_related('target', 'requested_skill', 'offered_skill').order_by('-created_at')[:50]
        ]

    def get_received_requests(self, obj):
        return [
            {
                'id': req.id,
                'requester_id': req.requester_id,
                'requester_username': req.requester.username,
                'requested_skill_id': req.requested_skill_id,
                'requested_skill_name': req.requested_skill.name,
                'offered_skill_id': req.offered_skill_id,
                'offered_skill_name': req.offered_skill.name if req.offered_skill else None,
                'message': req.message,
                'learning_goal': req.learning_goal,
                'status': req.status,
                'created_at': req.created_at,
            }
            for req in obj.received_requests.select_related('requester', 'requested_skill', 'offered_skill').order_by('-created_at')[:50]
        ]

    def get_conversations_count(self, obj):
        return obj.conversations_as_user1.count() + obj.conversations_as_user2.count()

    def get_reports_received_count(self, obj):
        return obj.reports_received.count()

    def get_account_activity(self, obj):
        logs = AdminAuditLog.objects.filter(
            target_model='User',
            target_id=str(obj.id)
        ).select_related('admin_user').order_by('-created_at')[:25]
        return [
            {
                'id': log.id,
                'action': log.action,
                'admin_username': log.admin_user.username,
                'reason': log.reason,
                'previous_value': log.previous_value,
                'new_value': log.new_value,
                'created_at': log.created_at,
            }
            for log in logs
        ]


class AdminAuditLogSerializer(serializers.ModelSerializer):
    admin_username = serializers.CharField(source='admin_user.username', read_only=True)
    description = serializers.SerializerMethodField()
    status = serializers.SerializerMethodField()

    class Meta:
        model = AdminAuditLog
        fields = [
            'id',
            'admin_user',
            'admin_username',
            'action',
            'target_model',
            'target_id',
            'target_repr',
            'previous_value',
            'new_value',
            'reason',
            'description',
            'status',
            'ip_address',
            'created_at',
        ]
        read_only_fields = fields

    def get_description(self, obj):
        target_label = obj.target_repr or f"{obj.target_model} #{obj.target_id or ''}".strip()
        if obj.reason:
            return f"{obj.action} on {target_label} — {obj.reason}"
        return f"{obj.action} on {target_label}"

    def get_status(self, obj):
        return 'success'


class AdminSkillSerializer(serializers.ModelSerializer):
    teaching_users_count = serializers.SerializerMethodField()
    learning_users_count = serializers.SerializerMethodField()
    total_users_count = serializers.SerializerMethodField()
    requests_count = serializers.SerializerMethodField()
    teaching_users = serializers.SerializerMethodField()
    learning_users = serializers.SerializerMethodField()

    class Meta:
        from skills.models import Skill
        model = Skill
        fields = [
            'id',
            'name',
            'description',
            'category',
            'is_active',
            'created_at',
            'teaching_users_count',
            'learning_users_count',
            'total_users_count',
            'requests_count',
            'teaching_users',
            'learning_users',
        ]

    def get_teaching_users_count(self, obj):
        return obj.user_skills.filter(skill_type='teach').count()

    def get_learning_users_count(self, obj):
        return obj.user_skills.filter(skill_type='learn').count()

    def get_total_users_count(self, obj):
        return obj.user_skills.values('user_id').distinct().count()

    def get_requests_count(self, obj):
        return obj.skill_requests.count() + obj.offered_requests.count()

    def get_teaching_users(self, obj):
        return [
            {
                'id': us.id,
                'user_id': us.user_id,
                'username': us.user.username,
                'full_name': _get_user_full_name(us.user),
                'email': us.user.email,
                'role': us.user.role,
                'proficiency': us.proficiency,
            }
            for us in obj.user_skills.filter(skill_type='teach').select_related('user')
        ]

    def get_learning_users(self, obj):
        return [
            {
                'id': us.id,
                'user_id': us.user_id,
                'username': us.user.username,
                'full_name': _get_user_full_name(us.user),
                'email': us.user.email,
                'role': us.user.role,
                'proficiency': us.proficiency,
            }
            for us in obj.user_skills.filter(skill_type='learn').select_related('user')
        ]


class AdminSkillRequestSerializer(serializers.ModelSerializer):
    requester_username = serializers.CharField(source='requester.username', read_only=True)
    requester_full_name = serializers.SerializerMethodField()
    requester_email = serializers.CharField(source='requester.email', read_only=True)
    requester_role = serializers.CharField(source='requester.role', read_only=True)
    target_username = serializers.CharField(source='target.username', read_only=True)
    target_full_name = serializers.SerializerMethodField()
    target_email = serializers.CharField(source='target.email', read_only=True)
    target_role = serializers.CharField(source='target.role', read_only=True)
    requested_skill_name = serializers.CharField(source='requested_skill.name', read_only=True)
    requested_skill_category = serializers.CharField(source='requested_skill.category', read_only=True)
    offered_skill_name = serializers.CharField(source='offered_skill.name', read_only=True, default=None)
    offered_skill_category = serializers.CharField(source='offered_skill.category', read_only=True, default=None)

    class Meta:
        from requests.models import SkillRequest
        model = SkillRequest
        fields = [
            'id',
            'requester',
            'requester_username',
            'requester_full_name',
            'requester_email',
            'requester_role',
            'target',
            'target_username',
            'target_full_name',
            'target_email',
            'target_role',
            'requested_skill',
            'requested_skill_name',
            'requested_skill_category',
            'offered_skill',
            'offered_skill_name',
            'offered_skill_category',
            'message',
            'learning_goal',
            'status',
            'created_at',
            'updated_at',
        ]

    def get_requester_full_name(self, obj):
        return _get_user_full_name(obj.requester)

    def get_target_full_name(self, obj):
        return _get_user_full_name(obj.target)


class AdminConversationSerializer(serializers.ModelSerializer):
    user1_username = serializers.CharField(source='user1.username', read_only=True)
    user1_email = serializers.CharField(source='user1.email', read_only=True)
    user2_username = serializers.CharField(source='user2.username', read_only=True)
    user2_email = serializers.CharField(source='user2.email', read_only=True)
    messages_count = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    last_message_at = serializers.SerializerMethodField()
    linked_request = serializers.SerializerMethodField()
    conversation_status = serializers.CharField(read_only=True)
    can_send_messages = serializers.BooleanField(read_only=True)
    has_accepted_request = serializers.BooleanField(read_only=True)
    is_reported = serializers.SerializerMethodField()

    class Meta:
        from chat.models import Conversation
        model = Conversation
        fields = [
            'id',
            'user1',
            'user1_username',
            'user1_email',
            'user2',
            'user2_username',
            'user2_email',
            'skill_request',
            'linked_request',
            'messages_count',
            'last_message',
            'last_message_at',
            'conversation_status',
            'can_send_messages',
            'has_accepted_request',
            'admin_authorized',
            'is_locked',
            'is_reported',
            'created_at',
            'updated_at',
        ]

    def get_messages_count(self, obj):
        return obj.messages.count()

    def get_last_message(self, obj):
        msg = obj.messages.order_by('-created_at').first()
        return msg.message[:100] if msg else None

    def get_last_message_at(self, obj):
        msg = obj.messages.order_by('-created_at').first()
        return msg.created_at if msg else obj.updated_at

    def get_linked_request(self, obj):
        req = obj.get_linked_request()
        if not req:
            return None
        return {
            'id': req.id,
            'requester_username': req.requester.username,
            'target_username': req.target.username,
            'requested_skill_name': req.requested_skill.name,
            'offered_skill_name': req.offered_skill.name if req.offered_skill else None,
            'status': req.status,
            'created_at': req.created_at,
        }

    def get_is_reported(self, obj):
        from discovery.models import UserReport
        return UserReport.objects.filter(
            (Q(reporter_id=obj.user1_id, reported_user_id=obj.user2_id) |
             Q(reporter_id=obj.user2_id, reported_user_id=obj.user1_id)),
            status__in=['pending', 'under_review']
        ).exists()


class AdminMessageSerializer(serializers.ModelSerializer):
    sender_username = serializers.CharField(source='sender.username', read_only=True)

    class Meta:
        from chat.models import Message
        model = Message
        fields = [
            'id',
            'conversation',
            'sender',
            'sender_username',
            'message',
            'is_read',
            'created_at',
        ]
        read_only_fields = fields


class AdminMessagingPolicySerializer(serializers.ModelSerializer):
    updated_by_username = serializers.CharField(source='updated_by.username', read_only=True, default=None)

    class Meta:
        from chat.models import MessagingPolicy
        model = MessagingPolicy
        fields = [
            'id',
            'max_messages_per_minute',
            'max_messages_per_conversation_per_day',
            'max_messages_per_user_per_day',
            'warning_threshold_percent',
            'cooldown_minutes',
            'enforce_accepted_request',
            'enable_rate_limiting',
            'updated_by',
            'updated_by_username',
            'updated_at',
        ]
        read_only_fields = ['id', 'updated_by', 'updated_by_username', 'updated_at']


class AdminUserMessagingRestrictionSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    created_by_username = serializers.CharField(source='created_by.username', read_only=True, default=None)
    is_currently_active = serializers.BooleanField(read_only=True)

    class Meta:
        from chat.models import UserMessagingRestriction
        model = UserMessagingRestriction
        fields = [
            'id',
            'user',
            'username',
            'user_email',
            'conversation',
            'restriction_type',
            'reason',
            'is_active',
            'is_currently_active',
            'expires_at',
            'created_by',
            'created_by_username',
            'created_at',
        ]
        read_only_fields = ['id', 'username', 'user_email', 'is_currently_active', 'created_by', 'created_by_username', 'created_at']


class AdminUserReportSerializer(serializers.ModelSerializer):
    reporter_username = serializers.CharField(source='reporter.username', read_only=True)
    reporter_email = serializers.CharField(source='reporter.email', read_only=True)
    reported_username = serializers.CharField(source='reported_user.username', read_only=True)
    reported_user_email = serializers.CharField(source='reported_user.email', read_only=True)
    reported_user_role = serializers.CharField(source='reported_user.role', read_only=True)
    reported_user_is_suspended = serializers.BooleanField(source='reported_user.is_suspended', read_only=True)
    reported_user_status = serializers.CharField(source='reported_user.account_status', read_only=True)
    resolved_by_username = serializers.CharField(source='resolved_by.username', read_only=True, default=None)

    class Meta:
        from discovery.models import UserReport
        model = UserReport
        fields = [
            'id',
            'reporter',
            'reporter_username',
            'reporter_email',
            'reported_user',
            'reported_username',
            'reported_user_email',
            'reported_user_role',
            'reported_user_is_suspended',
            'reported_user_status',
            'reason',
            'description',
            'status',
            'admin_notes',
            'resolved_by',
            'resolved_by_username',
            'resolved_at',
            'created_at',
        ]
        read_only_fields = [
            'id',
            'reporter',
            'reported_user',
            'reason',
            'description',
            'created_at',
        ]
