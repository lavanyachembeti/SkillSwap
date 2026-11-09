from rest_framework import serializers
from .models import Skill, UserSkill


class SkillSerializer(serializers.ModelSerializer):

    class Meta:
        model = Skill
        fields = [
            'id',
            'name',
            'description',
            'category',
            'is_active',
        ]


class UserSkillSerializer(serializers.ModelSerializer):

    skill_name = serializers.CharField(
        source='skill.name',
        read_only=True
    )

    class Meta:
        model = UserSkill
        fields = [
            'id',
            'skill',
            'skill_name',
            'skill_type',
            'proficiency',
            'created_at',
        ]
        read_only_fields = [
            'id',
            'skill_name',
            'created_at',
        ]