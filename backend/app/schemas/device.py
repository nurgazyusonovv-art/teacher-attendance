from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field
from app.models.enums import DevicePlatform


class DeviceRegisterRequest(BaseModel):
    device_id: str = Field(..., min_length=3, max_length=255, description="Уникалдуу түзмөк идентификатору")
    platform: DevicePlatform = Field(..., description="Платформа (IOS, ANDROID, WEB)")
    fcm_token: Optional[str] = Field(None, max_length=500, description="FCM / APNs push токени")


class DeviceRead(BaseModel):
    id: str
    user_id: str
    device_id: str
    platform: DevicePlatform
    fcm_token: Optional[str] = None
    is_active: bool
    last_seen_at: Optional[datetime] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
