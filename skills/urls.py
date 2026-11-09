from django.urls import path
from .views import SkillListView, MySkillsView

urlpatterns = [
    path('', SkillListView.as_view(), name='skill-list'),
    path('my-skills/', MySkillsView.as_view(), name='my-skills'),
    path('my-skills/<int:pk>/', MySkillsView.as_view(), name='my-skill-detail'),
]