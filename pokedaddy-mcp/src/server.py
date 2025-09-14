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
        "server_name": "Sample MCP Server",
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
        "user_identification": "Users provide their PokeDaddy API key to link conversations to their account",
        "available_actions": ["View user's blocked apps", "Unblock specific apps", "End entire blocking session"]
    }

# Configuration
POKEDADDY_SERVER_URL = "https://poke-daddy.vercel.app"

@mcp.tool(description="Get a user's current blocking status and restricted apps using their API key")
def get_user_blocking_status(api_key: str) -> dict:
    """Get detailed information about a user's current blocking session"""
    try:
        if not api_key:
            return {"error": "No API key provided", "valid": False}
        
        # For testing, return mock data for test API key
        if api_key == "test":
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
        
        # Call the live server to get blocking status
        headers = {"Authorization": f"Bearer {api_key}"}
        
        # Get blocking status
        status_response = requests.get(
            f"{POKEDADDY_SERVER_URL}/blocking/status",
            headers=headers,
            timeout=10
        )
        
        if status_response.status_code != 200:
            return {"error": f"Failed to get blocking status: {status_response.status_code}", "valid": False}
        
        status_data = status_response.json()
        
        if not status_data.get("is_blocking", False):
            return {
                "valid": True,
                "is_blocking": False,
                "message": "User is not currently blocking any apps"
            }
        
        # Get restricted apps for the active profile
        profile_id = status_data.get("profile_id")
        if profile_id:
            apps_response = requests.get(
                f"{POKEDADDY_SERVER_URL}/profiles/{profile_id}/restricted-apps",
                headers=headers,
                timeout=10
            )
            
            if apps_response.status_code == 200:
                apps_data = apps_response.json()
                return {
                    "valid": True,
                    "is_blocking": True,
                    "profile_id": profile_id,
                    "session_id": status_data.get("session_id"),
                    "started_at": status_data.get("started_at"),
                    "blocked_apps": apps_data.get("restricted_apps", []),
                    "blocked_categories": apps_data.get("restricted_categories", []),
                    "message": f"User is blocking {len(apps_data.get('restricted_apps', []))} apps"
                }
        
        return {
            "valid": True,
            "is_blocking": True,
            "profile_id": profile_id,
            "session_id": status_data.get("session_id"),
            "started_at": status_data.get("started_at"),
            "message": "User is blocking but couldn't retrieve app details"
        }
            
    except Exception as e:
        return {"error": f"Failed to get user status: {str(e)}", "valid": False}

