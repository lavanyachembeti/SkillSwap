from django.contrib import admin
from .models import Conversation, Message, MessagingPolicy, UserMessagingRestriction


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ('id', 'user1', 'user2', 'skill_request', 'admin_authorized', 'is_locked', 'created_at', 'updated_at')
    list_filter = ('admin_authorized', 'is_locked', 'created_at')
    search_fields = ('user1__username', 'user2__username')


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ('id', 'conversation', 'sender', 'is_read', 'created_at')
    list_filter = ('is_read', 'created_at')
    search_fields = ('sender__username', 'message')


@admin.register(MessagingPolicy)
class MessagingPolicyAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'max_messages_per_minute',
        'max_messages_per_conversation_per_day',
        'max_messages_per_user_per_day',
        'warning_threshold_percent',
        'cooldown_minutes',
        'enforce_accepted_request',
        'enable_rate_limiting',
        'updated_at',
    )


@admin.register(UserMessagingRestriction)
class UserMessagingRestrictionAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'restriction_type', 'is_active', 'expires_at', 'created_by', 'created_at')
    list_filter = ('restriction_type', 'is_active')
    search_fields = ('user__username', 'reason')
