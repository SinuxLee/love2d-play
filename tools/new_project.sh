#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="${1:?Usage: new_project.sh <game_name>}"
GAME_DIR="$REPO_ROOT/games/$GAME"

if [ -d "$GAME_DIR" ]; then
    echo "Error: game '$GAME' already exists at $GAME_DIR"
    exit 1
fi

mkdir -p "$GAME_DIR"/{src,assets/{sprites,audio,maps,fonts},.vscode}

cat > "$GAME_DIR/conf.lua" << 'CONF'
do
    local source = love.filesystem.getSource()
    local root = source .. "/../../"
    package.path = source .. "/src/?.lua;"
        .. source .. "/src/?/init.lua;"
        .. root .. "vendor/?.lua;"
        .. root .. "vendor/?/init.lua;"
        .. root .. "shared/?.lua;"
        .. root .. "shared/?/init.lua;"
        .. package.path
end

function love.conf(t)
    t.version = "11.4"
    t.window.title = "GAME_TITLE"
    t.window.width = 800
    t.window.height = 600
end
CONF
sed -i.bak "s/GAME_TITLE/$GAME/" "$GAME_DIR/conf.lua" && rm -f "$GAME_DIR/conf.lua.bak"

cat > "$GAME_DIR/main.lua" << 'MAIN'
function love.load()
end

function love.update(dt)
end

function love.draw()
    love.graphics.print("Hello from " .. love.window.getTitle(), 10, 10)
end
MAIN

cat > "$GAME_DIR/.vscode/launch.json" << 'LAUNCH'
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lua-local",
            "request": "launch",
            "name": "Debug",
            "program": {
                "command": "love"
            },
            "args": [
                "${workspaceFolder}"
            ],
            "env": {
                "LOCAL_LUA_DEBUGGER_VSCODE": "1"
            }
        }
    ]
}
LAUNCH

cat > "$GAME_DIR/.vscode/tasks.json" << 'TASKS'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Run Love2D",
            "type": "shell",
            "osx": {
                "command": "/Applications/love.app/Contents/MacOS/love"
            },
            "linux": {
                "command": "love"
            },
            "windows": {
                "command": "D:/Program Files/LOVE/love.exe"
            },
            "args": [
                "${workspaceFolder}"
            ],
            "problemMatcher": [],
            "group": {
                "kind": "build",
                "isDefault": true
            }
        }
    ]
}
TASKS

echo "Created new game project: $GAME_DIR"
echo "Add it to love2d.code-workspace to use in VS Code."
