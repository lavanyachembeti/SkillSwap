from django.contrib import admin

from .models import SkillRequest


@admin.register(SkillRequest)
class SkillRequestAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'requester',
        'target',
        'requested_skill',
        'offered_skill',
        'status',
        'created_at',
    )

    list_filter = (
        'status',
        'created_at',
    )

    search_fields = (
        'requester__username',
        'target__username',
        'requested_skill__name',
        'offered_skill__name',
        'message',
    )