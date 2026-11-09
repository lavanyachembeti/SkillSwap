from django.urls import path
from .views import (
    DiscoverUsersView,
    AvailabilityListCreateView,
    MatchingUsersView,
)
from .views import (
    DiscoverUsersView,
    AvailabilityListCreateView,
    MatchingUsersView,
    SessionListCreateView,
    RatingListCreateView,
    UserReportListCreateView,
    UserBlockListCreateView,
)
from .views import (
    DiscoverUsersView,
    AvailabilityListCreateView,
    MatchingUsersView,
    SessionListCreateView,
    SessionCancelView,
    RatingListCreateView,
    UserReportListCreateView,
    UserBlockListCreateView,
)
from .views import (
    DiscoverUsersView,
    AvailabilityListCreateView,
    MatchingUsersView,
    SessionListCreateView,
    SessionCancelView,
    SessionUpdateView,
    RatingListCreateView,
    UserReportListCreateView,
    UserBlockListCreateView,
)

urlpatterns = [
    path(
        'users/',
        DiscoverUsersView.as_view(),
        name='discover-users'
    ),
    path(
        'availability/',
        AvailabilityListCreateView.as_view(),
        name='availability-list-create'
    ),
    path(
        'matching/',
        MatchingUsersView.as_view(),
        name='matching-users'
    ),
    path(
    'sessions/',
    SessionListCreateView.as_view(),
    name='session-list-create'
),
path('ratings/', RatingListCreateView.as_view(), name='rating-list-create'),
path('reports/', UserReportListCreateView.as_view(), name='report-list-create'),
path('blocks/', UserBlockListCreateView.as_view(), name='block-list-create'),
path(
    'sessions/<int:pk>/cancel/',
    SessionCancelView.as_view(),
    name='session-cancel'
),
path(
    'sessions/<int:pk>/update/',
    SessionUpdateView.as_view(),
    name='session-update'
),
]