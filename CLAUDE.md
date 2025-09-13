# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PokeDaddy is a dual-component system for smartphone app blocking:
- **iOS App** (`pokedaddy/`): Swift/SwiftUI native app using Apple's Family Controls framework
- **FastAPI Server** (`pokedaddy-server/`): Python server providing centralized control over app restrictions

The architecture implements one-way blocking: users can start app restrictions but only the server can end them or unblock individual apps.

## Common Development Commands

### Server Development
```bash
# Navigate to server directory
cd pokedaddy-server

# Install dependencies
pip install -r requirements.txt

# Start development server
python main.py
# Server runs on http://localhost:8000
```

### iOS Development
```bash
# Open Xcode project
open pokedaddy/PokeDaddy.xcodeproj

# Build and run from Xcode (requires physical device for NFC functionality)
```

## Architecture Overview

### Core iOS Components
- **APIService**: Handles all server communication and JWT token management
- **AppBlocker**: Manages app restrictions using Apple's Family Controls and ManagedSettings frameworks
- **AuthenticationManager**: Handles Apple Sign In integration and user authentication
- **ProfileManager**: Manages restriction profiles (local storage + server sync)
- **NfcReader**: NFC tag reading functionality (legacy component)

### Server Architecture
- **FastAPI** with SQLAlchemy ORM using SQLite database
- **JWT authentication** with Apple ID integration
- **Key endpoints**:
  - `/auth/register` - User authentication with Apple ID
  - `/profiles/{id}/restricted-apps` - Returns restricted apps only during active blocking
  - `/blocking/toggle` - Users can start blocking (one-way operation)
  - `/admin/unblock-app` - Server-only endpoint for individual app unblocking
  - `/admin/end-blocking` - Server-only endpoint to end blocking sessions

### Security Model
- **Server Authority**: Only server can end blocking sessions or unblock apps
- **One-Way User Control**: Users initiate blocking but cannot self-unblock
- **Session-Based**: Apps are restricted only during active blocking sessions
- **Apple Sign In**: Trusted authentication provider with server verification

## Key Data Flow

1. User authenticates via Apple Sign In (iOS → Server)
2. User creates profiles specifying apps to block (iOS ↔ Server sync)
3. User starts blocking session (iOS → Server)
4. iOS app queries `/profiles/{id}/restricted-apps` to get current restrictions
5. External systems can control app access via admin endpoints
6. Only server can end blocking or unblock individual apps

## Development Notes

- iOS app requires physical device for Family Controls functionality
- Server uses SQLite database (`pokedaddy.db`) created automatically
- CORS is configured for development (`allow_origins=["*"]`)
- JWT tokens expire after 30 minutes
- Apple Family Controls requires special entitlements and App Store Connect configuration