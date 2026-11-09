from django.urls import path

from .views import (
    ConversationListCreateView,
    ConversationMessagesView
)

urlpatterns = [
    path(
        'conversations/',
        ConversationListCreateView.as_view(),
        name='conversation-list-create'
    ),

    path(
        'conversations/<int:conversation_id>/messages/',
        ConversationMessagesView.as_view(),
        name='conversation-messages'
    ),
]