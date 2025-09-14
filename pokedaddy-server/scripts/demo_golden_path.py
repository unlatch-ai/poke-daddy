#!/usr/bin/env python3
"""
Demo script for the golden path:
- Register a user
- Create a profile with blocked apps
- Start a blocking session
- Show restricted-apps
- Wait for you to try opening a blocked app on device and send SMS
- Simulate MCP by calling /admin/unblock-app for one bundle
- Show restricted-apps again
- Optionally end the blocking session

Run: python scripts/demo_golden_path.py
Server: expects http://localhost:8000
"""

import os
import sys
import time
import json
import requests

BASE = os.environ.get("POKEDADDY_BASE", "https://poke-daddy.vercel.app")


def main():
    # 1) Register user
    r = requests.post(
        f"{BASE}/auth/register",
        json={
            "apple_user_id": "demo_apple_user",
            "email": "demo@example.com",
            "name": "Demo User",
        },
    )
    r.raise_for_status()
    token = r.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("[demo] registered user, got token")

    # 2) Create profile (or reuse default) with two apps
    apps = ["com.instagram.app", "com.twitter.twitter"]
    r = requests.post(
        f"{BASE}/profiles",
        headers=headers,
        json={
            "name": "Default",
            "icon": "bell.slash",
            "restricted_apps": apps,
            "restricted_categories": [],
            "is_default": True,
        },
    )
    r.raise_for_status()
    profile = r.json()
    profile_id = profile["id"]
    print(f"[demo] profile created id={profile_id}")

    # 3) Start blocking
    r = requests.post(
        f"{BASE}/blocking/toggle",
        headers=headers,
        json={"profile_id": profile_id, "action": "start"},
    )
    r.raise_for_status()
    print("[demo] blocking started")

    # 4) Confirm restricted apps
    r = requests.get(f"{BASE}/profiles/{profile_id}/restricted-apps", headers=headers)
    r.raise_for_status()
    print("[demo] restricted apps:", r.json())

    input("\nNow, on the iPhone: open a blocked app → tap 'Debate Poke' → send SMS.\nPress Enter here to simulate MCP unblocking Instagram... ")

    # 5) Simulate MCP unblocking Instagram
    r_me = requests.get(f"{BASE}/users/me", headers=headers)
    r_me.raise_for_status()
    user_id = r_me.json()["id"]

    r = requests.post(
        f"{BASE}/admin/unblock-app",
        params={
            "user_id": user_id,
            "profile_id": profile_id,
            "app_bundle_id": "com.instagram.app",
        },
    )
    r.raise_for_status()
    print("[demo] unblocked Instagram:", r.json())

    # 6) Show restricted apps again
    r = requests.get(f"{BASE}/profiles/{profile_id}/restricted-apps", headers=headers)
    r.raise_for_status()
    print("[demo] restricted apps after unblock:", r.json())

    end = input("\nEnd blocking session now? [y/N]: ").strip().lower()
    if end == "y":
        r = requests.post(
            f"{BASE}/admin/end-blocking",
            params={"user_id": user_id, "profile_id": profile_id},
        )
        r.raise_for_status()
        print("[demo] ended blocking session")

        r = requests.get(f"{BASE}/profiles/{profile_id}/restricted-apps", headers=headers)
        r.raise_for_status()
        print("[demo] restricted apps after ending session:", r.json())


if __name__ == "__main__":
    try:
        main()
    except requests.HTTPError as e:
        print("HTTP error:", e.response.status_code, e.response.text)
        sys.exit(1)
    except Exception as e:
        print("Error:", str(e))
        sys.exit(1)
