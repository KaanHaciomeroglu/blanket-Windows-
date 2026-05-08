"""
Windows build script for Blanket.

Automatically finds MSYS2 (mingw64) tools.
If MSYS2 is not installed, get it from https://www.msys2.org/ and run:

  pacman -S mingw-w64-x86_64-gtk4
  pacman -S mingw-w64-x86_64-libadwaita
  pacman -S mingw-w64-x86_64-gstreamer
  pacman -S mingw-w64-x86_64-gst-plugins-base
  pacman -S mingw-w64-x86_64-gst-plugins-good
  pacman -S mingw-w64-x86_64-python-gobject
  pacman -S mingw-w64-x86_64-blueprint-compiler
"""

import os
import shutil
import subprocess
import sys
import glob

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
RESOURCES_DIR = os.path.join(DATA_DIR, "resources")
BUILD_DIR = os.path.join(BASE_DIR, "build")
UI_DIR = os.path.join(BUILD_DIR, "ui")

MSYS2_ROOTS = [
    r"C:\msys64\mingw64",
    r"C:\msys64\ucrt64",
    r"C:\msys2\mingw64",
    r"C:\msys2\ucrt64",
]


def find_msys2_root():
    for root in MSYS2_ROOTS:
        if os.path.isdir(root):
            return root
    return None


def find_exe(name, bin_dir):
    """Find an executable, with or without .exe extension."""
    for candidate in [name + ".exe", name]:
        path = os.path.join(bin_dir, candidate)
        if os.path.isfile(path):
            return path
    return shutil.which(name)


def find_msys2_python(root):
    """Find MSYS2's python3.exe and its site-packages."""
    bin_dir = os.path.join(root, "bin")
    python = find_exe("python3", bin_dir) or find_exe("python", bin_dir)
    if not python:
        return None, None
    # Find site-packages with blueprintcompiler
    lib_glob = os.path.join(root, "lib", "python3*", "site-packages")
    for sp in sorted(glob.glob(lib_glob), reverse=True):
        if os.path.isdir(os.path.join(sp, "blueprintcompiler")):
            return python, sp
    return python, None


def run(cmd, extra_env=None, **kwargs):
    print(f"  $ {' '.join(str(c) for c in cmd)}")
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    result = subprocess.run(cmd, env=env, **kwargs)
    if result.returncode != 0:
        print(f"ERROR: command failed with exit code {result.returncode}")
        sys.exit(result.returncode)


def main():
    print("=== Blanket Windows Build ===\n")

    msys2_root = find_msys2_root()
    if not msys2_root:
        print("ERROR: MSYS2 not found in standard locations.")
        print("Install from https://www.msys2.org/")
        sys.exit(1)

    bin_dir = os.path.join(msys2_root, "bin")
    print(f"  MSYS2 root : {msys2_root}")

    # Locate tools
    glib_schemas = find_exe("glib-compile-schemas", bin_dir)
    glib_res = find_exe("glib-compile-resources", bin_dir)
    msys2_python, blueprint_sp = find_msys2_python(msys2_root)

    for label, path in [
        ("glib-compile-schemas", glib_schemas),
        ("glib-compile-resources", glib_res),
        ("python (MSYS2)", msys2_python),
        ("blueprintcompiler module", blueprint_sp),
    ]:
        if not path:
            print(f"ERROR: {label} not found in {msys2_root}")
            print("Run in MSYS2 shell: pacman -S mingw-w64-x86_64-glib2 mingw-w64-x86_64-blueprint-compiler")
            sys.exit(1)
        print(f"  {label:30s}: {path}")

    os.makedirs(BUILD_DIR, exist_ok=True)
    os.makedirs(UI_DIR, exist_ok=True)

    # 1. Compile GSettings schema
    print("\n[1/3] Compiling GSettings schema...")
    schema_src = os.path.join(DATA_DIR, "com.rafaelmardojai.Blanket.gschema.xml")
    shutil.copy(schema_src, os.path.join(BUILD_DIR, os.path.basename(schema_src)))
    run([glib_schemas, BUILD_DIR])

    # 2. Compile Blueprint UI files via MSYS2 Python
    print("\n[2/3] Compiling Blueprint UI files...")
    blp_files = [
        os.path.join(RESOURCES_DIR, f)
        for f in sorted(os.listdir(RESOURCES_DIR))
        if f.endswith(".blp")
    ]
    blueprint_script = os.path.join(msys2_root, "bin", "blueprint-compiler")
    run(
        [msys2_python, blueprint_script, "batch-compile", UI_DIR, RESOURCES_DIR] + blp_files,
        extra_env={"PYTHONPATH": blueprint_sp},
    )

    # 3. Copy static assets and compile GResource bundle
    print("\n[3/3] Compiling GResource bundle...")

    for subdir in ["sounds", "icons"]:
        src = os.path.join(RESOURCES_DIR, subdir)
        dst = os.path.join(UI_DIR, subdir)
        if os.path.exists(dst):
            shutil.rmtree(dst)
        shutil.copytree(src, dst)

    shutil.copy(os.path.join(RESOURCES_DIR, "style.css"), UI_DIR)

    gresource_xml = os.path.join(RESOURCES_DIR, "blanket.gresource.xml")
    gresource_out = os.path.join(BUILD_DIR, "blanket.gresource")
    run([
        glib_res,
        "--sourcedir", UI_DIR,
        "--target", gresource_out,
        gresource_xml,
    ])

    print("\n=== Build complete! ===")
    print("Run the app with:  python run_windows.py")


if __name__ == "__main__":
    main()
