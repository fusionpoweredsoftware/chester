
#!/bin/bash
# deploy_commands.sh
# Creates simple shell scripts for chess API commands
rm -rf simple-chess
CMD_DIR="commands"
SERVER_URL="http://localhost:8001"

mkdir -p "$CMD_DIR"

# Move command (takes two args: from to)
cat > "$CMD_DIR/move.sh" << 'EOF'
#!/bin/bash
if [ $# -ne 2 ]; then
  echo "Usage: ./move.sh e2 e4"
  exit 1
fi
curl -s -X POST http://localhost:8001/move \
     -H "Content-Type: application/json" \
     -d "{\"from\":\"$1\",\"to\":\"$2\"}"
echo
EOF
chmod +x "$CMD_DIR/move.sh"

# Undo
cat > "$CMD_DIR/undo.sh" << 'EOF'
#!/bin/bash
curl -s -X POST http://localhost:8001/undo
echo
EOF
chmod +x "$CMD_DIR/undo.sh"

# New Game
cat > "$CMD_DIR/new.sh" << 'EOF'
#!/bin/bash
curl -s -X POST http://localhost:8001/new
echo
EOF
chmod +x "$CMD_DIR/new.sh"

# Computer Play
cat > "$CMD_DIR/computer.sh" << 'EOF'
#!/bin/bash
curl -s -X POST http://localhost:8001/computer
echo
EOF
chmod +x "$CMD_DIR/computer.sh"

# State (current board FEN)
cat > "$CMD_DIR/state.sh" << 'EOF'
#!/bin/bash
curl -s http://localhost:8001/state | jq .
EOF
chmod +x "$CMD_DIR/state.sh"

# History (move list)
cat > "$CMD_DIR/history.sh" << 'EOF'
#!/bin/bash
curl -s http://localhost:8001/history | jq .
EOF
chmod +x "$CMD_DIR/history.sh"

#!/bin/bash
rm -rf simple-chess
echo "Setting up Simple Chess UI with API control..."

# Create project directory
mkdir -p simple-chess
cd simple-chess

# Init npm and install dependencies
npm init -y > /dev/null 2>&1
npm install stockfish express ws > /dev/null 2>&1

# Download chess.js
curl -L https://cdnjs.cloudflare.com/ajax/libs/chess.js/0.12.1/chess.min.js -o chess.js

# Download chessboard.js + CSS
curl -L https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/chessboard-1.0.0.min.js -o chessboard.js
curl -L https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/chessboard-1.0.0.min.css -o chessboard.css

# Download piece images
mkdir -p img/chesspieces/wikipedia
cd img/chesspieces/wikipedia
pieces=("bB" "bK" "bN" "bP" "bQ" "bR" "wB" "wK" "wN" "wP" "wQ" "wR")
for piece in "${pieces[@]}"; do
    curl -L "https://chessboardjs.com/img/chesspieces/wikipedia/${piece}.png" -o "${piece}.png"
done
cd ../../..

# Download jQuery
curl -L https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js -o jquery.js

# Copy Stockfish engine from npm
cp node_modules/stockfish/src/stockfish-nnue-16-single.js stockfish.js
cp node_modules/stockfish/src/*.wasm . 2>/dev/null || true

# Copy your existing HTML and patch it
cp ../chess.html index.html
# Remove final </html> if present so we can append
sed -i '' -e '$ s_</html>__' index.html 2>/dev/null || sed -i '$ s_</html>__' index.html
cat >> index.html << 'EOF'
<script>
// WebSocket listener for API bridge
const socket = new WebSocket(`ws://${window.location.host}`);
socket.addEventListener('message', event => {
    try {
        const data = JSON.parse(event.data);
        if (data.action === 'move') window.chessAPI.move(data.from, data.to);
        if (data.action === 'undo') window.chessAPI.undo();
        if (data.action === 'new') window.chessAPI.newGame();
        if (data.action === 'computer') window.chessAPI.computerPlay();
    if (data.action === 'getState') {
        socket.send(JSON.stringify({
            action: 'state',
            fen: window.chessAPI.getStatus()
        }));
    }
    if (data.action === 'getHistory') {
        socket.send(JSON.stringify({
            action: 'history',
            moves: window.chessAPI.getMoves()
        }));
    }
    } catch (err) {
        console.error('Invalid WS message', err);
    }
});
</script>
</html>
EOF

# Create server.mjs
cat > server.mjs << 'EOF'
import express from 'express';
import { WebSocketServer } from 'ws';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = 8001;

app.use(express.static(__dirname));
app.use(express.json());

let browserClient = null;
function sendAction(action, payload = {}) {
    if (!browserClient) return false;
    browserClient.send(JSON.stringify({ action, ...payload }));
    return true;
}

app.post('/move', (req, res) => {
    const { from, to } = req.body;
    if (sendAction('move', { from, to })) res.json({ status: 'sent', from, to });
    else res.status(400).json({ error: 'No browser connected' });
});

app.post('/undo', (req, res) => {
    if (sendAction('undo')) res.json({ status: 'sent', action: 'undo' });
    else res.status(400).json({ error: 'No browser connected' });
});

app.post('/new', (req, res) => {
    if (sendAction('new')) res.json({ status: 'sent', action: 'new' });
    else res.status(400).json({ error: 'No browser connected' });
});

app.post('/computer', (req, res) => {
    if (sendAction('computer')) res.json({ status: 'sent', action: 'computer' });
    else res.status(400).json({ error: 'No browser connected' });
});

app.get('/state', (req, res) => {
    if (!browserClient) return res.status(400).json({ error: 'No browser connected' });
    let responded = false;
    const handler = (msg) => {
        try {
            const data = JSON.parse(msg);
            if (data.action === 'state') {
                responded = true;
                res.json(data);
                browserClient.off('message', handler);
            }
        } catch {}
    };
    browserClient.on('message', handler);
    sendAction('getState');
    setTimeout(() => {
        if (!responded) {
            browserClient.off('message', handler);
            res.status(504).json({ error: 'Timed out waiting for board state' });
        }
    }, 1000);
});

app.get('/history', (req, res) => {
    if (!browserClient) return res.status(400).json({ error: 'No browser connected' });
    let responded = false;
    const handler = (msg) => {
        try {
            const data = JSON.parse(msg);
            if (data.action === 'history') {
                responded = true;
                res.json(data);
                browserClient.off('message', handler);
            }
        } catch {}
    };
    browserClient.on('message', handler);
    sendAction('getHistory');
    setTimeout(() => {
        if (!responded) {
            browserClient.off('message', handler);
            res.status(504).json({ error: 'Timed out waiting for move history' });
        }
    }, 1000);
});

const server = app.listen(PORT, () => console.log(`Server running at http://localhost:${PORT}`));
const wss = new WebSocketServer({ server });

wss.on('connection', ws => {
    console.log('Browser connected');
    browserClient = ws;
    ws.on('close', () => {
        if (browserClient === ws) browserClient = null;
    });
});
EOF

echo "Setup complete!"
echo ""
echo "Run: cd simple-chess && node server.mjs"
echo "Open: http://localhost:8001"
echo "Examples:"
echo "curl -X POST http://localhost:8001/move -H 'Content-Type: application/json' -d '{\"from\":\"e2\",\"to\":\"e4\"}'"
echo "curl -X POST http://localhost:8001/computer"

echo "Command scripts created in $CMD_DIR/"
echo "Examples:"
echo "  $CMD_DIR/move.sh e2 e4"
echo "  $CMD_DIR/undo.sh"
echo "  $CMD_DIR/new.sh"
echo "  $CMD_DIR/computer.sh"
echo "  $CMD_DIR/state.sh"
echo "  $CMD_DIR/history.sh"

node server.mjs
