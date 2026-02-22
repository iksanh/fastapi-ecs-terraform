from fastapi import FastAPI
from app.db.session import engine
from app.models import user  # penting supaya model ke-load
from app.api.routes import user as user_router

app = FastAPI(title="FastAPI Backend")

# sementara untuk development
user.Base.metadata.create_all(bind=engine)

app.include_router(
    user_router.router,
    prefix="/users",
    tags=["users"]
)

@app.get("/")
def root():
    return {"status": "running"}
