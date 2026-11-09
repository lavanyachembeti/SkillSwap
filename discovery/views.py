from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from accounts.models import User, Notification
from skills.models import UserSkill

from .models import (
    Availability,
    Session,
    Rating,
    UserReport,
    UserBlock,
)

from .serializers import (
    DiscoverUserSerializer,
    AvailabilitySerializer,
    SessionSerializer,
    RatingSerializer,
    UserReportSerializer,
    UserBlockSerializer,
)


class DiscoverUsersView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        blocked_user_ids = UserBlock.objects.filter(
            blocker=request.user
        ).values_list(
            'blocked_user_id',
            flat=True
        )

        users = User.objects.filter(
            is_active=True
        ).exclude(
            id=request.user.id
        ).exclude(
            id__in=blocked_user_ids
        )

        serializer = DiscoverUserSerializer(
            users,
            many=True
        )

        return Response(serializer.data)


class AvailabilityListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        availabilities = Availability.objects.filter(
            user=request.user
        )

        serializer = AvailabilitySerializer(
            availabilities,
            many=True
        )

        return Response(serializer.data)

    def post(self, request):
        serializer = AvailabilitySerializer(
            data=request.data
        )

        if serializer.is_valid():
            availability = serializer.save(
                user=request.user
            )

            return Response(
                AvailabilitySerializer(availability).data,
                status=201
            )

        return Response(
            serializer.errors,
            status=400
        )


class MatchingUsersView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        my_learning_skills = UserSkill.objects.filter(
            user=request.user,
            skill_type='learn'
        ).values_list(
            'skill_id',
            flat=True
        )

        blocked_user_ids = UserBlock.objects.filter(
            blocker=request.user
        ).values_list(
            'blocked_user_id',
            flat=True
        )

        matching_users = User.objects.filter(
            is_active=True,
            user_skills__skill_id__in=my_learning_skills,
            user_skills__skill_type='teach'
        ).exclude(
            id=request.user.id
        ).exclude(
            id__in=blocked_user_ids
        ).distinct()

        serializer = DiscoverUserSerializer(
            matching_users,
            many=True
        )

        return Response(serializer.data)


class SessionListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        sessions = Session.objects.filter(
            learner=request.user
        ) | Session.objects.filter(
            teacher=request.user
        )

        sessions = sessions.distinct().order_by(
            'scheduled_date',
            'start_time'
        )

        serializer = SessionSerializer(
            sessions,
            many=True
        )

        return Response(serializer.data)

    def post(self, request):
        serializer = SessionSerializer(
            data=request.data
        )

        if serializer.is_valid():

            skill_request = serializer.validated_data[
                'skill_request'
            ]

            learner = skill_request.requester
            teacher = skill_request.target

            if request.user.id not in [
                learner.id,
                teacher.id
            ]:
                return Response(
                    {
                        'error': 'You are not part of this skill request.'
                    },
                    status=403
                )

            session = serializer.save(
                learner=learner,
                teacher=teacher
            )

            # Notify the other participant
            notification_user = (
                teacher
                if request.user.id == learner.id
                else learner
            )

            Notification.objects.create(
                user=notification_user,
                notification_type='session_scheduled',
                title='Session Scheduled',
                message=(
                    f'{request.user.username} scheduled a session with you '
                    f'on {session.scheduled_date} at {session.start_time}.'
                )
            )

            return Response(
                SessionSerializer(session).data,
                status=201
            )

        return Response(
            serializer.errors,
            status=400
        )


class RatingListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        ratings = Rating.objects.filter(
            rated_user=request.user
        )

        serializer = RatingSerializer(
            ratings,
            many=True
        )

        return Response(serializer.data)

    def post(self, request):
        session_id = request.data.get('session')
        score = request.data.get('score')
        review = request.data.get('review')

        if not session_id:
            return Response(
                {
                    'error': 'Session is required.'
                },
                status=400
            )

        try:
            session = Session.objects.get(
                id=session_id
            )

        except Session.DoesNotExist:
            return Response(
                {
                    'error': 'Session not found.'
                },
                status=404
            )

        if request.user.id not in [
            session.teacher_id,
            session.learner_id
        ]:
            return Response(
                {
                    'error': 'You are not part of this session.'
                },
                status=403
            )

        if session.status != 'completed':
            return Response(
                {
                    'error': 'You can rate only a completed session.'
                },
                status=400
            )

        rated_user = (
            session.learner
            if request.user.id == session.teacher_id
            else session.teacher
        )

        if Rating.objects.filter(
            session=session,
            rater=request.user
        ).exists():
            return Response(
                {
                    'error': 'You have already rated this session.'
                },
                status=400
            )

        data = {
            'session': session.id,
            'score': score,
            'review': review,
        }

        serializer = RatingSerializer(
            data=data
        )

        if serializer.is_valid():

            rating = serializer.save(
                rater=request.user,
                rated_user=rated_user
            )

            # Notify the person who received the rating
            Notification.objects.create(
                user=rated_user,
                notification_type='rating_received',
                title='New Rating Received',
                message=(
                    f'{request.user.username} gave you a '
                    f'{rating.score}/5 rating.'
                )
            )

            return Response(
                RatingSerializer(rating).data,
                status=201
            )

        return Response(
            serializer.errors,
            status=400
        )


class UserReportListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        reports = UserReport.objects.filter(
            reporter=request.user
        )

        serializer = UserReportSerializer(
            reports,
            many=True
        )

        return Response(serializer.data)

    def post(self, request):
        reported_user_id = request.data.get(
            'reported_user'
        )

        if not reported_user_id:
            return Response(
                {
                    'error': 'reported_user is required.'
                },
                status=400
            )

        if int(reported_user_id) == request.user.id:
            return Response(
                {
                    'error': 'You cannot report yourself.'
                },
                status=400
            )

        try:
            reported_user = User.objects.get(
                id=reported_user_id,
                is_active=True
            )

        except User.DoesNotExist:
            return Response(
                {
                    'error': 'User not found.'
                },
                status=404
            )

        data = request.data.copy()
        data['reported_user'] = reported_user.id

        serializer = UserReportSerializer(
            data=data
        )

        if serializer.is_valid():

            report = serializer.save(
                reporter=request.user
            )

            return Response(
                UserReportSerializer(report).data,
                status=201
            )

        return Response(
            serializer.errors,
            status=400
        )


class UserBlockListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        blocks = UserBlock.objects.filter(
            blocker=request.user
        )

        serializer = UserBlockSerializer(
            blocks,
            many=True
        )

        return Response(serializer.data)

    def post(self, request):
        blocked_user_id = request.data.get(
            'blocked_user'
        )

        if not blocked_user_id:
            return Response(
                {
                    'error': 'blocked_user is required.'
                },
                status=400
            )

        if int(blocked_user_id) == request.user.id:
            return Response(
                {
                    'error': 'You cannot block yourself.'
                },
                status=400
            )

        try:
            blocked_user = User.objects.get(
                id=blocked_user_id,
                is_active=True
            )

        except User.DoesNotExist:
            return Response(
                {
                    'error': 'User not found.'
                },
                status=404
            )

        if UserBlock.objects.filter(
            blocker=request.user,
            blocked_user=blocked_user
        ).exists():
            return Response(
                {
                    'error': 'User is already blocked.'
                },
                status=400
            )

        block = UserBlock.objects.create(
            blocker=request.user,
            blocked_user=blocked_user
        )

        return Response(
            UserBlockSerializer(block).data,
            status=201
        )
class SessionCancelView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request, pk):
        try:
            session = Session.objects.get(id=pk)
        except Session.DoesNotExist:
            return Response(
                {
                    'error': 'Session not found.'
                },
                status=404
            )

        # Check whether the current user is part of the session
        if request.user.id not in [
            session.teacher_id,
            session.learner_id
        ]:
            return Response(
                {
                    'error': 'You are not part of this session.'
                },
                status=403
            )

        # Only scheduled sessions can be cancelled
        if session.status != 'scheduled':
            return Response(
                {
                    'error': 'Only scheduled sessions can be cancelled.'
                },
                status=400
            )

        # Cancel the session
        session.status = 'cancelled'
        session.save(update_fields=['status'])

        # Find the other participant
        other_user = (
            session.teacher
            if request.user.id == session.learner_id
            else session.learner
        )

        # Create notification
        Notification.objects.create(
            user=other_user,
            notification_type='session_cancelled',
            title='Session Cancelled',
            message=(
                f'{request.user.username} cancelled the session '
                f'scheduled for {session.scheduled_date} '
                f'at {session.start_time}.'
            )
        )

        return Response(
            {
                'message': 'Session cancelled successfully.',
                'session_id': session.id,
                'status': session.status
            },
            status=200
        )
class SessionUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request, pk):
        try:
            session = Session.objects.get(id=pk)
        except Session.DoesNotExist:
            return Response(
                {
                    'error': 'Session not found.'
                },
                status=404
            )

        # Check whether the current user is part of the session
        if request.user.id not in [
            session.teacher_id,
            session.learner_id
        ]:
            return Response(
                {
                    'error': 'You are not part of this session.'
                },
                status=403
            )

        # Only scheduled sessions can be updated
        if session.status != 'scheduled':
            return Response(
                {
                    'error': 'Only scheduled sessions can be updated.'
                },
                status=400
            )

        # Update allowed fields
        if 'scheduled_date' in request.data:
            session.scheduled_date = request.data['scheduled_date']

        if 'start_time' in request.data:
            session.start_time = request.data['start_time']

        if 'end_time' in request.data:
            session.end_time = request.data['end_time']

        if 'mode' in request.data:
            session.mode = request.data['mode']

        if 'meeting_link' in request.data:
            session.meeting_link = request.data['meeting_link']

        # Validate that start time is before end time
        if session.start_time >= session.end_time:
            return Response(
                {
                    'error': 'Start time must be before end time.'
                },
                status=400
            )

        session.save()

        # Find the other participant
        other_user = (
            session.teacher
            if request.user.id == session.learner_id
            else session.learner
        )

        # Create notification
        Notification.objects.create(
            user=other_user,
            notification_type='session_updated',
            title='Session Updated',
            message=(
                f'{request.user.username} updated the session '
                f'scheduled for {session.scheduled_date} '
                f'at {session.start_time}.'
            )
        )

        return Response(
            {
                'message': 'Session updated successfully.',
                'session': SessionSerializer(session).data
            },
            status=200
        )