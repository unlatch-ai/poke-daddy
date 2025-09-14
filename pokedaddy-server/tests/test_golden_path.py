import os
import json
import pathlib

from fastapi.testclient import TestClient


def setup_module(module):
    # Use a fresh SQLite DB for tests
    db_path = pathlib.Path("test_golden.db")
    if db_path.exists():
        db_path.unlink()
    os.environ["POSTGRES_URL"] = f"sqlite:///./{db_path.name}"
    # Ensure SECRET_KEY is stable for JWT
    os.environ.setdefault("SECRET_KEY", "test-secret")


def test_golden_path_end_to_end():
    # Import after env vars are set so the engine binds to SQLite
    from pokedaddy-server.main import app, SessionLocal, UserProfile

    client = TestClient(app)

    # 1) Register/authenticate user
    r = client.post(
        "/auth/register",
        json={
            "apple_user_id": "test_apple_id_1",
            "email": "tester@example.com",
            "name": "Tester",
        },
    )
    assert r.status_code == 200, r.text
    token = r.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2) Create a profile with two restricted apps
    restricted_apps = [
        "com.instagram.app",
        "com.twitter.twitter",
    ]
    r = client.post(
        "/profiles",
        headers=headers,
        json={
            "name": "Default",
            "icon": "bell.slash",
            "restricted_apps": restricted_apps,
            "restricted_categories": [],
            "is_default": True,
        },
    )
    assert r.status_code == 200, r.text
    profile = r.json()
    profile_id = profile["id"]

    # 3) Start blocking (user-initiated)
    r = client.post(
        "/blocking/toggle",
        headers=headers,
        json={"profile_id": profile_id, "action": "start"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["is_blocking"] is True

    # 4) While active, restricted-apps returns the list
    r = client.get(f"/profiles/{profile_id}/restricted-apps", headers=headers)
    assert r.status_code == 200, r.text
    payload = r.json()
    assert set(payload["restricted_apps"]) == set(restricted_apps)
    assert payload["restricted_categories"] == []

    # 5) Faux MCP unblocks one app via admin endpoint
    # Lookup user_id from token by calling users/me
    r_me = client.get("/users/me", headers=headers)
    assert r_me.status_code == 200
    user_id = r_me.json()["id"]

    to_unblock = "com.instagram.app"
    r = client.post(
        "/admin/unblock-app",
        params={
            "user_id": user_id,
            "profile_id": profile_id,
            "app_bundle_id": to_unblock,
        },
    )
    assert r.status_code == 200, r.text
    # 6) Restricted apps reflects removal
    r = client.get(f"/profiles/{profile_id}/restricted-apps", headers=headers)
    assert r.status_code == 200
    payload = r.json()
    assert set(payload["restricted_apps"]) == {"com.twitter.twitter"}

    # 7) End blocking session via admin endpoint
    r = client.post(
        "/admin/end-blocking",
        params={"user_id": user_id, "profile_id": profile_id},
    )
    assert r.status_code == 200, r.text

    # 8) After session end, restricted-apps is empty
    r = client.get(f"/profiles/{profile_id}/restricted-apps", headers=headers)
    assert r.status_code == 200
    payload = r.json()
    assert payload["restricted_apps"] == []
    assert payload["restricted_categories"] == []

