from typing import List, Optional, Tuple
from sqlalchemy import func, or_, select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppException, ErrorCode
from app.core.security import get_password_hash
from app.models.enums import UserRole
from app.models.school import School
from app.models.teacher import Teacher
from app.models.user import User
from app.schemas.teacher import TeacherCreate, TeacherRead, TeacherUpdate


class TeacherService:
    @staticmethod
    async def list_teachers(
        db: AsyncSession,
        school_id: Optional[str] = None,
        search: Optional[str] = None,
        is_active: Optional[bool] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[TeacherRead], int]:
        query = (
            select(Teacher)
            .join(User, Teacher.user_id == User.id)
            .options(selectinload(Teacher.user))
        )

        if school_id:
            query = query.where(Teacher.school_id == school_id)

        if is_active is not None:
            query = query.where(User.is_active == is_active)

        if search:
            search_filter = f"%{search}%"
            query = query.where(
                or_(
                    User.full_name.ilike(search_filter),
                    User.username.ilike(search_filter),
                    Teacher.employee_code.ilike(search_filter),
                    Teacher.subject.ilike(search_filter),
                )
            )

        # Count total
        count_query = select(func.count()).select_from(query.subquery())
        total_result = await db.execute(count_query)
        total = total_result.scalar_one()

        # Fetch page
        query = query.order_by(User.full_name.asc()).offset(skip).limit(limit)
        result = await db.execute(query)
        teachers = result.scalars().all()

        items = [
            TeacherRead(
                id=t.id,
                user_id=t.user_id,
                school_id=t.school_id,
                employee_code=t.employee_code,
                phone_number=t.phone,
                subject=t.subject,
                full_name=t.user.full_name,
                username=t.user.username,
                is_active=t.user.is_active,
                is_demo=t.user.is_demo,
                created_at=t.created_at,
            )
            for t in teachers
        ]
        return items, total

    @staticmethod
    async def get_teacher_by_id(db: AsyncSession, teacher_id: str) -> TeacherRead:
        result = await db.execute(
            select(Teacher)
            .where(Teacher.id == teacher_id)
            .options(selectinload(Teacher.user))
        )
        t = result.scalar_one_or_none()
        if not t:
            raise AppException(
                code=ErrorCode.TEACHER_NOT_FOUND,
                message="Мугалим табылган жок",
                status_code=404,
            )

        return TeacherRead(
            id=t.id,
            user_id=t.user_id,
            school_id=t.school_id,
            employee_code=t.employee_code,
            phone_number=t.phone,
            subject=t.subject,
            full_name=t.user.full_name,
            username=t.user.username,
            is_active=t.user.is_active,
            is_demo=t.user.is_demo,
            created_at=t.created_at,
        )

    @staticmethod
    async def create_teacher(db: AsyncSession, payload: TeacherCreate) -> TeacherRead:
        # Check existing username
        existing = await db.execute(
            select(User).where(User.username == payload.username)
        )
        if existing.scalar_one_or_none():
            raise AppException(
                code=ErrorCode.VALIDATION_ERROR,
                message=f"Логин бош эмес: {payload.username}",
                status_code=400,
            )

        # Check existing employee code in school
        school_id = payload.school_id
        if not school_id:
            # Default to first school
            school_result = await db.execute(select(School).limit(1))
            school = school_result.scalar_one_or_none()
            if not school:
                raise AppException(
                    code=ErrorCode.NOT_FOUND,
                    message="Мектеп табылган жок",
                    status_code=400,
                )
            school_id = school.id

        existing_code = await db.execute(
            select(Teacher).where(
                Teacher.school_id == school_id,
                Teacher.employee_code == payload.employee_code,
            )
        )
        if existing_code.scalar_one_or_none():
            raise AppException(
                code=ErrorCode.VALIDATION_ERROR,
                message=f"Табель номери колдонулууда: {payload.employee_code}",
                status_code=400,
            )

        # Create user
        user = User(
            email=f"{payload.username}@school.edu.kg",
            username=payload.username,
            hashed_password=get_password_hash(payload.password),
            full_name=payload.full_name,
            role=UserRole.TEACHER,
            is_active=True,
            is_demo=False,
        )
        db.add(user)
        await db.flush()

        # Create teacher
        teacher = Teacher(
            user_id=user.id,
            school_id=school_id,
            employee_code=payload.employee_code,
            phone=payload.phone_number,
            subject=payload.subject,
            is_active=True,
        )
        db.add(teacher)
        await db.commit()
        await db.refresh(teacher)
        await db.refresh(user)

        return TeacherRead(
            id=teacher.id,
            user_id=teacher.user_id,
            school_id=teacher.school_id,
            employee_code=teacher.employee_code,
            phone_number=teacher.phone,
            subject=teacher.subject,
            full_name=user.full_name,
            username=user.username,
            is_active=user.is_active,
            is_demo=user.is_demo,
            created_at=teacher.created_at,
        )

    @staticmethod
    async def update_teacher(
        db: AsyncSession, teacher_id: str, payload: TeacherUpdate
    ) -> TeacherRead:
        result = await db.execute(
            select(Teacher)
            .where(Teacher.id == teacher_id)
            .options(selectinload(Teacher.user))
        )
        teacher = result.scalar_one_or_none()
        if not teacher:
            raise AppException(
                code=ErrorCode.TEACHER_NOT_FOUND,
                message="Мугалим табылган жок",
                status_code=404,
            )

        user = teacher.user
        if payload.full_name is not None:
            user.full_name = payload.full_name
        if payload.is_active is not None:
            user.is_active = payload.is_active
            teacher.is_active = payload.is_active
        if payload.password is not None and len(payload.password.strip()) > 0:
            user.hashed_password = get_password_hash(payload.password)

        if payload.employee_code is not None:
            teacher.employee_code = payload.employee_code
        if payload.phone_number is not None:
            teacher.phone = payload.phone_number
        if payload.subject is not None:
            teacher.subject = payload.subject

        await db.commit()
        await db.refresh(teacher)
        await db.refresh(user)

        return TeacherRead(
            id=teacher.id,
            user_id=teacher.user_id,
            school_id=teacher.school_id,
            employee_code=teacher.employee_code,
            phone_number=teacher.phone,
            subject=teacher.subject,
            full_name=user.full_name,
            username=user.username,
            is_active=user.is_active,
            is_demo=user.is_demo,
            created_at=teacher.created_at,
        )

    @staticmethod
    async def deactivate_teacher(db: AsyncSession, teacher_id: str) -> TeacherRead:
        return await TeacherService.update_teacher(
            db, teacher_id, TeacherUpdate(is_active=False)
        )

    @staticmethod
    async def delete_teacher(db: AsyncSession, teacher_id: str) -> bool:
        result = await db.execute(
            select(Teacher).where(Teacher.id == teacher_id)
        )
        teacher = result.scalar_one_or_none()
        if not teacher:
            raise AppException(
                code=ErrorCode.TEACHER_NOT_FOUND,
                message="Мугалим табылган жок",
                status_code=404,
            )

        user_id = teacher.user_id
        # Delete user which cascades to teacher and all dependent records
        await db.execute(delete(User).where(User.id == user_id))
        await db.commit()
        return True
