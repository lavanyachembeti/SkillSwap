import math
from datetime import timedelta
from django.db import IntegrityError
from django.db.models import Q
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import AdminAuditLog, Notification, User
from .permissions import IsAdminOrStaffUser
from .serializers import (
    AdminAuditLogSerializer,
    AdminConversationSerializer,
    AdminMessageSerializer,
    AdminMessagingPolicySerializer,
    AdminSkillRequestSerializer,
    AdminSkillSerializer,
    AdminUserDetailSerializer,
    AdminUserListSerializer,
    AdminUserMessagingRestrictionSerializer,
    AdminUserReportSerializer,
)

SENSITIVE_KEYS = {'password', 'password2', 'token', 'access', 'refresh', 'access_token', 'refresh_token', 'secret'}


def _sanitize_audit_payload(payload):
    """Strip any sensitive keys so passwords or JWT tokens are never persisted in audit logs."""
    if not isinstance(payload, dict):
        return payload
    return {
        k: ('[REDACTED]' if str(k).lower() in SENSITIVE_KEYS else v)
        for k, v in payload.items()
    }


def get_client_ip(request):
    """Extract client IP address from request metadata."""
    if not request:
        return None
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


def log_admin_action(
    admin_user,
    action,
    target_model,
    target_id=None,
    target_repr=None,
    previous_value=None,
    new_value=None,
    reason=None,
    request=None
):
    """Record an immutable administrative action in the append-only audit log."""
    return AdminAuditLog.objects.create(
        admin_user=admin_user,
        action=action,
        target_model=target_model,
        target_id=str(target_id) if target_id is not None else None,
        target_repr=str(target_repr)[:200] if target_repr else None,
        previous_value=_sanitize_audit_payload(previous_value),
        new_value=_sanitize_audit_payload(new_value),
        reason=reason,
        ip_address=get_client_ip(request),
    )


def paginate_queryset(queryset, request, default_page_size=50, max_page_size=200):
    """Paginate queryset and return (items, meta_dict)."""
    total_count = queryset.count()
    try:
        page = max(1, int(request.query_params.get('page', 1)))
    except (ValueError, TypeError):
        page = 1

    try:
        page_size = int(request.query_params.get('page_size', default_page_size))
        page_size = max(1, min(page_size, max_page_size))
    except (ValueError, TypeError):
        page_size = default_page_size

    total_pages = max(1, math.ceil(total_count / page_size)) if total_count > 0 else 1
    if page > total_pages:
        page = total_pages

    start = (page - 1) * page_size
    end = start + page_size
    items = queryset[start:end]

    return items, {
        'count': total_count,
        'page': page,
        'page_size': page_size,
        'total_pages': total_pages,
        'has_next': page < total_pages,
        'has_previous': page > 1,
    }


class AdminUserListView(APIView):
    """
    List all registered users with search, role filter, status filter, verification filter, and pagination.
    Enforces administrator permissions.
    """
    permission_classes = [IsAdminOrStaffUser]

    def get(self, request):
        users = User.objects.all().order_by('-date_joined')

        # Search by username, email, phone, first_name, last_name
        search_query = request.query_params.get('search', '').strip()
        if search_query:
            users = users.filter(
                Q(username__icontains=search_query) |
                Q(email__icontains=search_query) |
                Q(phone__icontains=search_query) |
                Q(first_name__icontains=search_query) |
                Q(last_name__icontains=search_query)
            )

        # Filter by role (student, professional, admin)
        role_filter = request.query_params.get('role', '').strip().lower()
        if role_filter in ['student', 'professional']:
            users = users.filter(role=role_filter)
        elif role_filter in ['admin', 'administrator', 'administrators']:
            users = users.filter(
                Q(role='admin') | Q(is_staff=True) | Q(is_superuser=True)
            ).distinct()

        # Filter by is_verified
        verified_param = request.query_params.get('is_verified')
        if verified_param is not None:
            if verified_param.lower() in ['true', '1']:
                users = users.filter(is_verified=True)
            elif verified_param.lower() in ['false', '0']:
                users = users.filter(is_verified=False)

        # Filter by account status (active, inactive, suspended, pending_verification, verified, unverified)
        status_filter = request.query_params.get('status', '').strip().lower()
        if status_filter == 'suspended':
            users = users.filter(is_suspended=True)
        elif status_filter == 'inactive':
            users = users.filter(is_active=False)
        elif status_filter == 'pending_verification':
            users = users.filter(is_verified=False, is_active=True, is_suspended=False)
        elif status_filter == 'active':
            users = users.filter(is_active=True, is_suspended=False)
        elif status_filter == 'verified':
            users = users.filter(is_verified=True)
        elif status_filter == 'unverified':
            users = users.filter(is_verified=False)

        paged_users, meta = paginate_queryset(users, request, default_page_size=50)
        serializer = AdminUserListSerializer(paged_users, many=True)
        return Response({
            **meta,
            'results': serializer.data,
        })


