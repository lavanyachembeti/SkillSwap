from rest_framework.views import APIView
from rest_framework.response import Response

from .models import Skill
from .serializers import SkillSerializer
from rest_framework.permissions import IsAuthenticated
from rest_framework import status

from .models import Skill, UserSkill
from .serializers import SkillSerializer, UserSkillSerializer


class SkillListView(APIView):

    def get(self, request):

        skills = Skill.objects.filter(is_active=True)

        serializer = SkillSerializer(skills, many=True)

        return Response(serializer.data)
class MySkillsView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request):

        user_skills = UserSkill.objects.filter(
            user=request.user
        )

        serializer = UserSkillSerializer(
            user_skills,
            many=True
        )

        return Response(serializer.data)

    def post(self, request):

        serializer = UserSkillSerializer(
            data=request.data
        )

        if serializer.is_valid():

            user_skill = serializer.save(
                user=request.user
            )

            return Response(
                UserSkillSerializer(user_skill).data,
                status=status.HTTP_201_CREATED
            )

        return Response(
            serializer.errors,
            status=status.HTTP_400_BAD_REQUEST
        )

    def delete(self, request, pk):

        try:
            user_skill = UserSkill.objects.get(
                id=pk,
                user=request.user
            )
        except UserSkill.DoesNotExist:
            return Response(
                {
                    'error': 'Skill not found'
                },
                status=status.HTTP_404_NOT_FOUND
            )

        user_skill.delete()

        return Response(
            {
                'message': 'Skill removed successfully'
            },
            status=status.HTTP_204_NO_CONTENT
        )