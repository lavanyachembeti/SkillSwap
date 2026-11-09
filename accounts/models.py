from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    ROLE_CHOICES = [
        ('student', 'Student'),
        ('professional', 'Professional'),
        ('admin', 'Admin'),
    ]

    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default='student'
    )

    phone = models.CharField(
        max_length=15,
        blank=True,
        null=True
    )

    bio = models.TextField(
        blank=True,
        null=True
    )

    profile_image = models.URLField(
        blank=True,
        null=True
    )

    is_verified = models.BooleanField(
        default=False
    )

    is_suspended = models.BooleanField(
        default=False
    )

    suspended_until = models.DateTimeField(
        blank=True,
        null=True
    )

    suspension_reason = models.TextField(
        blank=True,
        null=True
    )

    @property
    def is_administrator(self):
        """
        Determines whether the user has administrator privileges.
        Supports users with role='admin' as well as staff and superusers
        (such as existing super administrator Lavanya).
        """
        return self.role == 'admin' or self.is_staff or self.is_superuser

    @property
    def account_status(self):
        """
        Unified computed account status avoiding duplicate status storage.
        """
        if self.is_suspended:
            return 'suspended'
        if not self.is_active:
            return 'inactive'
        if not self.is_verified:
            return 'pending_verification'
        return 'active'

    def __str__(self):
        return self.username


class AdminAuditLog(models.Model):
    """
    Append-only audit trail recording every administrative operation.
    """
    admin_user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='admin_audit_logs'
    )
    action = models.CharField(max_length=100)
    target_model = models.CharField(max_length=50)
    target_id = models.CharField(max_length=50, blank=True, null=True)
    target_repr = models.CharField(max_length=200, blank=True, null=True)
    previous_value = models.JSONField(blank=True, null=True)
    new_value = models.JSONField(blank=True, null=True)
    reason = models.TextField(blank=True, null=True)
    ip_address = models.GenericIPAddressField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.admin_user.username} - {self.action} on {self.target_model}:{self.target_id}"


class Notification(models.Model):
    NOTIFICATION_TYPES = [
        ('skill_request', 'Skill Request'),
        ('request_accepted', 'Request Accepted'),
        ('request_rejected', 'Request Rejected'),
        ('new_message', 'New Message'),
        ('session_scheduled', 'Session Scheduled'),
        ('session_updated', 'Session Updated'),
        ('session_cancelled', 'Session Cancelled'),
        ('rating_received', 'Rating Received'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    notification_type = models.CharField(
        max_length=30,
        choices=NOTIFICATION_TYPES
    )
    title = models.CharField(max_length=200)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} - {self.title}"