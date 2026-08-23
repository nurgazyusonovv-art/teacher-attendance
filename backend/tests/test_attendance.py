import json
import uuid
from datetime import date, datetime
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from app.models.school import School
from app.models.teacher import Teacher
from app.models.user import User
from app.services.qr_service import QrService


async def create_fresh_teacher(async_client: AsyncClient, admin_auth_headers: dict) -> dict:
    uid = uuid.uuid4().hex[:6]
    username = f"t_{uid}"
    pwd = "password123"
    t_data = {
        "full_name": f"Teacher {uid}",
        "username": username,
        "password": pwd,
        "employee_code": f"EMP-{uid}",
        "subject": "Математика",
    }
    await async_client.post("/api/v1/teachers", json=t_data, headers=admin_auth_headers)
    login_res = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": username, "password": pwd},
    )
    token = login_res.json()["data"]["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_full_attendance_flow_checkin_and_checkout(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    # 1. Fetch school & QR info
    school_res = await db_session.execute(select(School).limit(1))
    school = school_res.scalar_one()
    qr_info = await QrService.get_active_school_qr(db_session, school.id)

    teacher_headers = await create_fresh_teacher(async_client, admin_auth_headers)

    # 2. Check-in inside school radius (exact coords)
    checkin_payload = {
        "school_id": school.id,
        "qr_token": qr_info.qr_token,
        "latitude": school.latitude,
        "longitude": school.longitude,
        "accuracy": 12.5,
        "device_info": "iPhone 15 Pro",
    }
    checkin_res = await async_client.post(
        "/api/v1/attendance/check-in",
        json=checkin_payload,
        headers=teacher_headers,
    )
    assert checkin_res.status_code == 200
    data = checkin_res.json()
    assert data["check_in_time"] is not None
    assert data["late_minutes"] >= 0

    # 3. Duplicate check-in should be rejected
    dup_res = await async_client.post(
        "/api/v1/attendance/check-in",
        json=checkin_payload,
        headers=teacher_headers,
    )
    assert dup_res.status_code == 400
    assert dup_res.json()["code"] == "ALREADY_CHECKED_IN"

    # 4. Check today status
    status_res = await async_client.get(
        "/api/v1/attendance/today",
        headers=teacher_headers,
    )
    assert status_res.status_code == 200
    status_data = status_res.json()
    assert status_data["has_checked_in"] is True
    assert status_data["has_checked_out"] is False

    # 5. Check-out
    checkout_res = await async_client.post(
        "/api/v1/attendance/check-out",
        json=checkin_payload,
        headers=teacher_headers,
    )
    assert checkout_res.status_code == 200
    co_data = checkout_res.json()
    assert co_data["check_out_time"] is not None

    # 6. Duplicate check-out should be rejected
    dup_co_res = await async_client.post(
        "/api/v1/attendance/check-out",
        json=checkin_payload,
        headers=teacher_headers,
    )
    assert dup_co_res.status_code == 400
    assert dup_co_res.json()["code"] == "ALREADY_CHECKED_OUT"


@pytest.mark.asyncio
async def test_checkin_outside_geofence_rejected(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    school_res = await db_session.execute(select(School).limit(1))
    school = school_res.scalar_one()
    qr_info = await QrService.get_active_school_qr(db_session, school.id)
    teacher_headers = await create_fresh_teacher(async_client, admin_auth_headers)

    # Location 5km away
    outside_payload = {
        "school_id": school.id,
        "qr_token": qr_info.qr_token,
        "latitude": school.latitude + 0.05,
        "longitude": school.longitude + 0.05,
        "accuracy": 15.0,
    }
    res = await async_client.post(
        "/api/v1/attendance/check-in",
        json=outside_payload,
        headers=teacher_headers,
    )
    assert res.status_code == 400
    assert res.json()["code"] == "LOCATION_OUTSIDE_SCHOOL"


@pytest.mark.asyncio
async def test_checkin_low_accuracy_rejected(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    school_res = await db_session.execute(select(School).limit(1))
    school = school_res.scalar_one()
    qr_info = await QrService.get_active_school_qr(db_session, school.id)
    teacher_headers = await create_fresh_teacher(async_client, admin_auth_headers)

    # Low accuracy (150m > 50m limit)
    low_acc_payload = {
        "school_id": school.id,
        "qr_token": qr_info.qr_token,
        "latitude": school.latitude,
        "longitude": school.longitude,
        "accuracy": 150.0,
    }
    res = await async_client.post(
        "/api/v1/attendance/check-in",
        json=low_acc_payload,
        headers=teacher_headers,
    )
    assert res.status_code == 400
    assert res.json()["code"] == "LOCATION_ACCURACY_TOO_LOW"


@pytest.mark.asyncio
async def test_checkin_invalid_qr_rejected(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    school_res = await db_session.execute(select(School).limit(1))
    school = school_res.scalar_one()
    teacher_headers = await create_fresh_teacher(async_client, admin_auth_headers)

    invalid_qr_payload = {
        "school_id": school.id,
        "qr_token": "fake-qr-token-12345",
        "latitude": school.latitude,
        "longitude": school.longitude,
        "accuracy": 10.0,
    }
    res = await async_client.post(
        "/api/v1/attendance/check-in",
        json=invalid_qr_payload,
        headers=teacher_headers,
    )
    assert res.status_code == 400
    assert res.json()["code"] == "QR_INVALID"


@pytest.mark.asyncio
async def test_demo_account_bypasses_geofence(
    async_client: AsyncClient, db_session
):
    school_res = await db_session.execute(select(School).limit(1))
    school = school_res.scalar_one()
    qr_info = await QrService.get_active_school_qr(db_session, school.id)

    # Login as demo_teacher
    demo_login = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "demo_teacher", "password": "demo123"},
    )
    demo_headers = {"Authorization": f"Bearer {demo_login.json()['data']['access_token']}"}

    # Demo teacher anywhere in the world (e.g. Cupertino, CA)
    demo_payload = {
        "school_id": school.id,
        "qr_token": qr_info.qr_token,
        "latitude": 37.3349,
        "longitude": -122.0090,
        "accuracy": 20.0,
    }
    res = await async_client.post(
        "/api/v1/attendance/check-in",
        json=demo_payload,
        headers=demo_headers,
    )
    assert res.status_code == 200 or res.json().get("code") == "ALREADY_CHECKED_IN"


@pytest.mark.asyncio
async def test_admin_dashboard_and_manual_correction(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    # 1. Get today dashboard
    dash_res = await async_client.get(
        "/api/v1/attendance/dashboard/today",
        headers=admin_auth_headers,
    )
    assert dash_res.status_code == 200
    dash_data = dash_res.json()
    assert "total_teachers" in dash_data
    assert "records" in dash_data

    # 2. Find a teacher to correct
    t_res = await db_session.execute(select(Teacher).limit(1))
    target_teacher = t_res.scalar_one()

    # 3. Apply manual correction
    corr_payload = {
        "teacher_id": target_teacher.id,
        "target_date": str(date.today()),
        "status": "EXCUSED",
        "reason": "Медициналык кароодон өткөндүгүнө байланыштуу",
    }
    corr_res = await async_client.post(
        "/api/v1/attendance/manual-correction",
        json=corr_payload,
        headers=admin_auth_headers,
    )
    assert corr_res.status_code == 200
    corr_data = corr_res.json()
    assert corr_data["is_manually_corrected"] is True
    assert corr_data["status"] == "EXCUSED"
    assert corr_data["correction_reason"] == "Медициналык кароодон өткөндүгүнө байланыштуу"
