"""Litestar + Advanced Alchemy backend.

Exposes GET /health, GET /vessels, POST /vessels over the shared `vessels`
table. The schema is owned by db/init/001_schema.sql, so we do not create or
migrate tables here.
"""

from __future__ import annotations

import os
from datetime import datetime

import msgspec
from advanced_alchemy.base import IdentityBase
from advanced_alchemy.extensions.litestar import (
    AsyncSessionConfig,
    SQLAlchemyAsyncConfig,
    SQLAlchemyPlugin,
)
from advanced_alchemy.repository import SQLAlchemyAsyncRepository
from litestar import Litestar, get, post
from sqlalchemy import DateTime, Float, String, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

DATABASE_URL = os.environ.get(
    "DATABASE_URL", "postgresql+asyncpg://app:app@localhost:5434/app"
)


# --- model (maps onto the shared table) ---

class Vessel(IdentityBase):
    __tablename__ = "vessels"

    name: Mapped[str] = mapped_column(String)
    length_m: Mapped[float] = mapped_column(Float, default=0.0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class VesselRepository(SQLAlchemyAsyncRepository[Vessel]):
    model_type = Vessel


# --- wire types (what crosses the HTTP boundary) ---

class VesselIn(msgspec.Struct):
    name: str
    length_m: float = 0.0


class VesselOut(msgspec.Struct):
    id: int
    name: str
    length_m: float
    created_at: datetime


def _to_out(v: Vessel) -> VesselOut:
    return VesselOut(id=v.id, name=v.name, length_m=v.length_m, created_at=v.created_at)


# --- handlers ---

@get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "python-litestar"}


@get("/vessels")
async def list_vessels(db_session: AsyncSession) -> list[VesselOut]:
    repo = VesselRepository(session=db_session)
    return [_to_out(v) for v in await repo.list()]


@post("/vessels")
async def create_vessel(data: VesselIn, db_session: AsyncSession) -> VesselOut:
    repo = VesselRepository(session=db_session)
    vessel = await repo.add(
        Vessel(name=data.name, length_m=data.length_m), auto_commit=True
    )
    return _to_out(vessel)


db_config = SQLAlchemyAsyncConfig(
    connection_string=DATABASE_URL,
    session_config=AsyncSessionConfig(expire_on_commit=False),
)

app = Litestar(
    route_handlers=[health, list_vessels, create_vessel],
    plugins=[SQLAlchemyPlugin(db_config)],
)
