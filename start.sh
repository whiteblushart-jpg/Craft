#!/bin/bash
# Craft Launcher for MSYS2 UCRT64
# Usage: ./start.sh [server|client|both]

set -e

cd "$(dirname "$0")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Craft Launcher ===${NC}"

# Find Python command first
PYTHON=""
if command -v python3 &>/dev/null; then
    PYTHON="python3"
elif command -v python &>/dev/null; then
    PYTHON="python"
else
    echo -e "${RED}Error: Python not found. Install it with: pacman -S python${NC}"
    exit 1
fi

# Build world DLL if missing
if [ ! -f "world.dll" ] && [ ! -f "world.so" ]; then
    echo -e "${YELLOW}Building world DLL...${NC}"
    gcc -std=c99 -O3 -fPIC -shared -o world.dll \
        -I src -I deps/noise deps/noise/noise.c src/world.c
    echo -e "${GREEN}World DLL built.${NC}"
fi

# Check for requests module
$PYTHON -c "import requests" 2>/dev/null || {
    echo -e "${YELLOW}requests module not found. Install it with:${NC}"
    echo -e "${YELLOW}  pacman -S python-requests${NC}"
    exit 1
}

# Build client if missing
if [ ! -f "craft.exe" ] && [ ! -f "craft" ]; then
    echo -e "${YELLOW}Building client...${NC}"
    rm -rf build
    cmake -B build -S .
    cmake --build build
    echo -e "${GREEN}Client built.${NC}"
fi

MODE=${1:-both}

case "$MODE" in
    server)
        echo -e "${GREEN}Starting server on 0.0.0.0:4080...${NC}"
        $PYTHON server.py
        ;;
    client)
        echo -e "${GREEN}Starting client...${NC}"
        ./build/craft 127.0.0.1 4080
        ;;
    both)
        echo -e "${GREEN}Starting server on 0.0.0.0:4080...${NC}"
        $PYTHON server.py &
        SERVER_PID=$!
        sleep 2
        echo -e "${GREEN}Starting client...${NC}"
        ./build/craft 127.0.0.1 4080
        kill $SERVER_PID 2>/dev/null
        ;;
    *)
        echo "Usage: ./start.sh [server|client|both]"
        exit 1
        ;;
esac
