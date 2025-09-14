#!/usr/bin/env python3
import os
import requests
import json
from http.server import BaseHTTPRequestHandler

# Configuration - points to your main PokeDaddy API
POKEDADDY_SERVER_URL = os.environ.get("POKEDADDY_SERVER_URL", "https://poke-daddy.vercel.app")

def health() -> dict:
    return {"status": "ok", "api_target": POKEDADDY_SERVER_URL}

def get_server_info() -> dict:
    return {
        "server_name": "PokeDaddy MCP Server",
        "version": "1.0.0",
        "environment": "production",
        "api_target": POKEDADDY_SERVER_URL,
        "python_version": "3.9"
    }

def get_mcp_config() -> dict:
    return {
        "pokedaddy_server_url": POKEDADDY_SERVER_URL,
        "environment": "production"
    }

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

def unblock_app(user_email: str = "", email: str = "", app_bundle_id: str = "", appBundleId: str = "", reason: str = "") -> dict:
    """Calls /admin/unblock-app-by-email on the server to remove the app from the user's restricted list."""
    try:
        user_email = user_email or email
        app_bundle_id = app_bundle_id or appBundleId
        if not user_email:
            return {"error": "No user email provided", "success": False}
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

def start_blocking_session(user_email: str = "", email: str = "", profile_id: str = "", profileId: str = "", profile_name: str = "", profileName: str = "") -> dict:
    """Calls /admin/start-blocking-by-email to start a blocking session for the user."""
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

# Tool aliases
def getserverinfo() -> dict:
    return get_server_info()

def getuserblocking_status(email: str = "", user_email: str = "") -> dict:
    return get_user_blocking_status(user_email=user_email or email)

def endblockingsession(email: str = "", user_email: str = "", reason: str = "") -> dict:
    return end_blocking_session(user_email=user_email or email, reason=reason)

def startblockingsession(email: str = "", user_email: str = "", profile_id: str = "", profileId: str = "", profile_name: str = "", profileName: str = "") -> dict:
    return start_blocking_session(user_email=user_email or email, profile_id=profile_id or profileId, profile_name=profile_name or profileName)

def unblockapp(email: str = "", user_email: str = "", app_bundle_id: str = "", appBundleId: str = "", reason: str = "") -> dict:
    return unblock_app(user_email=user_email or email, app_bundle_id=app_bundle_id or appBundleId, reason=reason)

# Tool function mapping
TOOLS = {
    "health": health,
    "get_server_info": get_server_info,
    "getserverinfo": get_server_info,
    "get_mcp_config": get_mcp_config,
    "get_user_blocking_status": get_user_blocking_status,
    "getuserblocking_status": get_user_blocking_status,
    "end_blocking_session": end_blocking_session,
    "endblockingsession": end_blocking_session,
    "unblock_app": unblock_app,
    "unblockapp": unblock_app,
    "start_blocking_session": start_blocking_session,
    "startblockingsession": start_blocking_session,
}

TOOL_DESCRIPTIONS = [
    {"name": "health", "description": "Health check for MCP server"},
    {"name": "get_server_info", "description": "Get server information"},
    {"name": "getserverinfo", "description": "Alias of get_server_info"},
    {"name": "get_mcp_config", "description": "Get MCP configuration"},
    {"name": "get_user_blocking_status", "description": "Get user blocking status by email"},
    {"name": "getuserblocking_status", "description": "Alias of get_user_blocking_status"},
    {"name": "end_blocking_session", "description": "End user blocking session"},
    {"name": "endblockingsession", "description": "Alias of end_blocking_session"},
    {"name": "unblock_app", "description": "Unblock specific app"},
    {"name": "unblockapp", "description": "Alias of unblock_app"},
    {"name": "start_blocking_session", "description": "Start blocking session"},
    {"name": "startblockingsession", "description": "Alias of start_blocking_session"},
]

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Check if client wants SSE format
        accept_header = self.headers.get('Accept', '')
        wants_sse = 'text/event-stream' in accept_header

        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')

        # Return MCP-style response similar to what Render server returns
        response = {
            "jsonrpc": "2.0",
            "error": {
                "code": -32600,
                "message": "Invalid Request - use POST with proper MCP protocol"
            }
        }

        if wants_sse:
            # Send as Server-Sent Events format
            self.send_header('Content-type', 'text/event-stream')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Connection', 'keep-alive')
            self.end_headers()
            sse_data = f"event: message\ndata: {json.dumps(response)}\n\n"
            self.wfile.write(sse_data.encode())
        else:
            # Send as regular JSON
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())

    def do_OPTIONS(self):
        # Handle preflight CORS requests
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()

    def do_POST(self):
        try:
            # Check Accept header to determine if client wants SSE format
            accept_header = self.headers.get('Accept', '')
            wants_sse = 'text/event-stream' in accept_header

            # For SSE format, require both json and event-stream in Accept header
            if wants_sse and 'application/json' not in accept_header:
                self.send_response(406)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                error_response = {
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32600,
                        "message": "Not Acceptable: Client must accept both application/json and text/event-stream"
                    }
                }
                self.wfile.write(json.dumps(error_response).encode())
                return

            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8')

            # Handle empty body
            if not body.strip():
                body = '{}'

            body_json = json.loads(body)

            method = body_json.get('method', '')

            if method == 'initialize':
                # MCP initialize handshake - return server capabilities
                response = {
                    "jsonrpc": "2.0",
                    "id": body_json.get("id"),
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {
                            "tools": {}
                        },
                        "serverInfo": {
                            "name": "PokeDaddy MCP Server",
                            "version": "1.0.0"
                        }
                    }
                }
            elif method == 'notifications/initialized':
                # Client finished initialization - just acknowledge
                response = {
                    "jsonrpc": "2.0",
                    "id": body_json.get("id"),
                    "result": {}
                }
            elif method == 'tools/list':
                response = {
                    "jsonrpc": "2.0",
                    "id": body_json.get("id"),
                    "result": {"tools": TOOL_DESCRIPTIONS}
                }
            elif method == 'tools/call':
                tool_name = body_json.get('params', {}).get('name', '')
                args = body_json.get('params', {}).get('arguments', {})

                if tool_name in TOOLS:
                    result = TOOLS[tool_name](**args)
                else:
                    result = {"error": f"Unknown tool: {tool_name}"}

                response = {
                    "jsonrpc": "2.0",
                    "id": body_json.get("id"),
                    "result": result
                }
            else:
                self.send_response(400)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                error_response = {
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32600,
                        "message": f"Invalid MCP method: {method}"
                    }
                }
                self.wfile.write(json.dumps(error_response).encode())
                return

            # Send response in appropriate format
            self.send_response(200)
            self.send_header('Access-Control-Allow-Origin', '*')

            if wants_sse:
                # Send as Server-Sent Events format (Streamable HTTP)
                self.send_header('Content-type', 'text/event-stream')
                self.send_header('Cache-Control', 'no-cache')
                self.send_header('Connection', 'keep-alive')
                self.end_headers()
                sse_data = f"event: message\ndata: {json.dumps(response)}\n\n"
                self.wfile.write(sse_data.encode())
            else:
                # Send as regular JSON
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())

        except Exception as e:
            print(f"[MCP] Handler error: {e}")
            self.send_response(500)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            error_response = {
                "jsonrpc": "2.0",
                "error": {
                    "code": -32603,
                    "message": f"Internal error: {str(e)}"
                }
            }
            self.wfile.write(json.dumps(error_response).encode())