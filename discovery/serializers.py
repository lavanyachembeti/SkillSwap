from rest_framework import serializers
from accounts.models import User
from skills.models import UserSkill
from .models import Availability, Session, Rating, UserReport, UserBlock


class DiscoverUserSerializer(serializers.ModelSerializer):

    skills_teach = serializers.SerializerMethodField()
    skills_learn = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'bio',
            'profile_image',
            'skills_teach',
            'skills_learn',
        ]

    def get_skills_teach(self, obj):
        skills = UserSkill.objects.filter(
            user=obj,
            skill_type='teach'
        )

        return [
            {
                'id': item.skill.id,
                'name': item.skill.name,
                'proficiency': item.proficiency,
            }
            for item in skills
        ]

    def get_skills_learn(self, obj):
        skills = UserSkill.objects.filter(
            user=obj,
            skill_type='learn'
        )

        return [
            {
                'id': item.skill.id,
                'name': item.skill.name,
                'proficiency': item.proficiency,
            }
            for item in skills
        ]


class AvailabilitySerializer(serializers.ModelSerializer):

    class Meta:
        model = Availability
        fields = [
            'id',
            'day',
            'start_time',
            'end_time',
            'mode',
            'created_at',
        ]
        read_only_fields = [
            'id',
            'created_at',
        ]

    def validate(self, data):
        if data['start_time'] >= data['end_time']:
            raise serializers.ValidationError(
                "End time must be after start time."
            )

        return data
class SessionSerializer(serializers.ModelSerializer):

    teacher_name = serializers.CharField(
        source='teacher.username',
        read_only=True
    )

    learner_name = serializers.CharField(
        source='learner.username',
        read_only=True
    )

    class Meta:
        model = Session
        fields = [
            'id',
            'skill_request',
            'teacher',
            'teacher_name',
            'learner',
            'learner_name',
            'scheduled_date',
            'start_time',
            'end_time',
            'mode',
            'meeting_link',
            'status',
            'created_at',
        ]

        read_only_fields = [
            'id',
            'teacher',
            'learner',
            'teacher_name',
            'learner_name',
            'status',
            'created_at',
        ]
class RatingSerializer(serializers.ModelSerializer):
    rater_name = serializers.CharField(
        source='rater.username',
        read_only=True
    )
    rated_user_name = serializers.CharField(
        source='rated_user.username',
        read_only=True
    )

    class Meta:
        model = Rating
        fields = [
            'id',
            'session',
            'rater',
            'rater_name',
            'rated_user',
            'rated_user_name',
            'score',
            'review',
            'created_at',
        ]
        read_only_fields = [
            'id',
            'rater',
            'rater_name',
            'rated_user',
            'rated_user_name',
            'created_at',
        ]

    def validate_score(self, value):
        if value < 1 or value > 5:
            raise serializers.ValidationError(
                "Score must be between 1 and 5."
            )
        return value
class UserReportSerializer(serializers.ModelSerializer):
    reporter_name = serializers.CharField(
        source='reporter.username',
        read_only=True
    )
    reported_user_name = serializers.CharField(
        source='reported_user.username',
        read_only=True
    )

    class Meta:
        model = UserReport
        fields = [
            'id',
            'reporter',
            'reporter_name',
            'reported_user',
            'reported_user_name',
            'reason',
            'description',
            'created_at',
        ]
        read_only_fields = [
            'id',
            'reporter',
            'reporter_name',
            'reported_user_name',
            'created_at',
        ]


class UserBlockSerializer(serializers.ModelSerializer):
    blocker_name = serializers.CharField(
        source='blocker.username',
        read_only=True
    )
    blocked_user_name = serializers.CharField(
        source='blocked_user.username',
        read_only=True
    )

    class Meta:
        model = UserBlock
        fields = [
            'id',
            'blocker',
            'blocker_name',
            'blocked_user',
            'blocked_user_name',
            'created_at',
        ]
        read_only_fields = [
            'id',
            'blocker',
            'blocker_name',
            'blocked_user_name',
            'created_at',
        ]
