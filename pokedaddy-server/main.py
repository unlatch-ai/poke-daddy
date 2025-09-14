from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, String, Text, DateTime, Boolean
from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta
import json
import os
from jose import JWTError, jwt
from passlib.context import CryptContext
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database setup
POSTGRES_URL = os.getenv("POSTGRES_URL")
if not POSTGRES_URL:
    raise ValueError("POSTGRES_URL environment variable is required")

# Convert postgres:// to postgresql:// for SQLAlchemy 2.0 compatibility
if POSTGRES_URL.startswith("postgres://"):
    POSTGRES_URL = POSTGRES_URL.replace("postgres://", "postgresql://", 1)

# Remove invalid Vercel-specific parameters that psycopg2 doesn't recognize
import urllib.parse
parsed_url = urllib.parse.urlparse(POSTGRES_URL)
query_params = urllib.parse.parse_qs(parsed_url.query)

# Remove the 'supa' parameter that Vercel adds but psycopg2 doesn't support
if 'supa' in query_params:
    del query_params['supa']

# Rebuild the URL without the invalid parameter
clean_query = urllib.parse.urlencode(query_params, doseq=True)
clean_url = urllib.parse.urlunparse((
    parsed_url.scheme,
    parsed_url.netloc,
    parsed_url.path,
    parsed_url.params,
    clean_query,
    parsed_url.fragment
))

engine = create_engine(clean_url)
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

class BlockingToggleRequest(BaseModel):
    profile_id: str
    action: str  # "start" or "stop"

class BlockingResponse(BaseModel):
    is_blocking: bool
    profile_id: str
    message: str

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
    return {"message": "PokeDaddy Server API", "version": "1.0.0", "status": "running"}

@app.post("/auth/register", response_model=Token)
async def register_user(user_data: UserCreate, db: Session = Depends(get_db)):
    # Check if user already exists
    existing_user = db.query(User).filter(User.apple_user_id == user_data.apple_user_id).first()
    if existing_user:
        # If new profile info is provided, update missing fields (email/name may be absent on later Apple sign-ins)
        updated = False
        if user_data.email and (existing_user.email is None or existing_user.email == ""):
            existing_user.email = user_data.email
            updated = True
        if user_data.name and (existing_user.name is None or existing_user.name == ""):
            existing_user.name = user_data.name
            updated = True
        if updated:
            db.add(existing_user)
            db.commit()

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

