from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, String, Text, DateTime, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta
import json
import os
from jose import JWTError, jwt
from passlib.context import CryptContext

# Database setup
SQLALCHEMY_DATABASE_URL = "sqlite:///./pokedaddy.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Security
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

app = FastAPI(title="PokeDaddy Server", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your iOS app's scheme
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database Models
class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    apple_user_id = Column(String, unique=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    is_active = Column(Boolean, default=True)

class UserProfile(Base):
    __tablename__ = "user_profiles"
    
    id = Column(String, primary_key=True, index=True)
    user_id = Column(String, index=True)
    name = Column(String)
    icon = Column(String)
    restricted_apps = Column(Text)  # JSON string of app identifiers
    restricted_categories = Column(Text)  # JSON string of category identifiers
    is_default = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

class BlockingSession(Base):
    __tablename__ = "blocking_sessions"
    
    id = Column(String, primary_key=True, index=True)
    user_id = Column(String, index=True)
    profile_id = Column(String, index=True)
    is_active = Column(Boolean, default=True)
    started_at = Column(DateTime, default=datetime.utcnow)
    ended_at = Column(DateTime, nullable=True)

# Create tables
Base.metadata.create_all(bind=engine)

# Pydantic models
class UserCreate(BaseModel):
    apple_user_id: str
    email: Optional[str] = None
    name: Optional[str] = None

class UserResponse(BaseModel):
    id: str
    email: Optional[str]
    name: Optional[str]
    apple_user_id: str
    is_active: bool

class ProfileCreate(BaseModel):
    name: str
    icon: str = "bell.slash"
    restricted_apps: List[str] = []
    restricted_categories: List[str] = []
    is_default: bool = False

class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    icon: Optional[str] = None
    restricted_apps: Optional[List[str]] = None
    restricted_categories: Optional[List[str]] = None

class ProfileResponse(BaseModel):
    id: str
    name: str
    icon: str
    restricted_apps: List[str]
    restricted_categories: List[str]
    is_default: bool
    created_at: datetime
    updated_at: datetime

class BlockingRequest(BaseModel):
    profile_id: str
    action: str  # "start" or "stop"

class BlockingStatusResponse(BaseModel):
    is_blocking: bool
    profile_id: Optional[str]
    session_id: Optional[str]
    started_at: Optional[datetime]

class Token(BaseModel):
    access_token: str
    token_type: str

# Dependency to get database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Authentication functions
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return user_id
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

def get_current_user(db: Session = Depends(get_db), user_id: str = Depends(verify_token)):
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user

# API Endpoints
@app.get("/")
async def root():
    return {"message": "PokeDaddy Server API", "version": "1.0.0"}

@app.post("/auth/register", response_model=Token)
async def register_user(user_data: UserCreate, db: Session = Depends(get_db)):
    # Check if user already exists
    existing_user = db.query(User).filter(User.apple_user_id == user_data.apple_user_id).first()
    if existing_user:
        # User exists, return token
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": existing_user.id}, expires_delta=access_token_expires
        )
        return {"access_token": access_token, "token_type": "bearer"}
    
    # Create new user
    import uuid
    user_id = str(uuid.uuid4())
    db_user = User(
        id=user_id,
        apple_user_id=user_data.apple_user_id,
        email=user_data.email,
        name=user_data.name
    )
    db.add(db_user)
    
    # Create default profile
    profile_id = str(uuid.uuid4())
    default_profile = UserProfile(
        id=profile_id,
        user_id=user_id,
        name="Default",
        icon="bell.slash",
        restricted_apps="[]",
        restricted_categories="[]",
        is_default=True
    )
    db.add(default_profile)
    db.commit()
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user_id}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=UserResponse)
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

@app.get("/profiles", response_model=List[ProfileResponse])
async def get_user_profiles(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    profiles = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).all()
    result = []
    for profile in profiles:
        result.append(ProfileResponse(
            id=profile.id,
            name=profile.name,
            icon=profile.icon,
            restricted_apps=json.loads(profile.restricted_apps),
            restricted_categories=json.loads(profile.restricted_categories),
            is_default=profile.is_default,
            created_at=profile.created_at,
            updated_at=profile.updated_at
        ))
    return result

