#!/usr/bin/env python3
import os
import requests
from fastmcp import FastMCP

mcp = FastMCP("PokeDaddy MCP Server")

@mcp.tool(description="Greet a user by name with a welcome message from the MCP server")
def greet(name: str) -> str:
    return f"Hello, {name}! Welcome to PokeDaddy MCP server!"

@mcp.tool(description="Get information about the MCP server including name, version, environment, and Python version")
def get_server_info() -> dict:
    return {
        "server_name": "PokeDaddy MCP Server",
        "version": "1.0.0",
        "environment": os.environ.get("ENVIRONMENT", "development"),
        "python_version": os.sys.version.split()[0]
    }

@mcp.tool(description="Get MCP configuration and API target information")
def get_mcp_config() -> dict:
    return {
        "pokedaddy_server_url": POKEDADDY_SERVER_URL,
        "environment": os.environ.get("ENVIRONMENT", "development")
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
POKEDADDY_SERVER_URL = os.environ.get("POKEDADDY_SERVER_URL", "https://poke-daddy.vercel.app")

@mcp.tool(description="Get a user's current blocking status and restricted apps using their email")
def get_user_blocking_status(user_email: str = "", email: str = "") -> dict:
    """Calls the server's /admin/status-by-email to return status for a given user."""
    try:
        user_email = user_email or email
        if not user_email:
            return {"error": "No user email provided", "valid": False}

        response = requests.get(f"{POKEDADDY_SERVER_URL}/admin/status-by-email",
                              params={"email": user_email}, timeout=25)
        print(f"[MCP] GET {response.url} response: {response.status_code}")
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"[MCP] get_user_blocking_status error: {e}")
        return {"error": str(e), "valid": False}

@mcp.tool(description="Unblock a specific app for a user with reasoning")
def unblock_app(user_email: str = "", email: str = "", app_bundle_id: str = "", appBundleId: str = "", reason: str = "") -> dict:
    """Calls /admin/unblock-app-by-email on the server to remove the app from the user's restricted list."""
    try:
        user_email = user_email or email
        if not user_email:
            return {"error": "No user email provided", "success": False}
        app_bundle_id = app_bundle_id or appBundleId
        if not app_bundle_id:
            return {"error": "No app bundle ID provided", "success": False}

        response = requests.post(f"{POKEDADDY_SERVER_URL}/admin/unblock-app-by-email",
                               params={"email": user_email, "app_bundle_id": app_bundle_id}, timeout=25)
        print(f"[MCP] POST {response.url} response: {response.status_code}")
        response.raise_for_status()
        result = response.json()
        result["success"] = True
        result["reason"] = reason
        return result
    except Exception as e:
        print(f"[MCP] unblock_app error: {e}")
        return {"error": str(e), "success": False}

@mcp.tool(description="End a user's entire blocking session with reasoning")
def end_blocking_session(user_email: str = "", email: str = "", reason: str = "") -> dict:
    """Calls /admin/end-blocking-by-email to end the user's blocking session."""
    try:
        user_email = user_email or email
        if not user_email:
            return {"error": "No user email provided", "success": False}

        response = requests.post(f"{POKEDADDY_SERVER_URL}/admin/end-blocking-by-email",
                               params={"email": user_email}, timeout=25)
        print(f"[MCP] POST {response.url} response: {response.status_code}")
        response.raise_for_status()
        result = response.json()
        result["success"] = True
        result["session_ended"] = True
        result["reason"] = reason
        return result
    except Exception as e:
        print(f"[MCP] end_blocking_session error: {e}")
        return {"error": str(e), "success": False}

@mcp.tool(description="Start a user's blocking session by email (optionally choose a profile)")
def start_blocking_session(user_email: str = "", email: str = "", profile_id: str = "", profileId: str = "", profile_name: str = "", profileName: str = "") -> dict:
    """Calls /admin/start-blocking-by-email to start a blocking session for the user.
    The user must foreground/refresh the iOS app to enforce shields after this call.
    """
    try:
        user_email = user_email or email
        if not user_email:
            return {"error": "No user email provided", "success": False}

        params = {"email": user_email}
        profile_id = profile_id or profileId
        profile_name = profile_name or profileName
        if profile_id:
            params["profile_id"] = profile_id
        if profile_name:
            params["profile_name"] = profile_name

        response = requests.post(f"{POKEDADDY_SERVER_URL}/admin/start-blocking-by-email",
                               params=params, timeout=25)
        print(f"[MCP] POST {response.url} response: {response.status_code}")
        response.raise_for_status()
        result = response.json()
        result["success"] = True
        return result
    except Exception as e:
        print(f"[MCP] start_blocking_session error: {e}")
        return {"error": str(e), "success": False}

# Health check tool
@mcp.tool(description="Health check for MCP server")
def health() -> dict:
    return {"status": "ok"}

# Tool aliases to tolerate different client naming conventions
@mcp.tool(description="Alias of get_server_info")
def getserverinfo() -> dict:
    return get_server_info()

@mcp.tool(description="Alias of get_pokedaddy_info")
def getpokedaddyinfo() -> dict:
    return get_pokedaddy_info()

@mcp.tool(description="Alias of get_user_blocking_status")
def getuserblocking_status(email: str = "", user_email: str = "") -> dict:
    return get_user_blocking_status(user_email=user_email or email)

@mcp.tool(description="Alias of end_blocking_session")
def endblockingsession(email: str = "", user_email: str = "", reason: str = "") -> dict:
    return end_blocking_session(user_email=user_email or email, reason=reason)

@mcp.tool(description="Alias of start_blocking_session")
def startblockingsession(email: str = "", user_email: str = "", profile_id: str = "", profileId: str = "", profile_name: str = "", profileName: str = "") -> dict:
    return start_blocking_session(user_email=user_email or email, profile_id=profile_id or profileId, profile_name=profile_name or profileName)

@mcp.tool(description="Alias of unblock_app")
def unblockapp(email: str = "", user_email: str = "", app_bundle_id: str = "", appBundleId: str = "", reason: str = "") -> dict:
    return unblock_app(user_email=user_email or email, app_bundle_id=app_bundle_id or appBundleId, reason=reason)

# Vercel serverless handler
from fastmcp.adapters.vercel import VercelMCPAdapter

handler = VercelMCPAdapter(mcp).create_handler()