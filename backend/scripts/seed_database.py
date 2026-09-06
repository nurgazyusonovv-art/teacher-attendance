"""Backward-compatible entry point for the guarded bootstrap seed."""

import asyncio

from seed import seed_data


if __name__ == "__main__":
    asyncio.run(seed_data())
