from django.contrib import admin
from django.urls import include, path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView


urlpatterns = [
    path('admin/', admin.site.urls),

    path('api/auth/', include('accounts.urls')),

    path('api/auth/login/', TokenObtainPairView.as_view(), name='login'),
    path('api/auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    path('api/skills/', include('skills.urls')),

    path('api/discovery/', include('discovery.urls')),
    path('api/requests/', include('requests.urls')),
    path('api/chat/', include('chat.urls')),
    path('api/admin/', include('accounts.admin_urls')),
]