class AdminUserDetailView(APIView):
    """
    View complete user profile, skills, request history, conversation statistics, and activity.
    Admin can also update user details and role.
    """
    permission_classes = [IsAdminOrStaffUser]

    def get(self, request, pk):
        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found.'},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = AdminUserDetailSerializer(user)
        return Response(serializer.data)

    def put(self, request, pk):
        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found.'},
                status=status.HTTP_404_NOT_FOUND
            )

        prev_state = {
            'role': user.role,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'phone': user.phone,
        }

        # Allowed fields for admin update
        if 'role' in request.data:
            new_role = str(request.data['role']).strip().lower()
            if new_role in ['student', 'professional', 'admin']:
                user.role = new_role
        if 'first_name' in request.data:
            user.first_name = str(request.data['first_name']).strip()
        if 'last_name' in request.data:
            user.last_name = str(request.data['last_name']).strip()
        if 'phone' in request.data:
            user.phone = request.data['phone']
        if 'bio' in request.data:
            user.bio = request.data['bio']
        if 'email' in request.data:
            new_email = str(request.data['email']).strip()
            if new_email:
                user.email = new_email

        user.save()

        log_admin_action(
            admin_user=request.user,
            action='user_update',
            target_model='User',
            target_id=user.id,
            target_repr=user.username,
            previous_value=prev_state,
            new_value={
                'role': user.role,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'phone': user.phone,
            },
            reason=request.data.get('reason', 'Admin profile update'),
            request=request
        )

        return Response(AdminUserDetailSerializer(user).data)


class AdminUserVerifyView(APIView):
    """
    Toggle or set user verification status with audit logging.
    """
    permission_classes = [IsAdminOrStaffUser]

    def post(self, request, pk):
        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found.'},
                status=status.HTTP_404_NOT_FOUND
            )

        prev_verified = user.is_verified
        if 'is_verified' in request.data:
            user.is_verified = bool(request.data['is_verified'])
        else:
            user.is_verified = not user.is_verified

        user.save(update_fields=['is_verified'])

        reason = request.data.get('reason', 'Admin verification update')
        log_admin_action(
            admin_user=request.user,
            action='user_verify' if user.is_verified else 'user_unverify',
            target_model='User',
            target_id=user.id,
            target_repr=user.username,
            previous_value={'is_verified': prev_verified},
            new_value={'is_verified': user.is_verified},
            reason=reason,
            request=request
        )

        return Response({
            'message': f"User '{user.username}' verification set to {user.is_verified}.",
            'id': user.id,
            'is_verified': user.is_verified,
            'account_status': user.account_status,
        })


