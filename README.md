# 🎯 PokeDaddy

*Making Poke the accountability partner that puts you back in control of your screen time.*

**Built for the Poke Hackathon 2024** by Kevin Fang and Olsen Budanur.

## 🌟 What is PokeDaddy?

PokeDaddy is a iOS app in the style of similar app blockers like Opal or OneSec that tackles smartphone addiction through using Screen Time in iOS Family Controls. Unlike traditional screen time apps that you can easily bypass, PokeDaddy creates a one-way blocking system where only an AI agent can grant you access to restricted apps.

### How it works:
1. **You start a blocking session** - Choose which apps to restrict and hit the big red button
2. **Apps become inaccessible** - Apple's Family Controls framework enforces the restrictions
3. **AI becomes your gatekeeper** - Want to check Instagram? You'll need to convince Poke's AI agent first
4. **Justify your access** - The AI agent evaluates your reason and decides whether to unblock the app

## 🏗️ Architecture

PokeDaddy consists of three main components:

### 📱 iOS App (`/pokedaddy/`)
- **SwiftUI + Family Controls** - Modern iOS interface with Apple's restriction framework
- **Apple Sign In** - Secure authentication
- **One-way blocking** - Users can start sessions but can't stop them
- **Real-time sync** - Communicates with server for dynamic app control

### 🖥️ FastAPI Server (`/pokedaddy-server/`)
- **Python + PostgreSQL** - Robust backend with Supabase database
- **JWT Authentication** - Secure API access
- **Admin endpoints** - Server-controlled app unblocking
- **Session management** - Tracks active blocking sessions

### 🤖 MCP Integration (`/pokedaddy-mcp-vercel/`)
- **Model Context Protocol** - Enables AI agents to control app restrictions
- **Poke.com integration** - Works with Poke's conversational AI
- **Serverless deployment** - Hosted on Vercel for reliability

## 🎨 Design Philosophy

**"Digital Glass" Aesthetic** - Clean, modern interface with gradient backgrounds and frosted glass surfaces that don't distract from the core functionality.

## 🚀 Getting Started

See [CLAUDE.md](./CLAUDE.md) for detailed setup instructions and development commands.