@mcp.tool(description="Unblock a specific app for a user with reasoning")
def unblock_app(api_key: str, app_bundle_id: str, reason: str) -> dict:
    """Unblock a specific app for a user, requires justification"""
    try:
        if not api_key:
            return {"error": "No API key provided", "success": False}
        
        if not app_bundle_id:
            return {"error": "No app bundle ID provided", "success": False}
        
        if not reason:
            return {"error": "No reason provided", "success": False}
        
        # For test API key, return mock success
        if api_key == "test":
            mock_remaining_apps = ["com.twitter.twitter", "com.facebook.Facebook", "com.tiktok.TikTok"]
            return {
                "success": True,
                "message": f"Successfully unblocked {app_bundle_id}",
                "app_unblocked": app_bundle_id,
                "reason_logged": reason,
                "remaining_blocked_apps": mock_remaining_apps
            }
        
        # First get user status to validate API key and get profile ID
        status = get_user_blocking_status(api_key)
        if not status.get("valid", False):
            return {"error": "Invalid API key", "success": False}
        
        if not status.get("is_blocking", False):
            return {"error": "User is not currently blocking any apps", "success": False}
        
        profile_id = status.get("profile_id")
        if not profile_id:
            return {"error": "Could not determine profile ID", "success": False}
        
        # Get user ID by calling the /users/me endpoint
        headers = {"Authorization": f"Bearer {api_key}"}
        user_response = requests.get(
            f"{POKEDADDY_SERVER_URL}/users/me",
            headers=headers,
            timeout=10
        )
        
        if user_response.status_code != 200:
            return {"error": "Failed to get user information", "success": False}
        
        user_data = user_response.json()
        user_id = user_data.get("id")
        
        if not user_id:
            return {"error": "Could not determine user ID", "success": False}
        
        # Call admin endpoint to unblock the app
        response = requests.post(
            f"{POKEDADDY_SERVER_URL}/admin/unblock-app",
            params={
                "app_bundle_id": app_bundle_id,
                "user_id": user_id,
                "profile_id": profile_id
            },
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            return {
                "success": True,
                "message": f"Successfully unblocked {app_bundle_id}",
                "app_unblocked": app_bundle_id,
                "reason_logged": reason,
                "remaining_blocked_apps": data.get("remaining_apps", [])
            }
        else:
            return {"error": f"Failed to unblock app: {response.status_code}", "success": False}
            
    except Exception as e:
        return {"error": f"Failed to unblock app: {str(e)}", "success": False}

@mcp.tool(description="End a user's entire blocking session with reasoning")
def end_blocking_session(api_key: str, reason: str) -> dict:
    """Completely end a user's blocking session, unblocking all apps"""
    try:
        if not api_key:
            return {"error": "No API key provided", "success": False}
        
        if not reason:
            return {"error": "No reason provided", "success": False}
        
        # For test API key, return mock success
        if api_key == "test":
            return {
                "success": True,
                "message": "Successfully ended blocking session",
                "session_ended": True,
                "reason_logged": reason,
                "apps_unblocked": ["com.instagram.app", "com.twitter.twitter", "com.facebook.Facebook", "com.tiktok.TikTok"]
            }
        
        # First get user status to validate API key and get profile ID
        status = get_user_blocking_status(api_key)
        if not status.get("valid", False):
            return {"error": "Invalid API key", "success": False}
        
        if not status.get("is_blocking", False):
            return {"error": "User is not currently blocking any apps", "success": False}
        
        profile_id = status.get("profile_id")
        if not profile_id:
            return {"error": "Could not determine profile ID", "success": False}
        
        # Get user ID by calling the /users/me endpoint
        headers = {"Authorization": f"Bearer {api_key}"}
        user_response = requests.get(
            f"{POKEDADDY_SERVER_URL}/users/me",
            headers=headers,
            timeout=10
        )
        
        if user_response.status_code != 200:
            return {"error": "Failed to get user information", "success": False}
        
        user_data = user_response.json()
        user_id = user_data.get("id")
        
        if not user_id:
            return {"error": "Could not determine user ID", "success": False}
        
        # Call admin endpoint to end the blocking session
        response = requests.post(
            f"{POKEDADDY_SERVER_URL}/admin/end-blocking",
            params={
                "user_id": user_id,
                "profile_id": profile_id
            },
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            return {
                "success": True,
                "message": "Successfully ended blocking session",
                "session_ended": True,
                "session_id": data.get("session_id"),
                "reason_logged": reason
            }
        else:
            return {"error": f"Failed to end blocking session: {response.status_code}", "success": False}
            
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

# import os
# import requests
# from fastmcp import FastMCP

# mcp = FastMCP("PokeDaddy MCP Server")

# # Configuration
# POKEDADDY_SERVER_URL = os.environ.get("POKEDADDY_SERVER_URL", "https://pokedaddy-server.onrender.com")


# @mcp.tool(description="Get a user's current blocking status and restricted apps using their API key")
# def get_user_blocking_status(api_key: str) -> dict:
#     """Get detailed information about a user's current blocking session"""
#     try:
#         if not api_key:
#             return {"error": "No API key provided", "valid": False}
        
#         # Validate the API key and get user info
#         user_info = _validate_api_key(api_key)
#         if not user_info["valid"]:
#             return {"error": "Invalid API key", "valid": False}
        
#         user_id = user_info["user_id"]
        
#         # For test API key, return mock data
#         if user_id == "test_user_123":
#             return {
#                 "valid": True,
#                 "user_id": user_id,
#                 "is_blocking": True,
#                 "profile_name": "Focus Mode",
#                 "blocked_apps": [
#                     "com.instagram.instagram",
#                     "com.facebook.facebook",
#                     "com.twitter.twitter",
#                     "com.tiktok.tiktok",
#                     "com.snapchat.snapchat"
#                 ],
#                 "blocked_categories": ["Social Networking", "Entertainment"],
#                 "session_started": "2025-09-13T18:00:00Z",
#                 "total_blocked_count": 5
#             }
        
#         # Get blocking status from main server for real users
#         response = requests.get(
#             f"{POKEDADDY_SERVER_URL}/admin/user-status/{user_id}",
#             timeout=10
#         )
        
#         if response.status_code == 200:
#             data = response.json()
#             return {
#                 "valid": True,
#                 "user_id": user_id,
#                 "is_blocking": data.get("is_blocking", False),
#                 "profile_name": data.get("profile_name"),
#                 "blocked_apps": data.get("blocked_apps", []),
#                 "blocked_categories": data.get("blocked_categories", []),
#                 "session_started": data.get("session_started"),
#                 "total_blocked_count": len(data.get("blocked_apps", []))
#             }
#         else:
#             return {"error": f"Server error: {response.status_code}", "valid": False}
            
#     except Exception as e:
#         return {"error": f"Failed to get user status: {str(e)}", "valid": False}

# @mcp.tool(description="Unblock a specific app for a user after they've justified their need")
# def unblock_app(api_key: str, app_bundle_id: str, reason: str) -> dict:
#     """Unblock a specific app for a user with reasoning"""
#     try:
#         if not api_key:
#             return {"error": "No API key provided", "success": False}
        
#         # Validate API key
#         user_info = _validate_api_key(api_key)
#         if not user_info["valid"]:
#             return {"error": "Invalid API key", "success": False}
        
#         user_id = user_info["user_id"]
        
#         # For test user, return mock success response
#         if user_id == "test_user_123":
#             # Mock remaining apps after unblocking one
#             mock_remaining_apps = [
#                 "com.facebook.facebook",
#                 "com.twitter.twitter",
#                 "com.tiktok.tiktok",
#                 "com.snapchat.snapchat"
#             ]
#             if app_bundle_id == "com.instagram.instagram":
#                 mock_remaining_apps = [app for app in mock_remaining_apps if app != app_bundle_id]
            
#             return {
#                 "success": True,
#                 "message": f"Successfully unblocked {app_bundle_id}",
#                 "app_unblocked": app_bundle_id,
#                 "reason_logged": reason,
#                 "remaining_blocked_apps": mock_remaining_apps
#             }
        
#         # Call main server admin endpoint to unblock the app for real users
#         response = requests.post(
#             f"{POKEDADDY_SERVER_URL}/admin/unblock-app",
#             json={
#                 "user_id": user_id,
#                 "app_bundle_id": app_bundle_id,
#                 "reason": reason,
#                 "unblocked_by": "poke.com_agent"
#             },
#             timeout=10
#         )
        
#         if response.status_code == 200:
#             data = response.json()
#             return {
#                 "success": True,
#                 "message": f"Successfully unblocked {app_bundle_id}",
#                 "app_unblocked": app_bundle_id,
#                 "reason_logged": reason,
#                 "remaining_blocked_apps": data.get("remaining_apps", [])
#             }
#         else:
#             return {"error": f"Failed to unblock app: {response.status_code}", "success": False}
            
#     except Exception as e:
#         return {"error": f"Failed to unblock app: {str(e)}", "success": False}

# @mcp.tool(description="End a user's entire blocking session with reasoning")
# def end_blocking_session(api_key: str, reason: str) -> dict:
#     """Completely end a user's blocking session, unblocking all apps"""
#     try:
#         if not api_key:
#             return {"error": "No API key provided", "success": False}
        
#         # Validate API key
#         user_info = _validate_api_key(api_key)
#         if not user_info["valid"]:
#             return {"error": "Invalid API key", "success": False}
        
#         user_id = user_info["user_id"]
        
#         # For test user, return mock success response
#         if user_id == "test_user_123":
#             return {
#                 "success": True,
#                 "message": "Blocking session ended - all apps unblocked",
#                 "session_id": "mock_session_456",
#                 "reason_logged": reason,
#                 "apps_unblocked": "all"
#             }
        
#         # Call main server admin endpoint to end blocking session for real users
#         response = requests.post(
#             f"{POKEDADDY_SERVER_URL}/admin/end-blocking",
#             json={
#                 "user_id": user_id,
#                 "reason": reason,
#                 "ended_by": "poke.com_agent"
#             },
#             timeout=10
#         )
        
#         if response.status_code == 200:
#             data = response.json()
#             return {
#                 "success": True,
#                 "message": "Blocking session ended - all apps unblocked",
#                 "session_id": data.get("session_id"),
#                 "reason_logged": reason,
#                 "apps_unblocked": "all"
#             }
#         else:
#             return {"error": f"Failed to end session: {response.status_code}", "success": False}
            
#     except Exception as e:
#         return {"error": f"Failed to end session: {str(e)}", "success": False}

# @mcp.tool(description="Get information about what a specific app is typically used for")
# def get_app_info(app_bundle_id: str) -> dict:
#     """Get context about an app to help make unblocking decisions"""
#     # Common app categories and descriptions
#     app_database = {
#         "com.instagram.instagram": {
#             "name": "Instagram",
#             "category": "Social Media",
#             "typical_use": "Photo sharing, social networking, entertainment",
#             "productivity_score": 2,
#             "common_justifications": ["Business promotion", "Staying in touch with family", "Art inspiration"]
#         },
#         "com.facebook.facebook": {
#             "name": "Facebook",
#             "category": "Social Media",
#             "typical_use": "Social networking, news, marketplace",
#             "productivity_score": 3,
#             "common_justifications": ["Business pages", "Community groups", "Marketplace"]
#         },
#         "com.twitter.twitter": {
#             "name": "Twitter/X",
#             "category": "Social Media",
#             "typical_use": "News, social networking, real-time updates",
#             "productivity_score": 4,
#             "common_justifications": ["Breaking news", "Professional networking", "Industry updates"]
#         },
#         "com.apple.mobilemail": {
#             "name": "Mail",
#             "category": "Productivity",
#             "typical_use": "Email communication",
#             "productivity_score": 9,
#             "common_justifications": ["Work emails", "Important communications", "Emergency contact"]
#         },
#         "com.microsoft.office.outlook": {
#             "name": "Outlook",
#             "category": "Productivity",
#             "typical_use": "Email, calendar, work communication",
#             "productivity_score": 9,
#             "common_justifications": ["Work requirements", "Meeting invites", "Business communication"]
#         }
#     }
    
#     app_info = app_database.get(app_bundle_id, {
#         "name": app_bundle_id.split(".")[-1].title(),
#         "category": "Unknown",
#         "typical_use": "Unknown app - research needed",
#         "productivity_score": 5,
#         "common_justifications": ["User should explain what this app does"]
#     })
    
#     return {
#         "app_bundle_id": app_bundle_id,
#         "app_name": app_info["name"],
#         "category": app_info["category"],
#         "typical_use": app_info["typical_use"],
#         "productivity_score": app_info["productivity_score"],
#         "common_justifications": app_info["common_justifications"],
#         "agent_guidance": _get_agent_guidance(app_info["productivity_score"])
#     }

# def _get_agent_guidance(productivity_score: int) -> str:
#     """Get guidance for the agent based on app productivity score"""
#     if productivity_score >= 8:
#         return "High productivity app - consider unblocking with minimal resistance"
#     elif productivity_score >= 6:
#         return "Moderate productivity - require good justification"
#     elif productivity_score >= 4:
#         return "Mixed use app - be moderately skeptical, require solid reasoning"
#     else:
#         return "Entertainment/distraction app - be very skeptical, require excellent justification"

# # Removed _extract_api_key() function since API key comes as parameter

# def _validate_api_key(api_key: str) -> dict:
#     """Validate API key with main server (placeholder for now)"""
#     # For testing, accept "test" as a valid API key
#     if api_key == "test":
#         return {
#             "valid": True,
#             "user_id": "test_user_123"
#         }
#     # TODO: This will call the main server to validate the API key
#     # For now, return a mock response for other keys
#     elif api_key and len(api_key) >= 10:  # Basic validation
#         return {
#             "valid": True,
#             "user_id": f"user_{api_key[:8]}"  # Mock user ID
#         }
#     else:
#         return {"valid": False}

# @mcp.tool(description="Check if the PokeDaddy blocking server is accessible")
# def check_blocking_server() -> dict:
#     """Check the status of the PokeDaddy blocking server"""
#     try:
#         response = requests.get(f"{POKEDADDY_SERVER_URL}/", timeout=10)
#         return {
#             "status": "accessible" if response.status_code == 200 else "error",
#             "status_code": response.status_code,
#             "server_url": POKEDADDY_SERVER_URL
#         }
#     except Exception as e:
#         return {
#             "status": "error",
#             "error": str(e),
#             "server_url": POKEDADDY_SERVER_URL
#         }


# if __name__ == "__main__":
#     port = int(os.environ.get("PORT", 8000))
#     host = "0.0.0.0"
    
#     print(f"Starting PokeDaddy FastMCP server on {host}:{port}")
    
#     mcp.run(
#         transport="http",
#         host=host,
#         port=port
#     )