from sqlalchemy.orm import Session
from app.models.user import User 
from app.schemas.user import UserCreate, UserUpdate


def get_users(db: Session):
    return db.query(User).all()

def create_user(db: Session, user: UserCreate):
    db_user = User(
        name=user.name,
        email=user.email
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def update_user(db: Session, user_id: int, user_update: UserUpdate):
    db_user = db.query(User).filter(User.id == user_id).first()
    
    if not db_user:
        return None

    db_user.name = user_update.name
    db_user.email = user_update.email

    db.commit()
    db.refresh(db_user)
    return db_user


