"""Symmetric encryption for secrets that must be stored and read back.

Passwords are hashed and never recovered; a Telegram bot token has to be
replayed to Telegram, so it is encrypted at rest instead. Values written
before this existed stay readable: anything without the version prefix is
returned unchanged and is re-encrypted the next time it is saved.
"""

import base64
import hashlib
import logging
from typing import Optional

from cryptography.fernet import Fernet, InvalidToken

from app.core.config import settings

logger = logging.getLogger("teacher_attendance")

_PREFIX = "enc:v1:"
_cache: dict[str, Fernet] = {}


def _key_material() -> str:
    return settings.SECRETS_ENCRYPTION_KEY or settings.SECRET_KEY


def _fernet() -> Fernet:
    material = _key_material()
    cached = _cache.get(material)
    if cached is None:
        digest = hashlib.sha256(material.encode("utf-8")).digest()
        cached = Fernet(base64.urlsafe_b64encode(digest))
        _cache[material] = cached
    return cached


def encrypt_secret(value: Optional[str]) -> Optional[str]:
    """Encrypts a secret for storage. Empty values are stored as NULL."""
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None
    if value.startswith(_PREFIX):
        return value
    token = _fernet().encrypt(value.encode("utf-8")).decode("utf-8")
    return f"{_PREFIX}{token}"


def decrypt_secret(value: Optional[str]) -> Optional[str]:
    """Reads a stored secret.

    Returns None rather than raising when the value cannot be decrypted (for
    example after an encryption key rotation), so the caller degrades to
    "not configured" and an administrator can simply re-enter it.
    """
    if not value:
        return None
    if not value.startswith(_PREFIX):
        # Written before encryption existed; still usable.
        return value
    try:
        return _fernet().decrypt(value[len(_PREFIX):].encode("utf-8")).decode("utf-8")
    except (InvalidToken, ValueError):
        logger.error(
            "Stored secret could not be decrypted; treating it as unset. "
            "It must be re-entered after an encryption key change."
        )
        return None
