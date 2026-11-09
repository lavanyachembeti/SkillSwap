from django.contrib import admin

from .models import (
    Availability,
    Session,
    Rating,
    UserReport,
    UserBlock,
)


@admin.register(Availability)
class AvailabilityAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'user',
        'day',
        'start_time',
        'end_time',
        'mode',
    )

    list_filter = (
        'day',
        'mode',
    )

    search_fields = (
        'user__username',
    )


@admin.register(Session)
class SessionAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'teacher',
        'learner',
        'scheduled_date',
        'start_time',
        'end_time',
        'mode',
        'status',
    )

    list_filter = (
        'status',
        'mode',
        'scheduled_date',
    )

    search_fields = (
        'teacher__username',
        'learner__username',
    )


@admin.register(Rating)
class RatingAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'session',
        'rater',
        'rated_user',
        'score',
        'created_at',
    )

    list_filter = (
        'score',
        'created_at',
    )

    search_fields = (
        'rater__username',
        'rated_user__username',
        'review',
    )


@admin.register(UserReport)
class UserReportAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'reporter',
        'reported_user',
        'reason',
        'created_at',
    )

    list_filter = (
        'reason',
        'created_at',
    )

    search_fields = (
        'reporter__username',
        'reported_user__username',
        'description',
    )


@admin.register(UserBlock)
class UserBlockAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'blocker',
        'blocked_user',
        'created_at',
    )

    search_fields = (
        'blocker__username',
        'blocked_user__username',
    )