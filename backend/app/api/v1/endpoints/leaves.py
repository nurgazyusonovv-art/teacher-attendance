from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_current_active_teacher, get_current_active_admin, get_user_school_id
from app.db.session import get_db
from app.models.teacher import Teacher
from app.models.user import User
from app.schemas.leave_request import LeaveCreate, LeaveDecision, LeaveRead
from app.services.leave_service import LeaveService

router = APIRouter()


@router.get('/mine', response_model=list[LeaveRead])
async def mine(offset: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100),
               db: AsyncSession = Depends(get_db), teacher: Teacher = Depends(get_current_active_teacher)):
    return await LeaveService.list(db, teacher.school_id, teacher.id, offset, limit)


@router.post('', response_model=LeaveRead)
async def create(payload: LeaveCreate, db: AsyncSession = Depends(get_db),
                 teacher: Teacher = Depends(get_current_active_teacher)):
    return await LeaveService.create(db, teacher, payload)


@router.get('/admin', response_model=list[LeaveRead])
async def admin_list(offset: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100),
                     db: AsyncSession = Depends(get_db), admin: User = Depends(get_current_active_admin)):
    return await LeaveService.list(db, await get_user_school_id(db, admin), offset=offset, limit=limit)


@router.post('/admin/{request_id}/decision', response_model=LeaveRead)
async def decide(request_id: str, payload: LeaveDecision, db: AsyncSession = Depends(get_db),
                 admin: User = Depends(get_current_active_admin)):
    return await LeaveService.decide(db, await get_user_school_id(db, admin), admin.id, request_id, payload)
