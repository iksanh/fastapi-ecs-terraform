from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.user import UserCreate, UserRead, UserUpdate
from app.crud.user import get_users, create_user, update_user

router = APIRouter()

@router.get("/", response_model=list[UserRead])
def read_users(db: Session = Depends(get_db)):
    return get_users(db)

@router.post("/", response_model=UserRead)
def add_user(user: UserCreate, db: Session= Depends(get_db)):
    return create_user(db, user)

@router.patch("/{user_id}", response_model=UserRead)
def update_user_route(user_id: int, user:UserUpdate, db: Session=Depends(get_db)):
    updated_user = update_user(db, user_id, user)

    if not update_user:
        raise HTTPException(status_code=404, detail="User not found")

    return updated_user