from django.urls import path

from .views import (
    SkillRequestListCreateView,
    SkillRequestActionView
)

urlpatterns = [
    path('', SkillRequestListCreateView.as_view(), name='request-list-create'),
    path('<int:pk>/', SkillRequestActionView.as_view(), name='request-action'),
]