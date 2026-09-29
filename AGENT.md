# Craft — Codebase Agent File

## Project Overview

**Craft** is a Minecraft clone written in C (client) and Python (server), using modern OpenGL (shaders) for rendering. It supports procedural terrain generation via simplex noise, multiplayer via a Python socket server, and persistent world storage in SQLite.

- **Repository**: `C:\msys64\home\Lucas T\Craft`
- **Language**: C99 (client), Python 2 (server)
- **Build System**: CMake
- **License**: See `LICENSE.md`

---

## Directory Structure

```
Craft/
├── src/                    # C client source code
│   ├── main.c              # Entry point, game loop, rendering, input
│   ├── config.h            # Compile-time configuration constants
│   ├── world.c / world.h   # Procedural terrain generation (simplex noise)
│   ├── client.c / client.h # Network client (socket communication)
│   ├── db.c / db.h         # SQLite database layer (async writes via ring buffer)
│   ├── auth.c / auth.h     # Authentication (HTTPS POST via cURL)
│   ├── cube.c / cube.h     # 3D model generation (cubes, plants, players, spheres)
│   ├── item.c / item.h     # Block type definitions and properties
│   ├── map.c / map.h       # Hash map data structure for block storage
│   ├── matrix.c / matrix.h # 4x4 matrix math (perspective, orthographic, etc.)
│   ├── sign.c / sign.h     # Sign data structure and list management
│   ├── ring.c / ring.h     # Circular buffer for async DB writes
│   └── util.c / util.h     # Utilities (shaders, textures, text rendering)
├── deps/                   # Third-party dependencies
│   ├── glew/               # OpenGL Extension Wrangler
│   ├── glfw/               # Window and input management
│   ├── lodepng/            # PNG texture loading
│   ├── noise/              # Simplex noise library
│   ├── sqlite/             # SQLite3 (amalgamation)
│   └── tinycthread/        # Cross-platform threading
├── shaders/                # GLSL shader files
│   ├── block_vertex.glsl / block_fragment.glsl
│   ├── sky_vertex.glsl / sky_fragment.glsl
│   ├── line_vertex.glsl / line_fragment.glsl
│   └── text_vertex.glsl / text_fragment.glsl
├── textures/               # PNG texture atlases
│   ├── texture.png         # Block texture atlas
│   ├── sky.png             # Sky dome texture
│   ├── sign.png            # Sign texture
│   └── font.png            # Font atlas for text rendering
├── server.py               # Python multiplayer server
├── world.py                # Python wrapper for C world generation DLL
├── builder.py              # Script for programmatic block placement
├── CMakeLists.txt          # CMake build configuration
├── craft.db                # SQLite database (world state)
├── auth.db                 # SQLite database (authentication)
└── build/                  # Build output directory
```

---

## Architecture

### Client (C)

The client is a single-threaded render loop with worker threads for chunk generation.

#### Key Components

1. **Game State (`Model` struct in `main.c`)**
   - Global singleton `g` holds all game state
   - Chunks, players, workers, rendering parameters
   - Chunk management: create, delete, dirty tracking

2. **Chunk System**
   - World divided into 32x32 block chunks (XZ plane, Y is up)
   - Each chunk has: block map, light map, sign list, VBO buffer
   - Worker threads (4) process chunk generation asynchronously
   - Frustum culling for visibility determination
   - Render radius: 10 chunks, Create radius: 10, Delete radius: 14

3. **Rendering Pipeline**
   - Modern OpenGL with VBOs and shaders
   - Only exposed faces rendered (face culling via opaque neighbor check)
   - Ambient occlusion per-vertex
   - Light propagation via flood fill
   - Texture atlas for block textures
   - Sky dome with time-of-day texture mapping
   - Text rendering via bitmap font atlas

4. **Terrain Generation (`world.c`)**
   - Simplex noise for heightmap and biome determination
   - Deterministic: same seed produces same world
   - Features: grass, sand, stone, trees, flowers, clouds
   - Chunk padding of 1 block for seamless borders

5. **Database Layer (`db.c`)**
   - SQLite for persistent world storage
   - Async writes via ring buffer + background thread
   - Transaction commits every 5 seconds
   - Stores: blocks, lights, signs, player state, auth tokens

6. **Network Client (`client.c`)**
   - TCP socket communication with server
   - Background receive thread with queue
   - Protocol: ASCII line-based commands
   - Commands: V (version), A (auth), P (position), C (chunk), B (block), L (light), S (sign), T (talk)

7. **Authentication (`auth.c`)**
   - HTTPS POST to authentication server
   - cURL for HTTP communication
   - Identity token management

8. **Input Handling**
   - Keyboard: WASD movement, Space jump, Tab fly, etc.
   - Mouse: look, block place/destroy
   - Chat commands with `/` prefix

### Server (Python)

`server.py` implements a multi-threaded TCP server:

