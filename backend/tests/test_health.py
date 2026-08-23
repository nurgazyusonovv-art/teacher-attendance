import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_check_returns_200(async_client: AsyncClient):
    response = await async_client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["data"]["status"] == "healthy"
    assert data["data"]["timezone"] == "Asia/Bishkek"
    assert "server_time_iso" in data["data"]


@pytest.mark.asyncio
async def test_root_endpoint_returns_info(async_client: AsyncClient):
    response = await async_client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "project" in data
    assert "docs" in data
