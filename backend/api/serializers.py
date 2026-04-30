from rest_framework import serializers

from .models import Study, Submission


class StudySerializer(serializers.ModelSerializer):
    class Meta:
        model = Study
        fields = ("id", "name", "created_at")
        read_only_fields = ("id", "created_at")


class StudyCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Study
        fields = ("name",)

    def validate_name(self, value: str) -> str:
        name = value.strip()
        if not name:
            raise serializers.ValidationError("Name must not be empty.")
        if len(name) > 255:
            raise serializers.ValidationError("Name too long.")
        return name


class SubmissionCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Submission
        fields = ("content",)

    def validate_content(self, value: str) -> str:
        if len(value) > 2000:
            raise serializers.ValidationError("Content must be at most 2000 characters.")
        return value


class SubmissionDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = Submission
        fields = ("study_id", "submission_id", "content", "status", "created_at")
        read_only_fields = fields
