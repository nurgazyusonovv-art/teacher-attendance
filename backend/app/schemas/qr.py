from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class QrCodeRead(BaseModel):
    id: str
    school_id: str
    token: str
    label: str
    is_active: bool
    expires_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class QrPayloadResponse(BaseModel):
    school_id: str
    school_name: str
    qr_token: str
    qr_payload: str  # JSON payload to encode in QR image: '{"school_id": "...", "qr_token": "..."}'
    created_at: datetime
