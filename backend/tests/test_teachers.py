import uuid
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_list_teachers_as_admin(
    async_client: AsyncClient, admin_auth_headers: dict
):
    response = await async_client.get(
        "/api/v1/teachers", headers=admin_auth_headers
    )
    assert response.status_code == 200
    data = response.json()
    assert "items" in data
    assert data["total"] >= 1
    assert any(t["username"] == "teacher1" for t in data["items"])


@pytest.mark.asyncio
async def test_create_and_update_teacher(
    async_client: AsyncClient, admin_auth_headers: dict
):
    uid = uuid.uuid4().hex[:6]
    username = f"asanov_{uid}"
    emp_code = f"TCH-{uid}"

    new_teacher_data = {
        "full_name": "Асанов Үсөн",
        "username": username,
        "password": "password123",
        "employee_code": emp_code,
        "phone_number": "+996555112233",
        "subject": "Физика",
    }
    create_res = await async_client.post(
        "/api/v1/teachers", json=new_teacher_data, headers=admin_auth_headers
    )
    assert create_res.status_code == 200
    created = create_res.json()
    assert created["full_name"] == "Асанов Үсөн"
    assert created["employee_code"] == emp_code
    assert created["subject"] == "Физика"
    teacher_id = created["id"]

    # Test duplicate username rejection
    dup_res = await async_client.post(
        "/api/v1/teachers", json=new_teacher_data, headers=admin_auth_headers
    )
    assert dup_res.status_code == 400
    assert dup_res.json()["code"] == "VALIDATION_ERROR"

    # Update teacher
    update_res = await async_client.patch(
        f"/api/v1/teachers/{teacher_id}",
        json={"subject": "Астрономия", "phone_number": "+996777000111"},
        headers=admin_auth_headers,
    )
    assert update_res.status_code == 200
    updated = update_res.json()
    assert updated["subject"] == "Астрономия"
    assert updated["phone_number"] == "+996777000111"


@pytest.mark.asyncio
async def test_deactivate_teacher_prevents_login(
    async_client: AsyncClient, admin_auth_headers: dict
):
    uid = uuid.uuid4().hex[:6]
    username = f"bakytov_{uid}"
    emp_code = f"TCH-{uid}"

    # 1. Create a temporary teacher
    t_data = {
        "full_name": "Бакытов Эдил",
        "username": username,
        "password": "secretPassword123",
        "employee_code": emp_code,
        "subject": "Химия",
    }
    create_res = await async_client.post(
        "/api/v1/teachers", json=t_data, headers=admin_auth_headers
    )
    assert create_res.status_code == 200
    teacher_id = create_res.json()["id"]

    # 2. Verify login works
    login_res = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": username, "password": "secretPassword123"},
    )
    assert login_res.status_code == 200

    # 3. Deactivate teacher
    deact_res = await async_client.delete(
        f"/api/v1/teachers/{teacher_id}", headers=admin_auth_headers
    )
    assert deact_res.status_code == 200
    assert deact_res.json()["is_active"] is False

    # 4. Verify login is now blocked
    login_after_res = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": username, "password": "secretPassword123"},
    )
    assert login_after_res.status_code == 403
    assert login_after_res.json()["code"] == "USER_INACTIVE"
