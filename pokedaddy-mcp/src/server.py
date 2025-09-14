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
POKEDADDY_SERVER_URL = os.environ.get("POKEDADDY_SERVER_URL", "https://poke-daddy.vercel.app")

@mcp.tool(description="Show MCP config, including server URL and environment")
def get_mcp_config() -> dict:
    return {
        "pokedaddy_server_url": POKEDADDY_SERVER_URL,
        "environment": os.environ.get("ENVIRONMENT", "development")
    }

@mcp.tool(description="Get a user's current blocking status and restricted apps using their email")
def get_user_blocking_status(user_email: str) -> dict:
    """Calls the server's /admin/status-by-email to return status for a given user."""
    try:
        if not user_email:
            return {"error": "No user email provided", "valid": False}
        url = f"{POKEDADDY_SERVER_URL}/admin/status-by-email"
        print(f"[MCP] GET {url}?email=…")
        r = requests.get(url, params={"email": user_email}, timeout=25)
        print(f"[MCP] status response: {r.status_code}")
        if r.status_code != 200:
            return {"error": f"status lookup failed: {r.status_code} {r.text}", "valid": False}
        data = r.json()
        return data
    except Exception as e:
        return {"error": f"Failed to get user status: {str(e)}", "valid": False}

@mcp.tool(description="Unblock a specific app for a user with reasoning")
def unblock_app(user_email: str, app_bundle_id: str, reason: str = "") -> dict:
    """Calls /admin/unblock-app-by-email on the server to remove the app from the user's restricted list."""
    try:
        if not user_email:
            return {"error": "No user email provided", "success": False}
        if not app_bundle_id:
            return {"error": "No app bundle ID provided", "success": False}
        url = f"{POKEDADDY_SERVER_URL}/admin/unblock-app-by-email"
        print(f"[MCP] POST {url}?email=…&app_bundle_id={app_bundle_id}")
        r = requests.post(url, params={"email": user_email, "app_bundle_id": app_bundle_id}, timeout=25)
        print(f"[MCP] unblock response: {r.status_code}")
        if r.status_code != 200:
            return {"error": f"unblock failed: {r.status_code} {r.text}", "success": False}
        data = r.json()
        data.update({"success": True, "app_unblocked": app_bundle_id, "reason_logged": reason})
        return data
    except Exception as e:
        return {"error": f"Failed to unblock app: {str(e)}", "success": False}

@mcp.tool(description="End a user's entire blocking session with reasoning")
def end_blocking_session(user_email: str, reason: str = "") -> dict:
    """Calls /admin/end-blocking-by-email to end the user's blocking session."""
    try:
        if not user_email:
            return {"error": "No user email provided", "success": False}
        url = f"{POKEDADDY_SERVER_URL}/admin/end-blocking-by-email"
        print(f"[MCP] POST {url}?email=…")
        r = requests.post(url, params={"email": user_email}, timeout=25)
        print(f"[MCP] end response: {r.status_code}")
        if r.status_code != 200:
            return {"error": f"end-blocking failed: {r.status_code} {r.text}", "success": False}
        data = r.json()
        data.update({"success": True, "session_ended": True, "reason_logged": reason})
        return data
    except Exception as e:
        return {"error": f"Failed to end blocking session: {str(e)}", "success": False}


@mcp.tool(description="Start a user's blocking session by email (optionally choose a profile)")
def start_blocking_session(user_email: str, profile_id: str = "", profile_name: str = "") -> dict:
    """Calls /admin/start-blocking-by-email to start a blocking session for the user.
    If profile_id is blank, the server uses the default or first profile.
    """
    try:
        if not user_email:
            return {"error": "No user email provided", "success": False}
        url = f"{POKEDADDY_SERVER_URL}/admin/start-blocking-by-email"
        params = {"email": user_email}
        if profile_id:
            params["profile_id"] = profile_id
        if profile_name:
            params["profile_name"] = profile_name
        print(f"[MCP] POST {url} {params}")
        r = requests.post(url, params=params, timeout=25)
        print(f"[MCP] start response: {r.status_code} {r.text[:200]}")
        if r.status_code != 200:
            return {"error": f"start-blocking failed: {r.status_code} {r.text}", "success": False}
        data = r.json()
        data.update({"success": True})
        return data
    except Exception as e:
        return {"error": f"Failed to start blocking session: {str(e)}", "success": False}


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    host = "0.0.0.0"
    
    print(f"Starting FastMCP server on {host}:{port}")
    
    mcp.run(
        transport="http",
        host=host,
        port=port
    )
