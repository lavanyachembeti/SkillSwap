from django.urls import path
from .views import (
    RegisterView,
    MyProfileView,
    NotificationListView,
    NotificationReadView,
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('profile/', MyProfileView.as_view(), name='profile'),
    path(
    'notifications/',
    NotificationListView.as_view(),
    name='notification-list'
),
path(
    'notifications/<int:pk>/read/',
    NotificationReadView.as_view(),
    name='notification-read'
),
]