- **Protocol**: Same ASCII line-based protocol as client
- **World Generation**: Uses compiled C DLL (`world`) via ctypes
- **Database**: SQLite for persistent storage
- **Features**: Rate limiting, authentication, chat commands, block validation
- **Commands**: /goto, /list, /login, /logout, /offline, /online, /pq, /spawn, /help

### World Generation DLL (`world.py`)

- Wraps C `world.c` functions via ctypes
- Provides `create_chunk(p, q)` returning a dict of block positions
- Used by the Python server for terrain generation

---

## Key Data Structures

### Map (Hash Map)
```c
typedef union {
    unsigned int value;
    struct {
        unsigned char x, y, z;
        char w;
    } e;
} MapEntry;

typedef struct {
    int dx, dy, dz;          // Offset for coordinate compression
    unsigned int mask;       // Size mask (power of 2 - 1)
    unsigned int size;       // Number of entries
    MapEntry *data;          // Open-addressing hash table
} Map;
```

### Chunk
```c
typedef struct {
    Map map;                 // Block data
    Map lights;              // Light data
    SignList signs;          // Sign data
    int p, q;                // Chunk coordinates
    int faces;               // Number of visible faces
    int sign_faces;          // Number of sign faces
    int dirty;               // Needs regeneration flag
    int miny, maxy;          // Height bounds for frustum culling
    GLuint buffer;           // OpenGL VBO
    GLuint sign_buffer;      // Sign VBO
} Chunk;
```

### Ring Buffer
```c
typedef struct {
    RingEntryType type;      // BLOCK, LIGHT, KEY, COMMIT, EXIT
    int p, q, x, y, z, w, key;
} RingEntry;

typedef struct {
    unsigned int capacity;
    unsigned int start, end;
    RingEntry *data;
} Ring;
```

---

## Block Types

| ID | Name | ID | Name |
|----|------|----|------|
| 0 | Empty | 14 | Chest |
| 1 | Grass | 15 | Leaves |
| 2 | Sand | 16 | Cloud |
| 3 | Stone | 17 | Tall Grass |
| 4 | Brick | 18-23 | Flowers |
| 5 | Wood | 32-63 | Colors |
| 6 | Cement | | |
| 7 | Dirt | | |
| 8 | Plank | | |
| 9 | Snow | | |
| 10 | Glass | | |
| 11 | Cobble | | |
| 12 | Light Stone | | |
| 13 | Dark Stone | | |

---

## Build Instructions

### Prerequisites
- CMake
- GLEW, GLFW, cURL development libraries
- MinGW (Windows) or GCC (Linux/Mac)

### Build
```bash
cd Craft
cmake .
make
./craft
```

### Server
```bash
gcc -std=c99 -O3 -fPIC -shared -o world -I src -I deps/noise deps/noise/noise.c src/world.c
python server.py [HOST [PORT]]
```

---

## Potential Issues & Improvements

### Code Quality
1. **Global state**: Single global `Model` struct makes testing difficult
2. **Memory management**: Manual malloc/free throughout; potential leaks on error paths
3. **Error handling**: Many functions return void with no error reporting
4. **Python 2**: Server uses Python 2 (print statements, Queue module) — should migrate to Python 3

### Performance
1. **Chunk regeneration**: Full VBO regeneration on block change (could be incremental)
2. **Frustum culling**: Naive AABB test per chunk
3. **Database**: Ring buffer may overflow under heavy write load
4. **Light propagation**: Recursive flood fill may cause stack overflow on large open areas

### Security
1. **SQL injection**: Some queries use string formatting (server.py `cleanup()`)
2. **No encryption**: Network protocol is plaintext
3. **Authentication**: Relies on external server; no local validation
4. **Buffer overflow**: Fixed-size buffers for network messages

### Architecture
1. **Tight coupling**: Rendering, game logic, and state management all in `main.c` (1773+ lines)
2. **No modularity**: Hard to test individual components
3. **Thread safety**: Worker threads access shared state with minimal synchronization
4. **Platform-specific code**: `#ifdef _WIN32` scattered throughout

---

## File Size Summary

| File | Lines | Purpose |
|------|-------|---------|
| `src/main.c` | 1773+ | Main game loop, rendering, input |
| `src/db.c` | 543 | Database layer |
| `src/cube.c` | 384 | 3D model generation |
| `src/matrix.c` | 259 | Matrix math |
| `src/util.c` | 225 | Utilities |
| `src/client.c` | 265 | Network client |
| `src/map.c` | 114 | Hash map |
| `src/ring.c` | 109 | Circular buffer |
| `src/item.c` | 199 | Block definitions |
| `src/world.c` | 77 | Terrain generation |
| `src/sign.c` | 72 | Sign management |
| `server.py` | 675 | Multiplayer server |
| `world.py` | 48 | Python world wrapper |
| `builder.py` | 248 | Block placement script |
