from django.contrib import admin

from .models import Skill, UserSkill


@admin.register(Skill)
class SkillAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'name',
        'category',
        'is_active',
        'created_at',
    )

    list_filter = (
        'category',
        'is_active',
    )

    search_fields = (
        'name',
        'category',
        'description',
    )


@admin.register(UserSkill)
class UserSkillAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'user',
        'skill',
        'skill_type',
        'proficiency',
        'created_at',
    )

    list_filter = (
        'skill_type',
        'proficiency',
    )

    search_fields = (
        'user__username',
        'skill__name',
    )