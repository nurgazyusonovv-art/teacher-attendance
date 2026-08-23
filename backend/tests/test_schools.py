import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_current_school(async_client: AsyncClient, admin_auth_headers: dict):
    response = await async_client.get(
        "/api/v1/schools/current", headers=admin_auth_headers
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "№1 Орто Мектеп"
    assert data["allowed_radius_meters"] > 0
    assert data["timezone"] == "Asia/Bishkek"


@pytest.mark.asyncio
async def test_update_school_settings_by_admin(
    async_client: AsyncClient, admin_auth_headers: dict
):
    # First get school ID
    curr_res = await async_client.get(
        "/api/v1/schools/current", headers=admin_auth_headers
    )
    school_id = curr_res.json()["id"]

    # Update radius to 120m and grace period to 10 min
    update_payload = {
        "allowed_radius_meters": 120.0,
        "grace_minutes": 10,
        "max_accuracy_meters": 45.0,
    }
    res = await async_client.patch(
        f"/api/v1/schools/{school_id}",
        json=update_payload,
        headers=admin_auth_headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["allowed_radius_meters"] == 120.0
    assert data["grace_minutes"] == 10
    assert data["max_accuracy_meters"] == 45.0


@pytest.mark.asyncio
async def test_teacher_cannot_update_school_settings(
    async_client: AsyncClient, teacher_auth_headers: dict
):
    curr_res = await async_client.get(
        "/api/v1/schools/current", headers=teacher_auth_headers
    )
    school_id = curr_res.json()["id"]

    update_payload = {"allowed_radius_meters": 300.0}
    res = await async_client.patch(
        f"/api/v1/schools/{school_id}",
        json=update_payload,
        headers=teacher_auth_headers,
    )
    assert res.status_code == 403
    assert res.json()["code"] == "PERMISSION_DENIED"
