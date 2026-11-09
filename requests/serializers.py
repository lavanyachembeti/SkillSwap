
from rest_framework import serializers
from .models import SkillRequest


class SkillRequestSerializer(serializers.ModelSerializer):

    requester_name = serializers.CharField(
        source='requester.username',
        read_only=True
    )

    target_name = serializers.CharField(
        source='target.username',
        read_only=True
    )

    requested_skill_name = serializers.CharField(
        source='requested_skill.name',
        read_only=True
    )

    offered_skill_name = serializers.CharField(
        source='offered_skill.name',
        read_only=True
    )

    class Meta:
        model = SkillRequest
        fields = [
            'id',
            'requester',
            'requester_name',
            'target',
            'target_name',
            'requested_skill',
            'requested_skill_name',
            'offered_skill',
            'offered_skill_name',
            'message',
            'learning_goal',
            'status',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'requester',
            'requester_name',
            'target_name',
            'requested_skill_name',
            'offered_skill_name',
            'status',
            'created_at',
            'updated_at',
        ]