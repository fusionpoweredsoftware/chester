# Chester - Chess API & Testing Interface

**Chester** is a **web-based chess interface** combined with a **REST API** that lets you play against the powerful **Stockfish AI engine** through both visual UI and command-line interactions. Perfect for chess testing, automation, and human-vs-computer play.

## Quick Start

Chester provides both a **visual chess board** in your browser and **command-line tools** for programmatic chess interactions. The setup script handles all dependencies, downloads chess assets, and creates ready-to-use command scripts.

```bash
# Run the setup script
chmod +x chester.sh && ./chester.sh
```

The script automatically starts the server at `http://localhost:8001` - open this URL to see the chess board interface with **drag-and-drop piece movement**, **configurable Stockfish engine settings** (depth, time limits, skill level, hash size), and **complete move history tracking**.

## API Endpoints

Chester exposes a **clean REST API** for programmatic chess control:

**POST /move** - Execute a chess move using algebraic notation (e.g., `{"from":"e2","to":"e4"}`)  
**POST /computer** - Trigger Stockfish to calculate and play its best move  
**POST /undo** - Undo the last move played  
**POST /new** - Start a fresh chess game  
**GET /state** - Retrieve current board position in FEN notation  
**GET /history** - Get complete move history as JSON array  

## Command Line Interface

Chester generates **executable shell scripts** in the `commands/` directory for quick chess operations:

```bash
# Make moves
./commands/move.sh e2 e4
./commands/move.sh g1 f3

# Let computer play
./commands/computer.sh

# Game control
./commands/undo.sh
./commands/new.sh

# Check status
./commands/state.sh     # Current position
./commands/history.sh   # Move list
```

## Engine Configuration

The web interface provides **real-time Stockfish tuning** with sliders for **search depth** (1-20 plies), **thinking time** (1-30 seconds), **skill level** (0-20, where 20 is maximum strength), and **hash table size** (16MB-1GB). Toggle between **time-based** and **depth-based** search modes depending on whether you want consistent timing or thorough analysis.

## Technical Architecture

Chester uses **WebSocket communication** between the browser chess board and the Node.js server, enabling **instant synchronization** between UI interactions and API commands. The system downloads **chess.js** for game logic, **chessboard.js** for visualization, **Stockfish WASM** for AI calculations, and **Wikipedia piece images** for a clean aesthetic. All dependencies are automatically managed through the setup script.

## Use Cases

Chester excels at **automated chess testing** (simulate games, test opening variations, benchmark AI performance), **educational chess programming** (learn chess APIs, experiment with position analysis, study Stockfish evaluation), **tournament preparation** (practice against configurable AI strength, analyze specific positions, train tactical patterns), and **chess software development** (prototype chess applications, test move validation, integrate chess AI into larger systems).

## Requirements

Chester requires **Node.js 16+** and **bash shell** for the setup script. The system works on **macOS**, **Linux**, and **Windows WSL**, automatically handling **npm dependencies**, **asset downloads**, and **WebSocket server setup**. No additional chess software installation needed.
