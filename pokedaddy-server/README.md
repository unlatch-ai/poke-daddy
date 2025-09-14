# PokeDaddy Server

A FastAPI server that provides centralized control over app restrictions for the PokeDaddy iOS app. This server manages user profiles, restricted apps, and blocking sessions, giving programmatic control over which apps users can access.

## Features

- **User Authentication**: JWT-based authentication with Apple Sign In integration
- **Profile Management**: Create and manage multiple restriction profiles
- **App Restriction Control**: Server-side control over which apps are blocked
- **Blocking Sessions**: Track when users are in blocking mode
- **RESTful API**: Clean API endpoints for iOS app integration

## Setup Instructions

### Prerequisites

- Python 3.8+
- pip (Python package manager)

### Installation

1. **Navigate to the server directory:**
   ```bash
   cd pokedaddy-server
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Start the server:**
   ```bash
   python main.py
   ```

The server will start on `http://localhost:8000`

### Running Tests (Golden Path)

We include a pytest that exercises the end-to-end blocking flow (register → create profile → start blocking → check restricted apps → admin unblock → admin end-blocking).

1. Install test deps:
   ```bash
   pip install -r requirements.txt pytest
   ```
2. Run tests (uses a temporary SQLite DB via `POSTGRES_URL=sqlite:///./test_golden.db`):
   ```bash
   pytest -q
   ```
   You should see the golden path test passing.

### Configuration

- **Database**: Uses SQLite database (`pokedaddy.db`) created automatically
- **Secret Key**: Set `SECRET_KEY` environment variable for production
- **CORS**: Currently allows all origins for development

## API Endpoints

### Authentication
- `POST /auth/register` - Register/authenticate user with Apple ID
- `GET /users/me` - Get current user information

### Profile Management
- `GET /profiles` - Get user's profiles
- `POST /profiles` - Create new profile
- `PUT /profiles/{profile_id}` - Update profile
- `DELETE /profiles/{profile_id}` - Delete profile

### Blocking Control
- `POST /blocking/toggle` - Start/stop blocking session
- `GET /blocking/status` - Get current blocking status
- `GET /profiles/{profile_id}/restricted-apps` - Get restricted apps (key endpoint)

### Key Endpoint: Restricted Apps

The `/profiles/{profile_id}/restricted-apps` endpoint is crucial for app access control:

- Returns list of restricted app bundle IDs when user is in blocking mode
- Returns empty list when not blocking
- iOS app should check this endpoint to determine which apps to block

## Database Schema

### Users Table
- `id`: Unique user identifier
- `email`: User email from Apple Sign In
- `name`: User display name
- `apple_user_id`: Apple ID identifier
- `created_at`: Account creation timestamp
- `is_active`: Account status

### User Profiles Table
- `id`: Unique profile identifier
- `user_id`: Reference to user
- `name`: Profile name
- `icon`: Profile icon identifier
- `restricted_apps`: JSON array of app bundle IDs
- `restricted_categories`: JSON array of category identifiers
- `is_default`: Whether this is the default profile

### Blocking Sessions Table
- `id`: Unique session identifier
- `user_id`: Reference to user
- `profile_id`: Reference to active profile
- `is_active`: Whether session is currently active
- `started_at`: Session start time
- `ended_at`: Session end time (if completed)

## iOS Integration

The iOS app integrates with this server through the `APIService` class:

1. **Authentication**: App authenticates with server using Apple ID
2. **Profile Sync**: Profiles are managed server-side
3. **Blocking Control**: NFC tag interactions trigger server API calls
4. **App Restrictions**: Server determines which apps to block

### Key iOS Changes Made

- **APIService.swift**: New service for server communication
- **AuthenticationManager**: Updated to authenticate with server
- **ProfileManager**: Added server profile management
- **AppBlocker**: Updated to use server-controlled restrictions
- **PokeDaddyView**: Modified to use server-based blocking

## Security Considerations

- JWT tokens for authentication
- Apple Sign In integration for secure user identification
- Server-side validation of all requests
- CORS configuration for production deployment

## Development vs Production

### Development
- Server runs on `localhost:8000`
- CORS allows all origins
- Uses default secret key

### Production Recommendations
- Set proper `SECRET_KEY` environment variable
- Configure CORS for specific domains
- Use HTTPS
- Deploy with proper database (PostgreSQL recommended)
- Set up proper logging and monitoring

## API Testing

You can test the API using the automatic documentation at:
`http://localhost:8000/docs`

This provides an interactive Swagger UI for testing all endpoints.

## Troubleshooting

### Common Issues

1. **Import Errors**: Ensure all dependencies are installed with `pip install -r requirements.txt`
2. **Port Conflicts**: Change port in `main.py` if 8000 is in use
3. **Database Issues**: Delete `pokedaddy.db` to reset database
4. **iOS Connection**: Ensure server is running and iOS app points to correct URL

### Logs

Server logs are printed to console. Look for:
- `INFO: Started server process` - Server started successfully
- `INFO: Uvicorn running on http://0.0.0.0:8000` - Server accessible
- Authentication and API request logs for debugging

## Next Steps

1. **Bundle ID Mapping**: Implement proper conversion from app bundle IDs to ApplicationTokens in iOS
2. **Enhanced Security**: Add rate limiting and request validation
3. **Admin Interface**: Create web interface for managing users and profiles
4. **Analytics**: Add usage tracking and reporting
5. **Deployment**: Set up production deployment with proper infrastructure
