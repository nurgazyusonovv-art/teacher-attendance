import math
from dataclasses import dataclass
from typing import Optional
from app.core.errors import ErrorCode


@dataclass
class GeofenceVerificationResult:
    is_valid: bool
    distance_meters: float
    accuracy_meters: float
    error_code: Optional[ErrorCode] = None
    error_message: Optional[str] = None


class GeofenceService:
    EARTH_RADIUS_METERS: float = 6371000.0  # Mean radius of Earth

    @classmethod
    def calculate_haversine_distance(
        cls,
        lat1: float,
        lon1: float,
        lat2: float,
        lon2: float,
    ) -> float:
        """
        Calculates the great-circle distance between two points on the Earth surface
        using the Haversine formula. Returns distance in meters.
        """
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)

        a = (
            math.sin(delta_phi / 2.0) ** 2
            + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
        )
        c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
        return cls.EARTH_RADIUS_METERS * c

    @classmethod
    def verify_location(
        cls,
        teacher_lat: float,
        teacher_lon: float,
        teacher_accuracy: float,
        school_lat: float,
        school_lon: float,
        allowed_radius_meters: float,
        max_accuracy_meters: float,
    ) -> GeofenceVerificationResult:
        """
        Verifies whether teacher's GPS location falls within the school's geofence
        and satisfies accuracy requirements.
        """
        # 1. Check GPS accuracy threshold
        if teacher_accuracy > max_accuracy_meters:
            return GeofenceVerificationResult(
                is_valid=False,
                distance_meters=0.0,
                accuracy_meters=teacher_accuracy,
                error_code=ErrorCode.LOCATION_ACCURACY_TOO_LOW,
                error_message=f"GPS accuracy ({teacher_accuracy:.1f}m) is lower than required ({max_accuracy_meters:.1f}m). Please move to an open area and try again."
            )

        # 2. Calculate distance using Haversine formula
        distance = cls.calculate_haversine_distance(
            lat1=teacher_lat,
            lon1=teacher_lon,
            lat2=school_lat,
            lon2=school_lon,
        )

        # 3. Check distance against allowed radius
        if distance > allowed_radius_meters:
            return GeofenceVerificationResult(
                is_valid=False,
                distance_meters=distance,
                accuracy_meters=teacher_accuracy,
                error_code=ErrorCode.LOCATION_OUTSIDE_SCHOOL,
                error_message=f"Location ({distance:.1f}m) is outside the school radius ({allowed_radius_meters:.1f}m)."
            )

        return GeofenceVerificationResult(
            is_valid=True,
            distance_meters=distance,
            accuracy_meters=teacher_accuracy,
            error_code=None,
            error_message=None
        )
