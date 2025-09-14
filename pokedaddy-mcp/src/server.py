#!/usr/bin/env python3
import os
from fastmcp import FastMCP
from fastapi.middleware.cors import CORSMiddleware
from fastapi import Response

mcp = FastMCP("PokeDaddy MCP Server")

# Add CORS middleware to handle cross-origin requests and SSE headers
mcp.app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*", "Accept", "Content-Type", "Cache-Control"],
    expose_headers=["*"],
)

# Add middleware to handle SSE content-type requirements
@mcp.app.middleware("http")
async def add_sse_headers(request, call_next):
    response = await call_next(request)
    
    # For MCP endpoints, ensure proper SSE headers
    if request.url.path.startswith("/mcp"):
        response.headers["Content-Type"] = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["Connection"] = "keep-alive"
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "Accept, Content-Type, Cache-Control"
    
    return response

@mcp.tool(description="Greet a user by name with a welcome message from the PokeDaddy MCP server")
def greet(name: str) -> str:
    return f"Hello, {name}! Welcome to the PokeDaddy MCP server running on Render!"

@mcp.tool(description="Get information about the PokeDaddy MCP server including name, version, environment, and Python version")
def get_server_info() -> dict:
    return {
        "server_name": "PokeDaddy MCP Server",
        "version": "1.0.0",
        "environment": os.environ.get("ENVIRONMENT", "production"),
        "python_version": os.sys.version.split()[0],
        "platform": "Render"
    }

@mcp.tool(description="Check if the PokeDaddy blocking server is accessible")
def check_blocking_server() -> dict:
    """Check the status of the PokeDaddy blocking server"""
    import requests
    try:
        # Check if the main PokeDaddy server is running
        response = requests.get("https://pokedaddy-server.onrender.com/", timeout=10)
        return {
            "status": "accessible" if response.status_code == 200 else "error",
            "status_code": response.status_code,
            "server_url": "https://pokedaddy-server.onrender.com"
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "server_url": "https://pokedaddy-server.onrender.com"
        }

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    host = "0.0.0.0"
    
    print(f"Starting PokeDaddy FastMCP server on {host}:{port}")
    
    mcp.run(
        transport="http",
        host=host,
        port=port
    )