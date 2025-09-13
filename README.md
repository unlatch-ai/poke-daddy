# PokeDaddy

An open-source iOS app for minimalist smartphone use with server-controlled app restrictions. PokeDaddy helps users reduce smartphone distractions by using NFC tags to toggle app blocking, with centralized control through a FastAPI server.

## 🎯 Purpose

PokeDaddy provides a physical, intentional way to manage smartphone usage. Users tap their phone on NFC tags to enter "blocking mode" where selected apps become inaccessible. The server maintains control over which apps are restricted, ensuring only programmatic access can restore functionality.

## ✨ Key Features

### iOS App
- **NFC-Controlled Blocking**: Tap NFC tags containing "POKEDADDY-IS-GREAT" to toggle app restrictions
- **Apple Sign In Authentication**: Secure user authentication before app access
- **Visual Interface**: Clean UI with red/green icons indicating blocking state
- **Profile Management**: Multiple restriction profiles with different app configurations
- **Server Integration**: Communicates with FastAPI server for centralized control

### FastAPI Server
- **Centralized Control**: Server determines which apps are blocked and when
- **User Management**: JWT-based authentication with Apple ID integration
- **Profile API**: Create, update, and manage restriction profiles
- **Blocking Sessions**: Track when users are in blocking mode
- **Programmatic Access**: Only the server can grant app access by ending blocking sessions

## 🛠 Tech Stack

### iOS App
- **Swift/SwiftUI** - Native iOS development
- **Family Controls & ManagedSettings** - Apple's app blocking frameworks
- **CoreNFC** - NFC tag reading and writing
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
3. **NFC Tag Creation**: Write "POKEDADDY-IS-GREAT" to NFC tags using the app
4. **Usage**: Tap phone on NFC tag to toggle between blocking/non-blocking states
5. **Server Control**: Server determines which apps are restricted based on active sessions

## 🔧 Architecture

### Core Components

**iOS App:**
- `APIService` - Server communication
- `AppBlocker` - Manages app restrictions using Apple's frameworks
- `NFCReader` - Handles NFC tag operations
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
- `POST /blocking/toggle` - Start/stop blocking sessions
- `GET /profiles/{id}/restricted-apps` - Get restricted apps (returns apps only when blocking is active)

## 🔒 Security & Control

- **Server-Side Authority**: Only the server can determine app access
- **JWT Authentication**: Secure token-based communication
- **Apple Sign In**: Trusted identity provider
- **Session-Based Blocking**: Apps are only restricted during active blocking sessions

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

**Note**: This app requires a physical iOS device with NFC capabilities. The simulator provides mock authentication for development purposes.
