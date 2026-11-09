from django.db import models
from accounts.models import User
from skills.models import Skill


class SkillRequest(models.Model):

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
        ('cancelled', 'Cancelled'),
    ]

    requester = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='sent_requests'
    )

    target = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='received_requests'
    )

    requested_skill = models.ForeignKey(
        Skill,
        on_delete=models.CASCADE,
        related_name='skill_requests'
    )

    offered_skill = models.ForeignKey(
        Skill,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='offered_requests'
    )

    message = models.TextField(blank=True, null=True)

    learning_goal = models.TextField(blank=True, null=True)

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending'
    )

    created_at = models.DateTimeField(auto_now_add=True)

    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return (
            f"{self.requester.username} → "
            f"{self.target.username} "
            f"({self.requested_skill.name})"
        )