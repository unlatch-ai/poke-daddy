# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PokeDaddy is a three-component system for smartphone app blocking:
- **iOS App** (`pokedaddy/`): Swift/SwiftUI native app using Apple's Family Controls framework
- **FastAPI Server** (`pokedaddy-server/`): Python server providing centralized control over app restrictions
- **MCP Server** (`pokedaddy-mcp-vercel/`): Serverless MCP server on Vercel providing Model Context Protocol tools for PokeDaddy integration

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

### MCP Server Development
```bash
# Navigate to MCP server directory
cd pokedaddy-mcp-vercel

# Deploy to Vercel
vercel --prod
# Production URL: https://pokedaddy-mcp-vercel.vercel.app/api/mcp

# Test with MCP Inspector
npx @modelcontextprotocol/inspector
# Connect to https://pokedaddy-mcp-vercel.vercel.app/api/mcp
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
- **FastAPI** with SQLAlchemy ORM using PostgreSQL database (Supabase)
- **JWT authentication** with Apple ID integration
- **Key endpoints**:
  - `/auth/register` - User authentication with Apple ID
  - `/profiles/{id}/restricted-apps` - Returns restricted apps only during active blocking
  - `/blocking/toggle` - Users can start blocking (one-way operation)
  - `/admin/unblock-app` - Server-only endpoint for individual app unblocking
  - `/admin/end-blocking` - Server-only endpoint to end blocking sessions

### MCP Server Architecture
- **FastMCP** framework providing Model Context Protocol tools
- **Deployed to Render** at `https://poke-daddy.onrender.com/mcp`
- **Available tools**:
  - `greet` - Welcome message from the MCP server
  - `get_server_info` - Server metadata and environment information
  - `check_blocking_server` - Health check for the main PokeDaddy server

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
- Server uses PostgreSQL database via Supabase (production)
- MCP server auto-deploys to Render on git push to main branch
- CORS is configured for development (`allow_origins=["*"]`)
- JWT tokens expire after 30 minutes
- Apple Family Controls requires special entitlements and App Store Connect configuration
- MCP server provides tools for external integration and monitoring