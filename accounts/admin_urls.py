from django.urls import path
from .admin_views import (
    AdminAuditLogListView,
    AdminConversationManagementView,
    AdminConversationMessagesView,
    AdminConversationStatusView,
    AdminDashboardStatsView,
    AdminMessagingPolicyView,
    AdminMessagingRestrictionListView,
    AdminMessagingRestrictionReleaseView,
    AdminReportManagementView,
    AdminReportResolveView,
    AdminRequestManagementView,
    AdminRequestStatusView,
    AdminSkillDetailView,
    AdminSkillManagementView,
    AdminUserDetailView,
    AdminUserListView,
    AdminUserStatusView,
    AdminUserVerifyView,
)

urlpatterns = [
    # Dashboard Overview Statistics
    path('dashboard-stats/', AdminDashboardStatsView.as_view(), name='admin-dashboard-stats'),

    # User Management
    path('users/', AdminUserListView.as_view(), name='admin-user-list'),
    path('users/<int:pk>/', AdminUserDetailView.as_view(), name='admin-user-detail'),
    path('users/<int:pk>/verify/', AdminUserVerifyView.as_view(), name='admin-user-verify'),
    path('users/<int:pk>/status/', AdminUserStatusView.as_view(), name='admin-user-status'),

    # Skill Management
    path('skills/', AdminSkillManagementView.as_view(), name='admin-skills'),
    path('skills/<int:pk>/', AdminSkillDetailView.as_view(), name='admin-skill-detail'),

    # Skill Request Management
    path('requests/', AdminRequestManagementView.as_view(), name='admin-requests'),
    path('requests/<int:pk>/status/', AdminRequestStatusView.as_view(), name='admin-request-status'),

    # Chat & Messaging Management
    path('conversations/', AdminConversationManagementView.as_view(), name='admin-conversations'),
    path('conversations/<int:pk>/messages/', AdminConversationMessagesView.as_view(), name='admin-conversation-messages'),
    path('conversations/<int:pk>/status/', AdminConversationStatusView.as_view(), name='admin-conversation-status'),
    path('messaging-policy/', AdminMessagingPolicyView.as_view(), name='admin-messaging-policy'),
    path('messaging-restrictions/', AdminMessagingRestrictionListView.as_view(), name='admin-messaging-restrictions'),
    path('messaging-restrictions/<int:pk>/release/', AdminMessagingRestrictionReleaseView.as_view(), name='admin-messaging-restriction-release'),

    # Reports Management
    path('reports/', AdminReportManagementView.as_view(), name='admin-reports'),
    path('reports/<int:pk>/resolve/', AdminReportResolveView.as_view(), name='admin-report-resolve'),

    # Audit Logs
    path('audit-logs/', AdminAuditLogListView.as_view(), name='admin-audit-logs'),
]
