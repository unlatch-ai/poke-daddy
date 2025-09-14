#!/usr/bin/env python3
import os
import requests
from fastmcp import FastMCP

mcp = FastMCP("Sample MCP Server")

@mcp.tool(description="Greet a user by name with a welcome message from the MCP server")
def greet(name: str) -> str:
    return f"Hello, {name}! Welcome to our sample MCP server running on Heroku!"

@mcp.tool(description="Get information about the MCP server including name, version, environment, and Python version")
def get_server_info() -> dict:
    return {
        "server_name": "PokeDaddy MCP Server",
        "version": "1.0.0",
        "environment": os.environ.get("ENVIRONMENT", "development"),
        "python_version": os.sys.version.split()[0]
    }

@mcp.tool(description="Get comprehensive information about the PokeDaddy system for agent context")
def get_pokedaddy_info() -> dict:
    """Provides complete context about PokeDaddy for the poke.com agent"""
    return {
        "system_name": "PokeDaddy",
        "purpose": "A digital wellness app that helps users reduce smartphone distractions by blocking apps",
        "blocking_model": {
            "user_control": "Users can START blocking sessions but cannot stop them",
            "agent_control": "Only external agents (like poke.com) can unblock apps or end sessions",
            "philosophy": "Users voluntarily restrict themselves, then must justify to an agent why they need access"
        },
        "how_it_works": [
            "1. User creates profiles specifying which apps to block",
            "2. User starts a blocking session in the iOS app",
            "3. Selected apps become inaccessible on their device",
            "4. To regain access, user must interact with poke.com agent",
            "5. Agent decides whether to unblock based on user's justification"
        ],
        "agent_role": {
            "responsibility": "Act as gatekeeper for app access",
            "personality": "Be sassy and make users work for their unblocks",
            "decision_factors": ["Legitimacy of need", "User's argument quality", "App type (productivity vs entertainment)"]
        },
        "user_identification": "Users provide their email address to link conversations to their account",
        "available_actions": ["View user's blocked apps", "Unblock specific apps", "End entire blocking session"]
    }

# Configuration
POKEDADDY_SERVER_URL = "https://poke-daddy.vercel.app"

@mcp.tool(description="Get a user's current blocking status and restricted apps using their email")
def get_user_blocking_status(user_email: str) -> dict:
    """Get detailed information about a user's current blocking session"""
    try:
        if not user_email:
            return {"error": "No user email provided", "valid": False}
        
        # For testing, return mock data for test email
        if user_email == "deatrh1kiss@gmail.com":
            return {
                "valid": True,
                "user_id": "test_user_123",
                "is_blocking": True,
                "profile_id": "test_profile_456",
                "session_id": "test_session_789",
                "started_at": "2024-01-15T10:30:00Z",
                "blocked_apps": [
                    "com.instagram.app",
                    "com.twitter.twitter", 
                    "com.facebook.Facebook",
                    "com.tiktok.TikTok"
                ],
                "blocked_categories": ["Social Media", "Entertainment"],
                "message": "User is currently blocking 4 apps in Social Media and Entertainment categories"
            }
        
        # For live server, we'll need to implement email-based lookup
        # For now, return error since we need API key for JWT auth
        return {"error": "Live server integration requires API key, not email. Email-based lookup not yet implemented.", "valid": False}
            
    except Exception as e:
        return {"error": f"Failed to get user status: {str(e)}", "valid": False}

@mcp.tool(description="Unblock a specific app for a user with reasoning")
def unblock_app(user_email: str, app_bundle_id: str, reason: str) -> dict:
    """Unblock a specific app for a user, requires justification"""
    try:
        if not user_email:
            return {"error": "No user email provided", "success": False}
        
        if not app_bundle_id:
            return {"error": "No app bundle ID provided", "success": False}
        
        if not reason:
            return {"error": "No reason provided", "success": False}
        
        # For test email, return mock success
        if user_email == "deatrh1kiss@gmail.com":
            mock_remaining_apps = ["com.twitter.twitter", "com.facebook.Facebook", "com.tiktok.TikTok"]
            return {
                "success": True,
                "message": f"Successfully unblocked {app_bundle_id}",
                "app_unblocked": app_bundle_id,
                "reason_logged": reason,
                "remaining_blocked_apps": mock_remaining_apps
            }
        
        # For live server, we need to implement email-to-user-ID lookup
        # For now, return error since we need proper authentication
        return {"error": "Live server integration requires API key authentication. Email-based lookup not yet implemented.", "success": False}
            
    except Exception as e:
        return {"error": f"Failed to unblock app: {str(e)}", "success": False}

@mcp.tool(description="End a user's entire blocking session with reasoning")
def end_blocking_session(user_email: str, reason: str) -> dict:
    """Completely end a user's blocking session, unblocking all apps"""
    try:
        if not user_email:
            return {"error": "No user email provided", "success": False}
        
        if not reason:
            return {"error": "No reason provided", "success": False}
        
        # For test email, return mock success
        if user_email == "deatrh1kiss@gmail.com":
            return {
                "success": True,
                "message": "Successfully ended blocking session",
                "session_ended": True,
                "reason_logged": reason,
                "apps_unblocked": ["com.instagram.app", "com.twitter.twitter", "com.facebook.Facebook", "com.tiktok.TikTok"]
            }
        
        # For live server, we need to implement email-to-user-ID lookup
        # For now, return error since we need proper authentication
        return {"error": "Live server integration requires API key authentication. Email-based lookup not yet implemented.", "success": False}
            
    except Exception as e:
        return {"error": f"Failed to end blocking session: {str(e)}", "success": False}


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    host = "0.0.0.0"
    
    print(f"Starting FastMCP server on {host}:{port}")
    
    mcp.run(
        transport="http",
        host=host,
        port=port
    )