@app.post("/blocking/toggle")
async def toggle_blocking(request: BlockingToggleRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Toggle blocking state for a profile - users can only start, server controls stopping"""
    # Get the profile
    profile = db.query(UserProfile).filter(
        UserProfile.id == request.profile_id,
        UserProfile.user_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Check if there's an active blocking session
    active_session = db.query(BlockingSession).filter(
        BlockingSession.user_id == current_user.id,
        BlockingSession.profile_id == request.profile_id,
        BlockingSession.is_active == True
    ).first()
    
    if request.action == "start":
        if active_session:
            return BlockingResponse(
                is_blocking=True,
                profile_id=request.profile_id,
                message="Already blocking"
            )
        
        # Create new blocking session
        import uuid
        session = BlockingSession(
            id=str(uuid.uuid4()),
            user_id=current_user.id,
            profile_id=request.profile_id,
            started_at=datetime.utcnow(),
            is_active=True
        )
        db.add(session)
        db.commit()
        
        return BlockingResponse(
            is_blocking=True,
            profile_id=request.profile_id,
            message="Blocking started"
        )
    
    else:
        raise HTTPException(status_code=400, detail="Invalid action. Only 'start' is allowed for users")

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

@app.get("/profiles/{profile_id}/restricted-apps")
async def get_restricted_apps(profile_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Get restricted apps for a profile - only returns apps when user is actively blocking"""
    # Check if user has an active blocking session for this profile
    active_session = db.query(BlockingSession).filter(
        BlockingSession.user_id == current_user.id,
        BlockingSession.profile_id == profile_id,
        BlockingSession.is_active == True
    ).first()
    
    if not active_session:
        # Return empty list if not actively blocking
        return {"restricted_apps": [], "restricted_categories": []}
    
    # Get the profile
    profile = db.query(UserProfile).filter(
        UserProfile.id == profile_id,
        UserProfile.user_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    return {
        "restricted_apps": json.loads(profile.restricted_apps),
        "restricted_categories": json.loads(profile.restricted_categories)
    }

# Server-only endpoint to unblock individual apps
@app.post("/admin/unblock-app")
async def unblock_app(app_bundle_id: str, user_id: str, profile_id: str, db: Session = Depends(get_db)):
    """Server endpoint to unblock individual apps - no authentication required for server use"""
    # Find active blocking session
    active_session = db.query(BlockingSession).filter(
        BlockingSession.user_id == user_id,
        BlockingSession.profile_id == profile_id,
        BlockingSession.is_active == True
    ).first()
    
    if not active_session:
        raise HTTPException(status_code=404, detail="No active blocking session found")
    
    # Get the profile and remove the app from restricted list
    profile = db.query(UserProfile).filter(
        UserProfile.id == profile_id,
        UserProfile.user_id == user_id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Remove app from restricted apps list
    restricted_apps = json.loads(profile.restricted_apps)
    if app_bundle_id in restricted_apps:
        restricted_apps.remove(app_bundle_id)
        profile.restricted_apps = json.dumps(restricted_apps)
        db.commit()
        
        return {"message": f"App {app_bundle_id} unblocked", "remaining_apps": restricted_apps}
    
    return {"message": "App was not in restricted list", "remaining_apps": restricted_apps}

@app.post("/admin/end-blocking")
async def end_blocking_session(user_id: str, profile_id: str, db: Session = Depends(get_db)):
    """Server endpoint to completely end a blocking session"""
    # Find active blocking session
    active_session = db.query(BlockingSession).filter(
        BlockingSession.user_id == user_id,
        BlockingSession.profile_id == profile_id,
        BlockingSession.is_active == True
    ).first()
    
    if not active_session:
        raise HTTPException(status_code=404, detail="No active blocking session found")
    
    # End the blocking session
    active_session.ended_at = datetime.utcnow()
    active_session.is_active = False
    db.commit()
    
    return {"message": "Blocking session ended", "session_id": active_session.id}

# -----------------------------
# Admin convenience endpoints for MCP by email
# -----------------------------

@app.get("/admin/status-by-email")
async def admin_status_by_email(email: str, db: Session = Depends(get_db)):
    """Lookup a user's blocking status and active profile by email (no auth, for MCP/demo).
    Returns: { valid, user_id, is_blocking, profile_id, session_id, started_at, restricted_apps, restricted_categories }
    """
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    active_session = db.query(BlockingSession).filter(
        BlockingSession.user_id == user.id,
        BlockingSession.is_active == True
    ).first()

    if not active_session:
        return {
            "valid": True,
            "user_id": user.id,
            "is_blocking": False,
            "profile_id": None,
            "session_id": None,
            "started_at": None,
            "restricted_apps": [],
            "restricted_categories": []
        }

    profile = db.query(UserProfile).filter(
        UserProfile.id == active_session.profile_id,
        UserProfile.user_id == user.id
    ).first()

    if not profile:
        # Return status with minimal info if profile record is missing
        return {
            "valid": True,
            "user_id": user.id,
            "is_blocking": True,
            "profile_id": active_session.profile_id,
            "session_id": active_session.id,
            "started_at": active_session.started_at,
            "restricted_apps": [],
            "restricted_categories": []
        }

    return {
        "valid": True,
        "user_id": user.id,
        "is_blocking": True,
        "profile_id": profile.id,
        "session_id": active_session.id,
        "started_at": active_session.started_at,
        "restricted_apps": json.loads(profile.restricted_apps),
        "restricted_categories": json.loads(profile.restricted_categories)
    }


@app.post("/admin/unblock-app-by-email")
async def admin_unblock_app_by_email(email: str, app_bundle_id: str, db: Session = Depends(get_db)):
    """Unblock a specific app for a user identified by email (no auth, for MCP/demo)."""
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    active_session = db.query(BlockingSession).filter(
        BlockingSession.user_id == user.id,
        BlockingSession.is_active == True
    ).first()
    if not active_session:
        raise HTTPException(status_code=404, detail="No active blocking session found")

    profile = db.query(UserProfile).filter(
        UserProfile.id == active_session.profile_id,
        UserProfile.user_id == user.id
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    restricted_apps = json.loads(profile.restricted_apps)
    if app_bundle_id in restricted_apps:
        restricted_apps.remove(app_bundle_id)
        profile.restricted_apps = json.dumps(restricted_apps)
        db.commit()
        return {
            "message": f"App {app_bundle_id} unblocked",
            "remaining_apps": restricted_apps,
            "user_id": user.id,
            "profile_id": profile.id
        }
    return {
        "message": "App was not in restricted list",
        "remaining_apps": restricted_apps,
        "user_id": user.id,
        "profile_id": profile.id
    }


@app.post("/admin/end-blocking-by-email")
async def admin_end_blocking_by_email(email: str, db: Session = Depends(get_db)):
    """End ALL active blocking sessions for a user by email (no auth, for MCP/demo)."""
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    active_sessions = db.query(BlockingSession).filter(
        BlockingSession.user_id == user.id,
        BlockingSession.is_active == True
    ).all()
    if not active_sessions:
        raise HTTPException(status_code=404, detail="No active blocking sessions found")

    # End ALL active sessions for this user
    session_ids = []
    for session in active_sessions:
        session.ended_at = datetime.utcnow()
        session.is_active = False
        session_ids.append(session.id)

    db.commit()
    return {
        "message": f"All blocking sessions ended ({len(session_ids)} sessions)",
        "session_ids": session_ids,
        "sessions_ended": len(session_ids)
    }

@app.post("/admin/start-blocking-by-email")
async def admin_start_blocking_by_email(
    email: str,
    profile_id: Optional[str] = None,
    profile_name: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Start a blocking session for a user by email. If profile_id is not provided,
    use the user's default profile, or fall back to the first available profile.
    """
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Resolve profile
    profile = None
    if profile_id:
        profile = db.query(UserProfile).filter(UserProfile.id == profile_id, UserProfile.user_id == user.id).first()
        if not profile:
            raise HTTPException(status_code=404, detail="Profile not found")
    else:
        q = db.query(UserProfile).filter(UserProfile.user_id == user.id)
        if profile_name:
            profile = q.filter(UserProfile.name == profile_name).first()
        if not profile:
            profile = q.filter(UserProfile.is_default == True).first()
        if not profile:
            profile = q.first()
        if not profile:
            raise HTTPException(status_code=404, detail="No profiles available for user")

    # Check existing active session
    active_session = db.query(BlockingSession).filter(
        BlockingSession.user_id == user.id,
        BlockingSession.profile_id == profile.id,
        BlockingSession.is_active == True
    ).first()
    if active_session:
        return {
            "message": "Already blocking",
            "session_id": active_session.id,
            "profile_id": profile.id,
            "is_blocking": True
        }

    # Create new session
    import uuid
    session = BlockingSession(
        id=str(uuid.uuid4()),
        user_id=user.id,
        profile_id=profile.id,
        started_at=datetime.utcnow(),
        is_active=True
    )
    db.add(session)
    db.commit()
    return {
        "message": "Blocking started",
        "session_id": session.id,
        "profile_id": profile.id,
        "is_blocking": True
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
