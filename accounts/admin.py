from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import AdminAuditLog, Notification, User


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = (
        'username',
        'email',
        'role',
        'phone',
        'is_verified',
        'is_suspended',
        'is_active',
        'is_staff',
    )

    list_filter = (
        'role',
        'is_verified',
        'is_suspended',
        'is_active',
        'is_staff',
    )

    search_fields = (
        'username',
        'email',
        'phone',
    )

    fieldsets = UserAdmin.fieldsets + (
        (
            'SkillSwap Information',
            {
                'fields': (
                    'role',
                    'phone',
                    'bio',
                    'profile_image',
                    'is_verified',
                    'is_suspended',
                    'suspended_until',
                    'suspension_reason',
                )
            }
        ),
    )


@admin.register(AdminAuditLog)
class AdminAuditLogAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'admin_user',
        'action',
        'target_model',
        'target_id',
        'created_at',
    )
    list_filter = (
        'action',
        'target_model',
        'created_at',
    )
    search_fields = (
        'admin_user__username',
        'action',
        'target_repr',
        'reason',
    )
    readonly_fields = [f.name for f in AdminAuditLog._meta.fields]

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'user',
        'notification_type',
        'title',
        'is_read',
        'created_at',
    )

    list_filter = (
        'notification_type',
        'is_read',
        'created_at',
    )

    search_fields = (
        'user__username',
        'title',
        'message',
    )