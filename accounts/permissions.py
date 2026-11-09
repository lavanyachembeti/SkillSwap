from rest_framework import permissions


class IsAdminOrStaffUser(permissions.BasePermission):
    """
    Allows access only to administrators, staff, or superusers.
    Ensures existing accounts like Lavanya (role='student', is_staff=True, is_superuser=True)
    and any user with role='admin' retain full administrator access.
    """
    message = 'Administrator access required.'

    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            (
                request.user.role == 'admin' or
                request.user.is_staff or
                request.user.is_superuser
            )
        )
