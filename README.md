# PokeDaddy

An open-source iOS app for minimalist smartphone use with server-controlled app restrictions. PokeDaddy helps users reduce smartphone distractions by using NFC tags to toggle app blocking, with centralized control through a FastAPI server.

## 🎯 Purpose

PokeDaddy provides a physical, intentional way to manage smartphone usage. Users tap their phone on NFC tags to enter "blocking mode" where selected apps become inaccessible. The server maintains control over which apps are restricted, ensuring only programmatic access can restore functionality.

## ✨ Key Features

### iOS App
- **One-Way Blocking**: Users can start app restrictions with a single tap
- **Server-Controlled Unblocking**: Only the server can end blocking sessions or unblock individual apps
- **Apple Sign In Authentication**: Secure user authentication before app access
- **Visual Interface**: Clean UI with red/green icons indicating blocking state
- **Profile Management**: Multiple restriction profiles with different app configurations
- **Server Integration**: Communicates with FastAPI server for centralized control

### FastAPI Server
- **Centralized Control**: Server determines which apps are blocked and when
- **User Management**: JWT-based authentication with Apple ID integration
- **Profile API**: Create, update, and manage restriction profiles
- **Blocking Sessions**: Track when users are in blocking mode
- **Individual App Control**: Server can unblock specific apps or end entire sessions
- **Admin Endpoints**: Server-only endpoints for programmatic control

## 🛠 Tech Stack

### iOS App
- **Swift/SwiftUI** - Native iOS development
- **Family Controls & ManagedSettings** - Apple's app blocking frameworks
- **AuthenticationServices** - Apple Sign In integration

### Server
- **FastAPI** - Modern Python web framework
- **SQLAlchemy** - Database ORM with SQLite
- **JWT Authentication** - Secure token-based auth
- **Python-JOSE** - JWT token handling

## 🚀 Quick Start

### Server Setup

1. **Navigate to server directory:**
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
   Server runs on `http://localhost:8000`

### iOS App Setup

1. **Open Xcode project:**
   ```bash
   open pokedaddy/PokeDaddy.xcodeproj
   ```

2. **Build and run** on iOS device (NFC requires physical device)

3. **Sign in with Apple ID** when prompted

4. **Create NFC tags** using the + button in the app

## 📱 How It Works

1. **Authentication**: User signs in with Apple ID (syncs with server)
2. **Profile Setup**: Create profiles specifying which apps to block
3. **Start Blocking**: User taps the button to start app restrictions
4. **Server Control**: Only the server can end blocking sessions or unblock individual apps
5. **Programmatic Access**: External systems can control app access via server API

## 🔧 Architecture

### Core Components

**iOS App:**
- `APIService` - Server communication
- `AppBlocker` - Manages app restrictions using Apple's frameworks
- `ProfileManager` - Manages user profiles (local + server sync)
- `AuthenticationManager` - Apple Sign In integration

**Server:**
- User authentication and management
- Profile CRUD operations
- Blocking session control
- Restricted apps endpoint (key for access control)

### Key API Endpoints

- `POST /auth/register` - User authentication
- `GET /profiles` - Get user profiles
- `POST /blocking/toggle` - Start blocking sessions (users can only start)
- `GET /profiles/{id}/restricted-apps` - Get restricted apps (returns apps only when blocking is active)
- `POST /admin/unblock-app` - Server-only endpoint to unblock individual apps
- `POST /admin/end-blocking` - Server-only endpoint to end blocking sessions

## 🔒 Security & Control

- **Server-Side Authority**: Only the server can end blocking or unblock apps
- **One-Way User Control**: Users can start blocking but cannot stop it themselves
- **JWT Authentication**: Secure token-based communication
- **Apple Sign In**: Trusted identity provider
- **Session-Based Blocking**: Apps are only restricted during active blocking sessions
- **Admin API**: Server endpoints for external system integration

## 📄 License

Apache 2.0 License - Open source and free to use

## 🤝 Contributing

This project is open source and welcomes contributions. Feel free to:
- Report bugs and issues
- Suggest new features
- Submit pull requests
- Improve documentation

## 🙏 Acknowledgments

Inspired by the commercial Brick app. PokeDaddy provides an open-source alternative for users who want to understand and customize their digital wellness tools.

---

**Note**: This app works on both physical iOS devices and the simulator. No NFC hardware required.
