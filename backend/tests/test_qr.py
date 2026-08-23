import json
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_current_school_qr(
    async_client: AsyncClient, admin_auth_headers: dict
):
    response = await async_client.get(
        "/api/v1/qr/current", headers=admin_auth_headers
    )
    assert response.status_code == 200
    data = response.json()
    assert "school_id" in data
    assert "qr_token" in data
    assert "qr_payload" in data

    # Verify payload format is valid JSON and does NOT include teacher identity
    payload_obj = json.loads(data["qr_payload"])
    assert "school_id" in payload_obj
    assert "qr_token" in payload_obj
    assert "teacher_id" not in payload_obj
    assert "user_id" not in payload_obj


@pytest.mark.asyncio
async def test_qr_validation_service(db_session):
    from app.services.qr_service import QrService
    from app.models.school import School
    from app.core.errors import AppException
    from sqlalchemy import select

    res = await db_session.execute(select(School).limit(1))
    school = res.scalar_one()

    qr_info = await QrService.get_active_school_qr(db_session, school.id)

    # Valid token
    valid_cred = await QrService.validate_qr_token(
        db_session, school.id, qr_info.qr_token
    )
    assert valid_cred.is_active is True

    # Invalid token
    with pytest.raises(AppException) as exc_info:
        await QrService.validate_qr_token(db_session, school.id, "invalid-token-xyz")
    assert exc_info.value.code.value == "QR_INVALID"


@pytest.mark.asyncio
async def test_rotate_school_qr_invalidates_previous(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    from app.services.qr_service import QrService
    from app.core.errors import AppException

    curr_res = await async_client.get(
        "/api/v1/qr/current", headers=admin_auth_headers
    )
    initial_qr = curr_res.json()
    school_id = initial_qr["school_id"]
    old_token = initial_qr["qr_token"]

    # Rotate QR
    rotate_res = await async_client.post(
        f"/api/v1/qr/{school_id}/rotate?description=NewTermRotation",
        headers=admin_auth_headers,
    )
    assert rotate_res.status_code == 200
    rotated_qr = rotate_res.json()
    assert rotated_qr["qr_token"] != old_token

    # Verify old token fails validation
    with pytest.raises(AppException) as exc_info:
        await QrService.validate_qr_token(db_session, school_id, old_token)
    assert exc_info.value.code.value == "QR_INVALID"

    # Verify new token succeeds
    valid_cred = await QrService.validate_qr_token(
        db_session, school_id, rotated_qr["qr_token"]
    )
    assert valid_cred.is_active is True
