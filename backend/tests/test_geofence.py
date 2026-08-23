from app.services.geofence_service import GeofenceService
from app.core.errors import ErrorCode


def test_haversine_distance_same_point():
    # Ala-Too Square, Bishkek
    lat = 42.8765
    lon = 74.6037
    dist = GeofenceService.calculate_haversine_distance(lat, lon, lat, lon)
    assert dist == 0.0


def test_haversine_distance_known_points():
    # Ala-Too Square (42.8765, 74.6037) to Bishkek Park (42.8744, 74.5888) ~ 1.23 km
    dist = GeofenceService.calculate_haversine_distance(42.8765, 74.6037, 42.8744, 74.5888)
    assert 1200 <= dist <= 1260


def test_geofence_inside_allowed_radius():
    # School center: (42.876500, 74.603700)
    # Teacher position: ~30 meters away
    teacher_lat = 42.876700
    teacher_lon = 74.603700
    
    result = GeofenceService.verify_location(
        teacher_lat=teacher_lat,
        teacher_lon=teacher_lon,
        teacher_accuracy=15.0,
        school_lat=42.876500,
        school_lon=74.603700,
        allowed_radius_meters=80.0,
        max_accuracy_meters=50.0,
    )
    assert result.is_valid is True
    assert result.distance_meters < 80.0
    assert result.error_code is None


def test_geofence_outside_allowed_radius():
    # School center: (42.876500, 74.603700)
    # Teacher position: 200 meters away
    teacher_lat = 42.878500
    teacher_lon = 74.603700
    
    result = GeofenceService.verify_location(
        teacher_lat=teacher_lat,
        teacher_lon=teacher_lon,
        teacher_accuracy=10.0,
        school_lat=42.876500,
        school_lon=74.603700,
        allowed_radius_meters=80.0,
        max_accuracy_meters=50.0,
    )
    assert result.is_valid is False
    assert result.error_code == ErrorCode.LOCATION_OUTSIDE_SCHOOL
    assert result.distance_meters > 80.0


def test_geofence_low_gps_accuracy_rejected():
    # Accuracy 65m when maximum allowed is 50m
    result = GeofenceService.verify_location(
        teacher_lat=42.876500,
        teacher_lon=74.603700,
        teacher_accuracy=65.0,
        school_lat=42.876500,
        school_lon=74.603700,
        allowed_radius_meters=80.0,
        max_accuracy_meters=50.0,
    )
    assert result.is_valid is False
    assert result.error_code == ErrorCode.LOCATION_ACCURACY_TOO_LOW
