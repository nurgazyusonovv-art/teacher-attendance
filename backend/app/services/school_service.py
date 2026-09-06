from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppException, ErrorCode
from app.models.school import School
from app.schemas.school import SchoolUpdate
from app.services.audit_service import AuditService


class SchoolService:
    @staticmethod
    async def get_school_by_id(db: AsyncSession, school_id: str) -> School:
        result = await db.execute(select(School).where(School.id == school_id))
        school = result.scalar_one_or_none()
        if not school:
            raise AppException(
                code=ErrorCode.NOT_FOUND,
                message=f"Мектеп табылган жок: {school_id}",
                status_code=404,
            )
        return school

    @staticmethod
    async def get_first_active_school(db: AsyncSession) -> School:
        result = await db.execute(
            select(School).where(School.is_active == True).limit(1)  # noqa: E712
        )
        school = result.scalar_one_or_none()
        if not school:
            raise AppException(
                code=ErrorCode.NOT_FOUND,
                message="Активдүү мектеп табылган жок",
                status_code=404,
            )
        return school

    @staticmethod
    async def update_school(
        db: AsyncSession,
        school_id: str,
        payload: SchoolUpdate,
        actor_user_id: Optional[str] = None,
    ) -> School:
        school = await SchoolService.get_school_by_id(db, school_id)

        update_data = payload.model_dump(exclude_unset=True)
        old_values = {field: getattr(school, field) for field in update_data}
        for field, value in update_data.items():
            setattr(school, field, value)

        AuditService.add(
            db,
            school_id=school_id,
            user_id=actor_user_id,
            action="SCHOOL_SETTINGS_UPDATED",
            entity_name="school",
            entity_id=school_id,
            old_values=old_values,
            new_values=update_data,
        )

        await db.commit()
        await db.refresh(school)
        return school
