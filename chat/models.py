from django.db import models
from django.db.models import Q
from django.utils import timezone
from accounts.models import User


class Conversation(models.Model):
    user1 = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='conversations_as_user1'
    )
    user2 = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='conversations_as_user2'
    )
    skill_request = models.ForeignKey(
        'requests.SkillRequest',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='conversations'
    )
    admin_authorized = models.BooleanField(
        default=False,
        help_text='Explicitly authorized by an administrator to allow messaging in legacy conversations.'
    )
    is_locked = models.BooleanField(
        default=False,
        help_text='Locked by an administrator for moderation purposes.'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['user1', 'user2'],
                name='unique_conversation'
            )
        ]

    def get_linked_request(self):
        """
        Return the explicitly linked skill request or find the most relevant
        (accepted first, otherwise latest) skill-swap request between user1 and user2.
        """
        if self.skill_request_id:
            return self.skill_request
        from requests.models import SkillRequest
        pair_qs = SkillRequest.objects.filter(
            (Q(requester_id=self.user1_id, target_id=self.user2_id) |
             Q(requester_id=self.user2_id, target_id=self.user1_id))
        ).select_related('requested_skill', 'offered_skill', 'requester', 'target')
        accepted = pair_qs.filter(status='accepted').order_by('-updated_at').first()
        if accepted:
            return accepted
        return pair_qs.order_by('-created_at').first()

    @property
    def has_accepted_request(self):
        if self.skill_request_id and self.skill_request and self.skill_request.status == 'accepted':
            return True
        from requests.models import SkillRequest
        return SkillRequest.objects.filter(
            (Q(requester_id=self.user1_id, target_id=self.user2_id) |
             Q(requester_id=self.user2_id, target_id=self.user1_id)),
            status='accepted'
        ).exists()

    @property
    def can_send_messages(self):
        if self.is_locked:
            return False
        return self.has_accepted_request or self.admin_authorized

    @property
    def conversation_status(self):
        if self.is_locked:
            return 'restricted'
        if self.has_accepted_request:
            return 'active'
        if self.admin_authorized:
            return 'authorized_legacy'
        return 'read_only_legacy'

    def __str__(self):
        return f"{self.user1.username} - {self.user2.username}"


class Message(models.Model):
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='messages'
    )
    sender = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='sent_messages'
    )
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.sender.username}: {self.message[:30]}"


class MessagingPolicy(models.Model):
    """
    Platform-wide configurable messaging policy & rate-limit settings.
    Default values:
    - 5 messages per minute
    - 50 messages per conversation per day
    - 100 messages per user per day
    - Warning at 80%
    - 15-minute cooldown
    """
    max_messages_per_minute = models.PositiveIntegerField(default=5)
    max_messages_per_conversation_per_day = models.PositiveIntegerField(default=50)
    max_messages_per_user_per_day = models.PositiveIntegerField(default=100)
    warning_threshold_percent = models.PositiveIntegerField(default=80)
    cooldown_minutes = models.PositiveIntegerField(default=15)
    enforce_accepted_request = models.BooleanField(default=True)
    enable_rate_limiting = models.BooleanField(default=True)
    updated_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='updated_messaging_policies'
    )
    updated_at = models.DateTimeField(auto_now=True)

    @classmethod
    def get_policy(cls):
        policy, _ = cls.objects.get_or_create(
            pk=1,
            defaults={
                'max_messages_per_minute': 5,
                'max_messages_per_conversation_per_day': 50,
                'max_messages_per_user_per_day': 100,
                'warning_threshold_percent': 80,
                'cooldown_minutes': 15,
                'enforce_accepted_request': True,
                'enable_rate_limiting': True,
            }
        )
        return policy

    def __str__(self):
        return (
            f"MessagingPolicy({self.max_messages_per_minute}/min, "
            f"{self.max_messages_per_conversation_per_day}/conv/day, "
            f"{self.max_messages_per_user_per_day}/user/day)"
        )


class UserMessagingRestriction(models.Model):
    """
    Temporary cooldowns or administrative messaging restrictions.
    Never permanently bans users based on automated spam detection.
    """
    RESTRICTION_TYPES = [
        ('cooldown', 'Automated Cooldown'),
        ('admin_mute', 'Admin Restriction'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='messaging_restrictions'
    )
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='restrictions'
    )
    restriction_type = models.CharField(
        max_length=30,
        choices=RESTRICTION_TYPES,
        default='cooldown'
    )
    reason = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_messaging_restrictions'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    @property
    def is_currently_active(self):
        if not self.is_active:
            return False
        if self.expires_at and self.expires_at <= timezone.now():
            return False
        return True

    def __str__(self):
        return f"{self.user.username} - {self.restriction_type} (active={self.is_currently_active})"