class AdminUserStatusView(APIView):
    """
    Manage user account status: activate, deactivate, suspend, reactivate.
    Includes reason recording and audit logging.
    """
    permission_classes = [IsAdminOrStaffUser]

    def post(self, request, pk):
        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found.'},
                status=status.HTTP_404_NOT_FOUND
            )

        action = request.data.get('action', '').strip().lower()
        reason = request.data.get('reason', '').strip()

        if action not in ['suspend', 'reactivate', 'unsuspend', 'activate', 'deactivate']:
            return Response(
                {
                    'error': "Action must be 'suspend', 'reactivate', 'activate', or 'deactivate'."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Protect against self-suspension or self-deactivation of logged-in admin
        if user.id == request.user.id and action in ['suspend', 'deactivate']:
            return Response(
                {'error': 'Administrators cannot suspend or deactivate their own account.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        prev_state = {
            'is_active': user.is_active,
            'is_suspended': user.is_suspended,
            'suspended_until': user.suspended_until.isoformat() if user.suspended_until else None,
            'suspension_reason': user.suspension_reason,
        }

        if action == 'suspend':
            if not reason:
                return Response(
                    {'error': 'A reason is required when suspending a user account.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            user.is_suspended = True
            user.is_active = False  # Suspended users cannot bypass restrictions with existing JWT tokens
            user.suspension_reason = reason

            duration_days = request.data.get('duration_days')
            if duration_days:
                try:
                    days_int = int(duration_days)
                    user.suspended_until = timezone.now() + timedelta(days=days_int)
                except ValueError:
                    pass
            elif 'suspended_until' in request.data:
                user.suspended_until = request.data['suspended_until']
            else:
                user.suspended_until = None

            user.save(update_fields=['is_suspended', 'suspended_until', 'suspension_reason', 'is_active'])

        elif action in ['reactivate', 'unsuspend']:
            user.is_suspended = False
            user.suspended_until = None
            user.suspension_reason = None
            user.is_active = True
            user.save(update_fields=['is_suspended', 'suspended_until', 'suspension_reason', 'is_active'])

        elif action == 'deactivate':
            user.is_active = False
            user.save(update_fields=['is_active'])

        elif action == 'activate':
            user.is_active = True
            user.is_suspended = False
            user.suspended_until = None
            user.suspension_reason = None
            user.save(update_fields=['is_active', 'is_suspended', 'suspended_until', 'suspension_reason'])

        new_state = {
            'is_active': user.is_active,
            'is_suspended': user.is_suspended,
            'suspended_until': user.suspended_until.isoformat() if user.suspended_until else None,
            'suspension_reason': user.suspension_reason,
        }

        log_admin_action(
            admin_user=request.user,
            action=f'user_{action}',
            target_model='User',
            target_id=user.id,
            target_repr=user.username,
            previous_value=prev_state,
            new_value=new_state,
            reason=reason or f'Admin {action} action',
            request=request
        )

        return Response({
            'message': f"User '{user.username}' status updated to {user.account_status}.",
            'id': user.id,
            'is_active': user.is_active,
            'is_suspended': user.is_suspended,
            'account_status': user.account_status,
            'suspension_reason': user.suspension_reason,
            'suspended_until': user.suspended_until,
        })


class AdminAuditLogListView(APIView):
    """
    List audit logs for administrative actions (append-only, read-only for administrators).
    """
    permission_classes = [IsAdminOrStaffUser]

    def get(self, request):
        logs = AdminAuditLog.objects.all().select_related('admin_user').order_by('-created_at')

        action_filter = request.query_params.get('action', '').strip()
        if action_filter:
            logs = logs.filter(action__icontains=action_filter)

        target_model = request.query_params.get('target_model', '').strip()
        if target_model:
            logs = logs.filter(target_model__iexact=target_model)

        target_id = request.query_params.get('target_id', '').strip()
        if target_id:
            logs = logs.filter(target_id=str(target_id))

        admin_username = request.query_params.get('admin_username', '').strip()
        if admin_username:
            logs = logs.filter(admin_user__username__icontains=admin_username)

        search = request.query_params.get('search', '').strip()
        if search:
            logs = logs.filter(
                Q(admin_user__username__icontains=search) |
                Q(action__icontains=search) |
                Q(target_model__icontains=search) |
                Q(target_repr__icontains=search) |
                Q(reason__icontains=search)
            )

        paged_logs, meta = paginate_queryset(logs, request, default_page_size=100)
        serializer = AdminAuditLogSerializer(paged_logs, many=True)
        return Response({
            **meta,
            'results': serializer.data,
        })


class AdminDashboardStatsView(APIView):
    """
    Returns live database statistics across the entire platform.
    Requires administrator permissions.
    """
    permission_classes = [IsAdminOrStaffUser]

    def get(self, request):
        from skills.models import Skill, UserSkill
        from requests.models import SkillRequest
        from chat.models import Conversation, Message
        from discovery.models import UserReport

        now = timezone.now()
        seven_days_ago = now - timedelta(days=7)

        # 1. USER STATISTICS
        total_users = User.objects.count()
        total_students = User.objects.filter(role='student').count()
        total_professionals = User.objects.filter(role='professional').count()
        total_administrators = User.objects.filter(
            Q(role='admin') | Q(is_staff=True) | Q(is_superuser=True)
        ).distinct().count()

        active_users = User.objects.filter(is_active=True, is_suspended=False).count()
        inactive_users = User.objects.filter(is_active=False).count()
        suspended_users = User.objects.filter(is_suspended=True).count()
        verified_users = User.objects.filter(is_verified=True).count()
        unverified_users = User.objects.filter(is_verified=False).count()
        recently_registered_users = User.objects.filter(date_joined__gte=seven_days_ago).count()

        recent_users_qs = User.objects.all().order_by('-date_joined')[:6]
        recent_users = AdminUserListSerializer(recent_users_qs, many=True).data

        # 2. SKILL STATISTICS
        total_skills = Skill.objects.count()
        active_skills = Skill.objects.filter(is_active=True).count()
        inactive_skills = Skill.objects.filter(is_active=False).count()
        total_users_teaching_skills = UserSkill.objects.filter(
            skill_type='teach'
        ).values('user_id').distinct().count()
        total_users_learning_skills = UserSkill.objects.filter(
            skill_type='learn'
        ).values('user_id').distinct().count()

        # 3. REQUEST STATISTICS
        total_requests = SkillRequest.objects.count()
        pending_requests = SkillRequest.objects.filter(status='pending').count()
        accepted_requests = SkillRequest.objects.filter(status='accepted').count()
        rejected_requests = SkillRequest.objects.filter(status='rejected').count()
        cancelled_requests = SkillRequest.objects.filter(status='cancelled').count()

        # 4. CHAT STATISTICS
        total_conversations = Conversation.objects.count()
        total_messages = Message.objects.count()
        recent_messages = Message.objects.filter(created_at__gte=seven_days_ago).count()
        recent_messages_qs = Message.objects.select_related('sender').order_by('-created_at')[:6]
        recent_messages_list = AdminMessageSerializer(recent_messages_qs, many=True).data

        # Reported conversations: conversations locked or involving users with active reports
        reported_user_ids = list(
            UserReport.objects.filter(
                status__in=['pending', 'under_review']
            ).values_list('reported_user_id', flat=True).distinct()
        )
        reported_conversations = Conversation.objects.filter(
            Q(is_locked=True) |
            Q(user1_id__in=reported_user_ids) |
            Q(user2_id__in=reported_user_ids)
        ).distinct().count()

        # 5. OTHER STATISTICS (REPORTS & AUDIT)
        total_reports = UserReport.objects.count()
        pending_reports = UserReport.objects.filter(status='pending').count()
        under_review_reports = UserReport.objects.filter(status='under_review').count()
        resolved_reports = UserReport.objects.filter(status='resolved').count()
        dismissed_reports = UserReport.objects.filter(status='dismissed').count()

        total_audit_logs = AdminAuditLog.objects.count()
        recent_audit_qs = AdminAuditLog.objects.select_related('admin_user').order_by('-created_at')[:8]
        recent_admin_activities = AdminAuditLogSerializer(recent_audit_qs, many=True).data

        return Response({
            # User statistics
            'total_users': total_users,
            'total_students': total_students,
            'total_professionals': total_professionals,
            'total_administrators': total_administrators,
            'active_users': active_users,
            'inactive_users': inactive_users,
            'suspended_users': suspended_users,
            'verified_users': verified_users,
            'unverified_users': unverified_users,
            'recently_registered_users': recently_registered_users,
            'recent_users': recent_users,

            # Skill statistics
            'total_skills': total_skills,
            'active_skills': active_skills,
            'inactive_skills': inactive_skills,
            'total_users_teaching_skills': total_users_teaching_skills,
            'total_users_learning_skills': total_users_learning_skills,

            # Request statistics
            'total_requests': total_requests,
            'pending_requests': pending_requests,
            'accepted_requests': accepted_requests,
            'rejected_requests': rejected_requests,
            'cancelled_requests': cancelled_requests,

            # Chat statistics
            'total_conversations': total_conversations,
            'total_messages': total_messages,
            'recent_messages': recent_messages,
            'recent_messages_list': recent_messages_list,
            'reported_conversations': reported_conversations,

            # Reports & Audit statistics
            'total_reports': total_reports,
            'pending_reports': pending_reports,
            'under_review_reports': under_review_reports,
            'resolved_reports': resolved_reports,
            'dismissed_reports': dismissed_reports,
            'total_audit_logs': total_audit_logs,
            'recent_admin_activities': recent_admin_activities,
        })


class AdminSkillManagementView(APIView):
    """
    List master skills catalog or create a new skill in the catalog.
    """
    permission_classes = [IsAdminOrStaffUser]

    def get(self, request):
        from skills.models import Skill
        skills = Skill.objects.all().order_by('name')

        search = request.query_params.get('search', '').strip()
        if search:
            skills = skills.filter(
                Q(name__icontains=search) |
                Q(category__icontains=search) |
                Q(description__icontains=search)
            )

        category_param = request.query_params.get('category', '').strip()
        if category_param and category_param.lower() != 'all':
            skills = skills.filter(category__iexact=category_param)

        is_active_param = request.query_params.get('is_active')
        if is_active_param is not None:
            if is_active_param.lower() in ['true', '1', 'active']:
                skills = skills.filter(is_active=True)
            elif is_active_param.lower() in ['false', '0', 'inactive']:
                skills = skills.filter(is_active=False)

        paged_skills, meta = paginate_queryset(skills, request, default_page_size=100)
        serializer = AdminSkillSerializer(paged_skills, many=True)
        return Response({
            **meta,
            'results': serializer.data,
        })

    def post(self, request):
        from skills.models import Skill
        name = str(request.data.get('name', '')).strip()
        if not name:
            return Response({'error': 'Skill name is required.'}, status=status.HTTP_400_BAD_REQUEST)

        if Skill.objects.filter(name__iexact=name).exists():
            return Response({'error': f"Skill '{name}' already exists in catalog."}, status=status.HTTP_400_BAD_REQUEST)

        description = str(request.data.get('description', '')).strip()
        category = str(request.data.get('category', '')).strip() or 'General'
        is_active = bool(request.data.get('is_active', True))

        skill = Skill.objects.create(
            name=name,
            description=description,
            category=category,
            is_active=is_active,
        )

        log_admin_action(
            admin_user=request.user,
            action='skill_create',
            target_model='Skill',
            target_id=skill.id,
            target_repr=skill.name,
            previous_value=None,
            new_value={'name': skill.name, 'category': skill.category, 'is_active': skill.is_active},
            reason=request.data.get('reason', 'Admin created skill in catalog'),
            request=request
        )

        return Response(AdminSkillSerializer(skill).data, status=status.HTTP_201_CREATED)


class AdminSkillDetailView(APIView):
    """
    Retrieve, update, or delete/deactivate a catalog skill.
    Guarantees that skills referenced by existing users or requests are deactivated, not deleted.
    """
    permission_classes = [IsAdminOrStaffUser]

    def get_skill(self, pk):
        from skills.models import Skill
        try:
            return Skill.objects.get(pk=pk)
        except Skill.DoesNotExist:
            return None

    def get(self, request, pk):
        skill = self.get_skill(pk)
        if not skill:
            return Response({'error': 'Skill not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(AdminSkillSerializer(skill).data)

    def put(self, request, pk):
        skill = self.get_skill(pk)
        if not skill:
            return Response({'error': 'Skill not found.'}, status=status.HTTP_404_NOT_FOUND)

        prev_val = {
            'name': skill.name,
            'category': skill.category,
            'description': skill.description,
            'is_active': skill.is_active,
        }

        if 'name' in request.data:
            new_name = str(request.data['name']).strip()
            if not new_name:
                return Response({'error': 'Skill name cannot be empty.'}, status=status.HTTP_400_BAD_REQUEST)
            if new_name.lower() != skill.name.lower():
                from skills.models import Skill
                if Skill.objects.filter(name__iexact=new_name).exclude(pk=skill.pk).exists():
                    return Response({'error': f"Skill '{new_name}' already exists."}, status=status.HTTP_400_BAD_REQUEST)
            skill.name = new_name
        if 'description' in request.data:
            skill.description = request.data['description']
        if 'category' in request.data:
            skill.category = request.data['category']
        if 'is_active' in request.data:
            skill.is_active = bool(request.data['is_active'])

        skill.save()

        action_name = 'skill_update'
        if prev_val['is_active'] != skill.is_active:
            action_name = 'skill_activate' if skill.is_active else 'skill_deactivate'

        log_admin_action(
            admin_user=request.user,
            action=action_name,
            target_model='Skill',
            target_id=skill.id,
            target_repr=skill.name,
            previous_value=prev_val,
            new_value={
                'name': skill.name,
                'category': skill.category,
                'description': skill.description,
                'is_active': skill.is_active,
            },
            reason=request.data.get('reason', 'Admin updated skill catalog'),
            request=request
        )

        return Response(AdminSkillSerializer(skill).data)

    def delete(self, request, pk):
        skill = self.get_skill(pk)
        if not skill:
            return Response({'error': 'Skill not found.'}, status=status.HTTP_404_NOT_FOUND)

        # Check if referenced by user_skills or skill_requests
        is_used = skill.user_skills.exists() or skill.skill_requests.exists() or skill.offered_requests.exists()

        if is_used:
            # Safe deactivation: do not delete referenced records
            skill.is_active = False
            skill.save(update_fields=['is_active'])

            log_admin_action(
                admin_user=request.user,
                action='skill_deactivate',
                target_model='Skill',
                target_id=skill.id,
                target_repr=skill.name,
                previous_value={'is_active': True},
                new_value={'is_active': False},
                reason=request.data.get('reason', 'Deactivated because skill is referenced by existing users/requests'),
                request=request
            )

            return Response({
                'message': f"Skill '{skill.name}' is referenced by existing users or requests. It was deactivated instead of deleted to protect record integrity.",
                'id': skill.id,
                'is_active': False,
                'action_taken': 'deactivated'
            })
        else:
            skill_name = skill.name
            skill.delete()

            log_admin_action(
                admin_user=request.user,
                action='skill_delete',
                target_model='Skill',
                target_id=pk,
                target_repr=skill_name,
                previous_value={'name': skill_name},
                new_value=None,
                reason=request.data.get('reason', 'Unreferenced skill deleted from catalog'),
                request=request
            )

            return Response({
                'message': f"Skill '{skill_name}' was unreferenced and permanently removed.",
                'id': pk,
                'action_taken': 'deleted'
            })


class AdminRequestManagementView(APIView):
    """
    List all skill-swap requests across the platform with filtering, search, and pagination.
    """
    permission_classes = [IsAdminOrStaffUser]

    def get(self, request):
        from requests.models import SkillRequest
        requests_qs = SkillRequest.objects.all().select_related(
            'requester', 'target', 'requested_skill', 'offered_skill'
        ).order_by('-created_at')

        status_param = request.query_params.get('status', '').strip().lower()
        if status_param in ['pending', 'accepted', 'rejected', 'cancelled']:
            requests_qs = requests_qs.filter(status=status_param)

        user_id = request.query_params.get('user_id', '').strip()
        if user_id and user_id.isdigit():
            requests_qs = requests_qs.filter(
                Q(requester_id=int(user_id)) | Q(target_id=int(user_id))
            )

        search = request.query_params.get('search', '').strip()
        if search:
            requests_qs = requests_qs.filter(
                Q(requester__username__icontains=search) |
                Q(requester__email__icontains=search) |
                Q(target__username__icontains=search) |
                Q(target__email__icontains=search) |
                Q(requested_skill__name__icontains=search) |
                Q(offered_skill__name__icontains=search) |
                Q(message__icontains=search) |
                Q(learning_goal__icontains=search)
            )

        paged_requests, meta = paginate_queryset(requests_qs, request, default_page_size=100)
        serializer = AdminSkillRequestSerializer(paged_requests, many=True)
        return Response({
            **meta,
            'results': serializer.data,
        })


class AdminRequestStatusView(APIView):
    """
    Administrative status override for skill-swap requests with validation and audit logging.
    """
    permission_classes = [IsAdminOrStaffUser]

    def post(self, request, pk):
        from requests.models import SkillRequest
        try:
            req_obj = SkillRequest.objects.select_related('requester', 'target', 'requested_skill', 'offered_skill').get(pk=pk)
        except SkillRequest.DoesNotExist:
            return Response({'error': 'Skill request not found.'}, status=status.HTTP_404_NOT_FOUND)

        new_status = request.data.get('status', '').strip().lower()
        if new_status not in ['pending', 'accepted', 'rejected', 'cancelled']:
            return Response(
                {'error': "Status must be 'pending', 'accepted', 'rejected', or 'cancelled'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        prev_status = req_obj.status
        reason = request.data.get('reason', '').strip() or 'Admin status change'

        req_obj.status = new_status
        req_obj.save(update_fields=['status', 'updated_at'])

        # If accepted, ensure a Conversation exists between the participants without duplicating reverse pairs
        if new_status == 'accepted':
            from chat.models import Conversation
            u1 = req_obj.requester
            u2 = req_obj.target
            conv = Conversation.objects.filter(
                (Q(user1=u1, user2=u2) | Q(user1=u2, user2=u1))
            ).first()
            if not conv:
                try:
                    conv = Conversation.objects.create(
                        user1=u1,
                        user2=u2,
                        skill_request=req_obj
                    )
                except IntegrityError:
                    conv = Conversation.objects.filter(
                        (Q(user1=u1, user2=u2) | Q(user1=u2, user2=u1))
                    ).first()
            if conv and not conv.skill_request_id:
                conv.skill_request = req_obj
                conv.save(update_fields=['skill_request'])

        log_admin_action(
            admin_user=request.user,
            action='request_status_override',
            target_model='SkillRequest',
            target_id=req_obj.id,
            target_repr=f"{req_obj.requester.username} -> {req_obj.target.username} ({req_obj.requested_skill.name})",
            previous_value={'status': prev_status},
            new_value={'status': new_status},
            reason=reason,
            request=request
        )

        return Response({
            'message': f"Request #{req_obj.id} status updated from '{prev_status}' to '{new_status}'.",
            'id': req_obj.id,
            'status': req_obj.status,
            'updated_at': req_obj.updated_at,
        })


class AdminConversationManagementView(APIView):
    """
    List of all conversations for administrative oversight and moderation.
    """
    permission_classes = [IsAdminOrStaffUser]

    def get(self, request):
        from chat.models import Conversation
        convs = Conversation.objects.all().select_related('user1', 'user2', 'skill_request').order_by('-updated_at')

        search = request.query_params.get('search', '').strip()
        if search:
            convs = convs.filter(
                Q(user1__username__icontains=search) |
                Q(user1__email__icontains=search) |
                Q(user2__username__icontains=search) |
                Q(user2__email__icontains=search)
            )

        status_filter = request.query_params.get('status', '').strip().lower()
        if status_filter == 'restricted' or status_filter == 'locked':
            convs = convs.filter(is_locked=True)
        elif status_filter == 'authorized_legacy':
            convs = convs.filter(admin_authorized=True, is_locked=False)
        elif status_filter == 'reported':
            from discovery.models import UserReport
            reported_user_ids = list(
                UserReport.objects.filter(
                    status__in=['pending', 'under_review']
                ).values_list('reported_user_id', flat=True).distinct()
            )
            convs = convs.filter(
                Q(is_locked=True) |
                Q(user1_id__in=reported_user_ids) |
                Q(user2_id__in=reported_user_ids)
            ).distinct()

        paged_convs, meta = paginate_queryset(convs, request, default_page_size=100)
        serializer = AdminConversationSerializer(paged_convs, many=True)
        return Response({
            **meta,
            'results': serializer.data,
        })


class AdminConversationMessagesView(APIView):
    """
    Read-only message history inspection for conversation moderation.
    """
    permission_classes = [IsAdminOrStaffUser]

    def get(self, request, pk):
        from chat.models import Conversation
        try:
            conv = Conversation.objects.select_related('user1', 'user2', 'skill_request').get(pk=pk)
        except Conversation.DoesNotExist:
            return Response({'error': 'Conversation not found.'}, status=status.HTTP_404_NOT_FOUND)

        messages = conv.messages.all().select_related('sender').order_by('created_at')
        serializer = AdminMessageSerializer(messages[:300], many=True)
        conv_data = AdminConversationSerializer(conv).data
        return Response({
            'conversation_id': conv.id,
            'user1': conv.user1.username,
            'user2': conv.user2.username,
            'conversation_status': conv.conversation_status,
            'can_send_messages': conv.can_send_messages,
            'has_accepted_request': conv.has_accepted_request,
            'admin_authorized': conv.admin_authorized,
            'is_locked': conv.is_locked,
            'linked_request': conv_data.get('linked_request'),
            'count': messages.count(),
            'messages': serializer.data,
        })


class AdminConversationStatusView(APIView):
    """
    Administrative moderation controls for a conversation:
    - authorize_legacy: explicitly authorize messaging in a legacy conversation without an accepted request
    - revoke_legacy: revoke legacy authorization
    - lock: restrict/lock a conversation for moderation
    - unlock: remove lock on a conversation
    """
    permission_classes = [IsAdminOrStaffUser]

    def post(self, request, pk):
        from chat.models import Conversation
        try:
            conv = Conversation.objects.select_related('user1', 'user2', 'skill_request').get(pk=pk)
        except Conversation.DoesNotExist:
            return Response({'error': 'Conversation not found.'}, status=status.HTTP_404_NOT_FOUND)

        action = str(request.data.get('action', '')).strip().lower()
        reason = str(request.data.get('reason', '')).strip() or f'Admin conversation {action}'

        if action not in ['authorize_legacy', 'revoke_legacy', 'lock', 'unlock']:
            return Response(
                {'error': "Action must be 'authorize_legacy', 'revoke_legacy', 'lock', or 'unlock'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        prev_state = {
            'admin_authorized': conv.admin_authorized,
            'is_locked': conv.is_locked,
            'conversation_status': conv.conversation_status,
        }

        if action == 'authorize_legacy':
            conv.admin_authorized = True
            conv.is_locked = False
        elif action == 'revoke_legacy':
            conv.admin_authorized = False
        elif action == 'lock':
            conv.is_locked = True
        elif action == 'unlock':
            conv.is_locked = False

        conv.save(update_fields=['admin_authorized', 'is_locked', 'updated_at'])

        new_state = {
            'admin_authorized': conv.admin_authorized,
            'is_locked': conv.is_locked,
            'conversation_status': conv.conversation_status,
        }

        log_admin_action(
            admin_user=request.user,
            action=f'conversation_{action}',
            target_model='Conversation',
            target_id=conv.id,
            target_repr=f"{conv.user1.username} & {conv.user2.username}",
            previous_value=prev_state,
            new_value=new_state,
            reason=reason,
            request=request
        )

        return Response({
            'message': f"Conversation #{conv.id} updated ({action}).",
            'conversation': AdminConversationSerializer(conv).data,
        })


class AdminMessagingPolicyView(APIView):
    """
    Retrieve or update platform-wide messaging policy controls and view active restrictions.
    """
    permission_classes = [IsAdminOrStaffUser]

    def get(self, request):
        from chat.models import MessagingPolicy, UserMessagingRestriction
        policy = MessagingPolicy.get_policy()
        now = timezone.now()

        # Auto-expire past restrictions
        UserMessagingRestriction.objects.filter(
            is_active=True,
            expires_at__lte=now
        ).update(is_active=False)

        active_restrictions = UserMessagingRestriction.objects.filter(
            is_active=True
        ).filter(
            Q(expires_at__isnull=True) | Q(expires_at__gt=now)
        ).select_related('user', 'created_by')

        return Response({
            'policy': AdminMessagingPolicySerializer(policy).data,
            'active_restrictions_count': active_restrictions.count(),
            'active_restrictions': AdminUserMessagingRestrictionSerializer(active_restrictions[:100], many=True).data,
        })

    def put(self, request):
        from chat.models import MessagingPolicy
        policy = MessagingPolicy.get_policy()

        prev_val = {
            'max_messages_per_minute': policy.max_messages_per_minute,
            'max_messages_per_conversation_per_day': policy.max_messages_per_conversation_per_day,
            'max_messages_per_user_per_day': policy.max_messages_per_user_per_day,
            'warning_threshold_percent': policy.warning_threshold_percent,
            'cooldown_minutes': policy.cooldown_minutes,
            'enforce_accepted_request': policy.enforce_accepted_request,
            'enable_rate_limiting': policy.enable_rate_limiting,
        }

        int_fields = [
            'max_messages_per_minute',
            'max_messages_per_conversation_per_day',
            'max_messages_per_user_per_day',
            'warning_threshold_percent',
            'cooldown_minutes',
        ]
        for field in int_fields:
            if field in request.data:
                try:
                    val = int(request.data[field])
                    if val < 1:
                        return Response(
                            {'error': f'{field} must be at least 1.'},
                            status=status.HTTP_400_BAD_REQUEST
                        )
                    if field == 'warning_threshold_percent' and val > 100:
                        return Response(
                            {'error': 'warning_threshold_percent must be between 1 and 100.'},
                            status=status.HTTP_400_BAD_REQUEST
                        )
                    setattr(policy, field, val)
                except (ValueError, TypeError):
                    return Response(
                        {'error': f'Invalid integer value for {field}.'},
                        status=status.HTTP_400_BAD_REQUEST
                    )

        if 'enforce_accepted_request' in request.data:
            policy.enforce_accepted_request = bool(request.data['enforce_accepted_request'])
        if 'enable_rate_limiting' in request.data:
            policy.enable_rate_limiting = bool(request.data['enable_rate_limiting'])

        policy.updated_by = request.user
        policy.save()

        new_val = {
            'max_messages_per_minute': policy.max_messages_per_minute,
            'max_messages_per_conversation_per_day': policy.max_messages_per_conversation_per_day,
            'max_messages_per_user_per_day': policy.max_messages_per_user_per_day,
            'warning_threshold_percent': policy.warning_threshold_percent,
            'cooldown_minutes': policy.cooldown_minutes,
            'enforce_accepted_request': policy.enforce_accepted_request,
            'enable_rate_limiting': policy.enable_rate_limiting,
        }

        log_admin_action(
            admin_user=request.user,
            action='messaging_policy_update',
            target_model='MessagingPolicy',
            target_id=policy.id,
            target_repr='Platform Messaging Policy',
            previous_value=prev_val,
            new_value=new_val,
            reason=request.data.get('reason', 'Admin updated messaging policy controls'),
            request=request
        )

        return Response({
            'message': 'Messaging policy updated successfully.',
            'policy': AdminMessagingPolicySerializer(policy).data,
        })

    def post(self, request):
        return self.put(request)


class AdminMessagingRestrictionListView(APIView):
    """
    List or create temporary user messaging restrictions / cooldowns.
    """
    permission_classes = [IsAdminOrStaffUser]

    def get(self, request):
        from chat.models import UserMessagingRestriction
        now = timezone.now()
        UserMessagingRestriction.objects.filter(
            is_active=True,
            expires_at__lte=now
        ).update(is_active=False)

        qs = UserMessagingRestriction.objects.select_related('user', 'created_by').order_by('-created_at')
        active_only = request.query_params.get('active_only', 'true').lower()
        if active_only in ['true', '1']:
            qs = qs.filter(is_active=True).filter(Q(expires_at__isnull=True) | Q(expires_at__gt=now))

        serializer = AdminUserMessagingRestrictionSerializer(qs[:100], many=True)
        return Response({
            'count': qs.count(),
            'results': serializer.data,
        })

    def post(self, request):
        from chat.models import UserMessagingRestriction, MessagingPolicy
        user_id = request.data.get('user_id')
        if not user_id:
            return Response({'error': 'user_id is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            target_user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        policy = MessagingPolicy.get_policy()
        try:
            minutes = int(request.data.get('duration_minutes', policy.cooldown_minutes))
        except (ValueError, TypeError):
            minutes = policy.cooldown_minutes

        reason = str(request.data.get('reason', '')).strip() or 'Administrative messaging cooldown'
        expires_at = timezone.now() + timedelta(minutes=max(1, minutes))

        restriction = UserMessagingRestriction.objects.create(
            user=target_user,
            restriction_type='admin_mute',
            reason=reason,
            is_active=True,
            expires_at=expires_at,
            created_by=request.user,
        )

        log_admin_action(
            admin_user=request.user,
            action='messaging_restriction_create',
            target_model='UserMessagingRestriction',
            target_id=restriction.id,
            target_repr=target_user.username,
            previous_value=None,
            new_value={'user': target_user.username, 'duration_minutes': minutes, 'expires_at': expires_at.isoformat()},
            reason=reason,
            request=request
        )

        return Response(
            AdminUserMessagingRestrictionSerializer(restriction).data,
            status=status.HTTP_201_CREATED
        )


class AdminMessagingRestrictionReleaseView(APIView):
    """
    Release/clear an active messaging restriction or cooldown.
    """
    permission_classes = [IsAdminOrStaffUser]

    def post(self, request, pk):
        from chat.models import UserMessagingRestriction
        try:
            restriction = UserMessagingRestriction.objects.select_related('user').get(pk=pk)
        except UserMessagingRestriction.DoesNotExist:
            return Response({'error': 'Restriction not found.'}, status=status.HTTP_404_NOT_FOUND)

        restriction.is_active = False
        restriction.save(update_fields=['is_active'])

        log_admin_action(
            admin_user=request.user,
            action='messaging_restriction_release',
            target_model='UserMessagingRestriction',
            target_id=restriction.id,
            target_repr=restriction.user.username,
            previous_value={'is_active': True},
            new_value={'is_active': False},
            reason=request.data.get('reason', 'Admin released messaging cooldown/restriction'),
            request=request
        )

        return Response({
            'message': f"Messaging restriction for '{restriction.user.username}' has been lifted.",
            'id': restriction.id,
            'is_active': False,
        })


class AdminReportManagementView(APIView):
    """
    List user moderation reports with filtering, search, and pagination.
    """
    permission_classes = [IsAdminOrStaffUser]

    def get(self, request):
        from discovery.models import UserReport
        reports = UserReport.objects.all().select_related('reporter', 'reported_user', 'resolved_by').order_by('-created_at')

        status_param = request.query_params.get('status', '').strip().lower()
        if status_param in ['pending', 'under_review', 'resolved', 'dismissed']:
            reports = reports.filter(status=status_param)

        reason_param = request.query_params.get('reason', '').strip()
        if reason_param and reason_param.lower() != 'all':
            reports = reports.filter(reason=reason_param)

        search = request.query_params.get('search', '').strip()
        if search:
            reports = reports.filter(
                Q(reporter__username__icontains=search) |
                Q(reported_user__username__icontains=search) |
                Q(description__icontains=search) |
                Q(admin_notes__icontains=search) |
                Q(reason__icontains=search)
            )

        paged_reports, meta = paginate_queryset(reports, request, default_page_size=100)
        serializer = AdminUserReportSerializer(paged_reports, many=True)
        return Response({
            **meta,
            'results': serializer.data,
        })


class AdminReportResolveView(APIView):
    """
    Update a user report: mark as under_review, resolve, dismiss, or add admin notes,
    with optional reported user suspension and full audit logging.
    """
    permission_classes = [IsAdminOrStaffUser]

    def post(self, request, pk):
        from discovery.models import UserReport
        try:
            report = UserReport.objects.select_related('reported_user', 'reporter').get(pk=pk)
        except UserReport.DoesNotExist:
            return Response({'error': 'Report not found.'}, status=status.HTTP_404_NOT_FOUND)

        action = request.data.get('action', '').strip().lower()
        if action not in ['resolve', 'dismiss', 'under_review', 'review', 'add_note']:
            return Response(
                {'error': "Action must be 'under_review', 'resolve', 'dismiss', or 'add_note'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        prev_status = report.status
        prev_notes = report.admin_notes

        if action == 'resolve':
            report.status = 'resolved'
            report.resolved_by = request.user
            report.resolved_at = timezone.now()
        elif action == 'dismiss':
            report.status = 'dismissed'
            report.resolved_by = request.user
            report.resolved_at = timezone.now()
        elif action in ['under_review', 'review']:
            report.status = 'under_review'

        if 'admin_notes' in request.data:
            report.admin_notes = str(request.data.get('admin_notes', '')).strip()

        report.save(update_fields=['status', 'admin_notes', 'resolved_by', 'resolved_at'])

        # Optional simultaneous user suspension when justified
        user_suspended = False
        if request.data.get('suspend_user') is True:
            reported_user = report.reported_user
            if reported_user.id != request.user.id and not reported_user.is_administrator:
                reported_user.is_suspended = True
                reported_user.is_active = False  # Deactivate session
                reported_user.suspension_reason = (
                    report.admin_notes or f"Suspended following Report #{report.id}: {report.reason}"
                )
                reported_user.save(update_fields=['is_suspended', 'is_active', 'suspension_reason'])
                user_suspended = True

        log_admin_action(
            admin_user=request.user,
            action=f'report_{action}',
            target_model='UserReport',
            target_id=report.id,
            target_repr=f"Report on {report.reported_user.username} by {report.reporter.username}",
            previous_value={'status': prev_status, 'admin_notes': prev_notes},
            new_value={
                'status': report.status,
                'admin_notes': report.admin_notes,
                'user_suspended': user_suspended,
            },
            reason=report.admin_notes or f'Admin {action} report',
            request=request
        )

        return Response({
            'message': f"Report #{report.id} set to '{report.status}'.",
            'id': report.id,
            'status': report.status,
            'admin_notes': report.admin_notes,
            'resolved_by': report.resolved_by.username if report.resolved_by else None,
            'resolved_at': report.resolved_at,
            'user_suspended': user_suspended,
        })
