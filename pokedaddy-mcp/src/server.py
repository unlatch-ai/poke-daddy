#!/usr/bin/env python3
import os
from fastmcp import FastMCP

mcp = FastMCP("PokeDaddy MCP Server")

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