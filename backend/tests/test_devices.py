import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_register_device_and_fcm_token(
    async_client: AsyncClient, teacher_auth_headers: dict
):
    payload = {
        "device_id": "iphone-17-sim-uuid-001",
        "platform": "IOS",
        "fcm_token": "mock-apns-fcm-token-abcdef123456",
    }
    response = await async_client.post(
        "/api/v1/devices/register",
        json=payload,
        headers=teacher_auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["device_id"] == "iphone-17-sim-uuid-001"
    assert data["platform"] == "IOS"
    assert data["fcm_token"] == "mock-apns-fcm-token-abcdef123456"
    assert data["is_active"] is True
