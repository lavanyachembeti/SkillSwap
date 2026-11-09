from rest_framework import serializers

from .models import Conversation, Message


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(
        source='sender.username',
        read_only=True
    )

    class Meta:
        model = Message
        fields = [
            'id',
            'conversation',
            'sender',
            'sender_name',
            'message',
            'is_read',
            'created_at',
        ]
        read_only_fields = [
            'id',
            'conversation',
            'sender',
            'sender_name',
            'is_read',
            'created_at',
        ]


class ConversationSerializer(serializers.ModelSerializer):
    user1_name = serializers.CharField(
        source='user1.username',
        read_only=True
    )
    user2_name = serializers.CharField(
        source='user2.username',
        read_only=True
    )
    conversation_status = serializers.CharField(read_only=True)
    can_send_messages = serializers.BooleanField(read_only=True)
    has_accepted_request = serializers.BooleanField(read_only=True)

    class Meta:
        model = Conversation
        fields = [
            'id',
            'user1',
            'user1_name',
            'user2',
            'user2_name',
            'skill_request',
            'admin_authorized',
            'is_locked',
            'conversation_status',
            'can_send_messages',
            'has_accepted_request',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'user1',
            'user1_name',
            'user2_name',
            'skill_request',
            'admin_authorized',
            'is_locked',
            'conversation_status',
            'can_send_messages',
            'has_accepted_request',
            'created_at',
            'updated_at',
        ]
