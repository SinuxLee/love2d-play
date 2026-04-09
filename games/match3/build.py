#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LÖVE cross-platform pack script.
Usage: python build.py [options]
Requires LÖVE (Windows/Linux/macOS) in PATH or --love-path / LOVE_ROOT.
All build artifacts go into a single output directory (default: release/).
"""

import argparse
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path


def find_love_in_path(love_exe_name):
    """Find LÖVE executable directory from PATH (or platform equivalent)."""
    names = ["love", love_exe_name] if love_exe_name != "love" else ["love"]
    for name in names:
        exe = shutil.which(name)
        if exe:
            p = Path(exe).resolve()
            if p.is_file():
                return p.parent
    return None


def main():
    parser = argparse.ArgumentParser(description="Pack LÖVE game (fused exe/binary + runtime libs)")
    parser.add_argument("--game-name", default="Match3", help="Output executable name (no extension)")
    parser.add_argument("--love-path", default=os.environ.get("LOVE_ROOT", ""), help="LÖVE extract directory")
    parser.add_argument("--out-dir", default="release", help="Output directory for all artifacts")
    parser.add_argument("--zip", action="store_true", default=True, help="Create distribution zip (default)")
    parser.add_argument("--no-zip", action="store_false", dest="zip", help="Do not create zip")
    parser.add_argument("--sfx", action="store_true", help="Windows: build self-extracting exe with 7-Zip")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent
    os.chdir(project_root)

    out_dir = project_root / args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    # ---------- 1. Platform and LÖVE path ----------
    plat = sys.platform
    if plat == "win32":
        love_exe_name = "love.exe"
        lib_glob = "*.dll"
    elif plat == "darwin":
        love_exe_name = "love"
        lib_glob = "*.dylib"
    else:
        love_exe_name = "love"
        lib_glob = "*.so*"

    def find_love_dir():
        if args.love_path and Path(args.love_path).is_dir():
            p = Path(args.love_path).resolve()
            if (p / love_exe_name).exists():
                return p
        path_dir = find_love_in_path(love_exe_name)
        if path_dir and (path_dir / love_exe_name).exists():
            return path_dir
        if plat == "darwin":
            exe = shutil.which("love")
            if exe:
                resolved = Path(exe).resolve()
                if "Contents/MacOS" in str(resolved):
                    return resolved.parent
        for name in ("love-win", "love-11.4-win64", "love-11.4-win32", "love-linux64", "love", "love.app"):
            cand = project_root / name
            if cand.is_dir():
                if name == "love.app" and plat == "darwin":
                    mac_path = cand / "Contents" / "MacOS"
                    if (mac_path / "love").exists():
                        return mac_path
                elif (cand / love_exe_name).exists():
                    return cand
        for d in project_root.iterdir():
            if d.is_dir() and (d / love_exe_name).exists():
                return d
        if plat == "win32":
            for d in project_root.glob("love-*-win*"):
                if d.is_dir() and (d / love_exe_name).exists():
                    return d
        return None

    love_path = find_love_dir()

    if not love_path or not love_path.is_dir():
        print("Error: LÖVE directory not found.")
        print("Download from https://love2d.org and extract to project (e.g. love-win) or set LOVE_ROOT / --love-path")
        sys.exit(1)

    love_exe = love_path / love_exe_name
    if plat == "darwin" and not love_exe.exists():
        love_exe = love_path / "love"
    if not love_exe.exists():
        print(f"Error: {love_exe_name} not found in {love_path}")
        sys.exit(1)

    # ---------- 2. Build game.love (zip) ----------
    to_pack = []
    for f in project_root.glob("*.lua"):
        if f.name.startswith(("build.", "pack.")) or f.name == "build.py":
            continue
        to_pack.append((f.name, f))
    for subdir in ("core", "systems", "ui", "tools"):
        sub_path = project_root / subdir
        if sub_path.is_dir():
            for f in sub_path.glob("*.lua"):
                to_pack.append((f"{subdir}/{f.name}", f))

    if not to_pack:
        print("Error: No .lua files to pack")
        sys.exit(1)

    love_zip = out_dir / "game.love"
    print(f"Packing game.love ({len(to_pack)} files)...")
    if love_zip.exists():
        love_zip.unlink()
    with zipfile.ZipFile(love_zip, "w", zipfile.ZIP_DEFLATED) as z:
        for arcname, path in to_pack:
            z.write(path, arcname)
    print(f"  -> {love_zip}")

    # ---------- 3. Fuse love + game.love -> executable ----------
    if plat == "win32":
        out_exe = out_dir / f"{args.game_name}.exe"
    else:
        out_exe = out_dir / args.game_name
    with open(love_exe, "rb") as a, open(love_zip, "rb") as b:
        out_exe.write_bytes(a.read() + b.read())
    if plat != "win32":
        out_exe.chmod(0o755)
    print(f"Fused -> {out_exe.name}")
    print(f"  -> {out_exe}")

    # ---------- 4. Copy runtime libs into output dir ----------
    if plat == "darwin" and "Contents" in str(love_path):
        lib_dir = love_path.parent / "Frameworks"
        libs = list(lib_dir.glob(lib_glob)) if lib_dir.is_dir() else []
    else:
        libs = list(love_path.glob(lib_glob))
    if plat == "linux" and not libs:
        for lib_dir in [love_path.parent / "lib", Path("/usr/lib/love"), Path("/usr/lib/x86_64-linux-gnu")]:
            if lib_dir.is_dir():
                libs = list(lib_dir.glob(lib_glob))
                if libs:
                    break
    for lib in libs:
        shutil.copy2(lib, out_dir / lib.name)
    print(f"Copied executable and {len(libs)} lib(s) to {args.out_dir}")

    # ---------- 5. Single-file delivery: zip and/or SFX exe ----------
    plat_suffix = {"win32": "win", "darwin": "macos", "linux": "linux"}.get(plat, plat)
    exe_in_archive = f"{args.game_name}.exe" if plat == "win32" else args.game_name

    if args.zip:
        zip_path = out_dir / f"{args.game_name}-{plat_suffix}.zip"
        print(f"Creating {zip_path.name}...")
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
            for f in out_dir.iterdir():
                if f.suffix in (".zip", ".7z") or f.name == "game.love":
                    continue
                z.write(f, f.name)
        print(f"  -> {zip_path}")

    if getattr(args, "sfx", False) and plat == "win32":
        seven_z = shutil.which("7z") or (Path(os.environ.get("ProgramFiles", "")) / "7-Zip" / "7z.exe")
        sfx_module = None
        if seven_z and Path(seven_z).exists():
            for name in ("7zSD.sfx", "7zS.sfx"):
                cand = Path(seven_z).parent / name
                if cand.exists():
                    sfx_module = cand
                    break
        if not seven_z or not Path(seven_z).exists():
            print("SFX skipped: 7-Zip not found (install 7-Zip and use --sfx)")
        elif not sfx_module:
            print("SFX skipped: 7zSD.sfx not found (full 7-Zip install or Extra package)")
        else:
            import tempfile
            sfx_exe = out_dir / f"{args.game_name}-setup.exe"
            with tempfile.TemporaryDirectory() as tmp:
                arc_7z = Path(tmp) / "game.7z"
                config = Path(tmp) / "config.txt"
                config.write_text(
                    ";!@Install@!UTF-8!\nTitle=" + args.game_name + "\nRunProgram=\"" + exe_in_archive + "\"\n;!@InstallEnd@!\n",
                    encoding="utf-8",
                )
                subprocess.run(
                    [str(seven_z), "a", "-t7z", str(arc_7z), "*"],
                    cwd=out_dir,
                    check=True,
                    capture_output=True,
                )
                with open(sfx_exe, "wb") as out:
                    out.write(sfx_module.read_bytes())
                    out.write(config.read_bytes())
                    out.write(arc_7z.read_bytes())
                print(f"SFX package: {sfx_exe}")

    print()
    print(f"Done. All artifacts in: {out_dir.relative_to(project_root)}/")


if __name__ == "__main__":
    main()
