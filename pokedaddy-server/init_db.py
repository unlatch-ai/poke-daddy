#!/usr/bin/env python3
"""
Database initialization script for PokeDaddy PostgreSQL migration
"""

import os
import sys
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

# Load environment variables
load_dotenv()

def init_database():
    """Initialize PostgreSQL database with tables"""
    
    postgres_url = os.getenv("POSTGRES_URL")
    if not postgres_url:
        print("Error: POSTGRES_URL environment variable is required")
        sys.exit(1)
    
    try:
        # Convert postgres:// to postgresql:// for SQLAlchemy 2.0 compatibility
        if postgres_url.startswith("postgres://"):
            postgres_url = postgres_url.replace("postgres://", "postgresql://", 1)
        
        # Create engine
        engine = create_engine(postgres_url)
        
        # Test connection
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version();"))
            version = result.fetchone()[0]
            print(f"Connected to PostgreSQL: {version}")
        
        # Import models to register them with Base
        from main import Base, User, UserProfile, BlockingSession
        
        # Create all tables
        print("Creating database tables...")
        Base.metadata.create_all(bind=engine)
        print("Database tables created successfully!")
        
        # Verify tables were created
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public'
                ORDER BY table_name;
            """))
            tables = [row[0] for row in result.fetchall()]
            print(f"Created tables: {', '.join(tables)}")
        
        return True
        
    except SQLAlchemyError as e:
        print(f"Database error: {e}")
        return False
    except Exception as e:
        print(f"Unexpected error: {e}")
        return False

if __name__ == "__main__":
    print("Initializing PokeDaddy PostgreSQL database...")
    success = init_database()
    if success:
        print("Database initialization completed successfully!")
        sys.exit(0)
    else:
        print("Database initialization failed!")
        sys.exit(1)