@app.post("/profiles", response_model=ProfileResponse)
async def create_profile(
    profile_data: ProfileCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    import uuid
    profile_id = str(uuid.uuid4())
    
    db_profile = UserProfile(
        id=profile_id,
        user_id=current_user.id,
        name=profile_data.name,
        icon=profile_data.icon,
        restricted_apps=json.dumps(profile_data.restricted_apps),
        restricted_categories=json.dumps(profile_data.restricted_categories),
        is_default=profile_data.is_default
    )
    db.add(db_profile)
    db.commit()
    db.refresh(db_profile)
    
    return ProfileResponse(
        id=db_profile.id,
        name=db_profile.name,
        icon=db_profile.icon,
        restricted_apps=json.loads(db_profile.restricted_apps),
        restricted_categories=json.loads(db_profile.restricted_categories),
        is_default=db_profile.is_default,
        created_at=db_profile.created_at,
        updated_at=db_profile.updated_at
    )

@app.put("/profiles/{profile_id}", response_model=ProfileResponse)
async def update_profile(
    profile_id: str,
    profile_data: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    profile = db.query(UserProfile).filter(
        UserProfile.id == profile_id,
        UserProfile.user_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    if profile_data.name is not None:
        profile.name = profile_data.name
    if profile_data.icon is not None:
        profile.icon = profile_data.icon
    if profile_data.restricted_apps is not None:
        profile.restricted_apps = json.dumps(profile_data.restricted_apps)
    if profile_data.restricted_categories is not None:
        profile.restricted_categories = json.dumps(profile_data.restricted_categories)
    
    profile.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(profile)
    
    return ProfileResponse(
        id=profile.id,
        name=profile.name,
        icon=profile.icon,
        restricted_apps=json.loads(profile.restricted_apps),
        restricted_categories=json.loads(profile.restricted_categories),
        is_default=profile.is_default,
        created_at=profile.created_at,
        updated_at=profile.updated_at
    )

@app.delete("/profiles/{profile_id}")
async def delete_profile(
    profile_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    profile = db.query(UserProfile).filter(
        UserProfile.id == profile_id,
        UserProfile.user_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    if profile.is_default:
        raise HTTPException(status_code=400, detail="Cannot delete default profile")
    
    db.delete(profile)
    db.commit()
    return {"message": "Profile deleted successfully"}

@app.post("/blocking/toggle", response_model=BlockingStatusResponse)
async def toggle_blocking(
    blocking_request: BlockingRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Check if profile exists and belongs to user
    profile = db.query(UserProfile).filter(
        UserProfile.id == blocking_request.profile_id,
        UserProfile.user_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Check current blocking status
    active_session = db.query(BlockingSession).filter(
        BlockingSession.user_id == current_user.id,
        BlockingSession.is_active == True
    ).first()
    
    if blocking_request.action == "start":
        if active_session:
            # End current session
            active_session.is_active = False
            active_session.ended_at = datetime.utcnow()
        
        # Start new session
        import uuid
        session_id = str(uuid.uuid4())
        new_session = BlockingSession(
            id=session_id,
            user_id=current_user.id,
            profile_id=blocking_request.profile_id,
            is_active=True
        )
        db.add(new_session)
        db.commit()
        
        return BlockingStatusResponse(
            is_blocking=True,
            profile_id=blocking_request.profile_id,
            session_id=session_id,
            started_at=new_session.started_at
        )
    
    elif blocking_request.action == "stop":
        if active_session:
            active_session.is_active = False
            active_session.ended_at = datetime.utcnow()
            db.commit()
        
        return BlockingStatusResponse(
            is_blocking=False,
            profile_id=None,
            session_id=None,
            started_at=None
        )
    
    else:
        raise HTTPException(status_code=400, detail="Invalid action. Use 'start' or 'stop'")

@app.get("/blocking/status", response_model=BlockingStatusResponse)
async def get_blocking_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    active_session = db.query(BlockingSession).filter(
        BlockingSession.user_id == current_user.id,
        BlockingSession.is_active == True
    ).first()
    
    if active_session:
        return BlockingStatusResponse(
            is_blocking=True,
            profile_id=active_session.profile_id,
            session_id=active_session.id,
            started_at=active_session.started_at
        )
    else:
        return BlockingStatusResponse(
            is_blocking=False,
            profile_id=None,
            session_id=None,
            started_at=None
        )

@app.get("/profiles/{profile_id}/restricted-apps", response_model=List[str])
async def get_restricted_apps(
    profile_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get restricted apps for a specific profile - this is the key endpoint for app access control"""
    profile = db.query(UserProfile).filter(
        UserProfile.id == profile_id,
        UserProfile.user_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Check if there's an active blocking session for this profile
    active_session = db.query(BlockingSession).filter(
        BlockingSession.user_id == current_user.id,
        BlockingSession.profile_id == profile_id,
        BlockingSession.is_active == True
    ).first()
    
    if active_session:
        return json.loads(profile.restricted_apps)
    else:
        return []  # No restrictions if not in blocking mode

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
