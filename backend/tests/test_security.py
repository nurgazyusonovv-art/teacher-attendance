from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.models.enums import UserRole


def test_password_hashing_and_verification():
    raw_pass = "MySecretPass123!"
    hashed = get_password_hash(raw_pass)
    assert hashed != raw_pass
    assert verify_password(raw_pass, hashed) is True
    assert verify_password("WrongPassword", hashed) is False


def test_jwt_access_token_creation_and_decoding():
    user_id = "user-12345"
    school_id = "school-67890"
    role = UserRole.TEACHER.value

    token = create_access_token(
        subject=user_id,
        role=role,
        school_id=school_id,
    )
    assert isinstance(token, str)

    payload = decode_token(token)
    assert payload["sub"] == user_id
    assert payload["role"] == role
    assert payload["school_id"] == school_id
    assert payload["type"] == "access"


def test_jwt_refresh_token_creation_and_decoding():
    user_id = "user-12345"
    token = create_refresh_token(subject=user_id)
    assert isinstance(token, str)

    payload = decode_token(token)
    assert payload["sub"] == user_id
    assert payload["type"] == "refresh"
