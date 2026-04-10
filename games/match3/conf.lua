function love.conf(t)
    -- Identity: save dir name (e.g. AppData/LOVE/Match3 on Windows). Keep stable for upgrades.
    t.identity = "Match3"
    -- Lock LÖVE version so the game runs on the same runtime you tested with.
    t.version = "11.5"
    -- Console: dynamic. Default: on when running via love.exe (dev), off when fused/packaged.
    -- Override: LOVE_CONSOLE=1 or LOVE_CONSOLE=0; or run with --console (e.g. "Match3.exe --console").
    do
        local function has_arg(name)
            if not arg then return false end
            for i = 1, math.max(0, #arg) do if arg[i] == name then return true end end
            return false
        end
        local exe = (arg and (arg[-2] or arg[0] or "")) or ""
        local dev = exe:match("[Ll]ove%.exe$")
        local env = os.getenv("LOVE_CONSOLE")
        local force_on = (env == "1" or env == "true" or has_arg("--console"))
        local force_off = (env == "0" or env == "false")
        t.console = force_on or (not force_off and dev)
    end

    -- Gamma-correct rendering when supported (better colors on modern displays).
    t.gammacorrect = true

    -- Window
    t.window.title = "Match-3"
    t.window.width = 640
    t.window.height = 720
    t.window.vsync = 1
    t.window.resizable = false   -- no resize, no maximize button
    t.window.minwidth = 400
    t.window.minheight = 500
    -- Sharper on Retina/high-DPI; usedpiscale keeps coordinate scale consistent.
    t.window.highdpi = true
    t.window.usedpiscale = true

    -- Disable unused modules: faster startup, less memory (best practice for release).
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.touch = false
    t.modules.video = false
    t.modules.thread = false
end
