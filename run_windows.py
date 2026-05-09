"""
Windows launcher for Blanket.

Run setup_windows.py first, then launch with: python run_windows.py
Uses MSYS2's Python automatically if the current Python lacks 'gi'.
"""

import os
import sys
import subprocess
import glob

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BUILD_DIR = os.path.join(BASE_DIR, "build")
GRESOURCE = os.path.join(BUILD_DIR, "blanket.gresource")
SCHEMA_COMPILED = os.path.join(BUILD_DIR, "gschemas.compiled")

MSYS2_ROOTS = [
    r"C:\msys64\mingw64",
    r"C:\msys64\ucrt64",
    r"C:\msys2\mingw64",
    r"C:\msys2\ucrt64",
]


def find_msys2_python():
    for root in MSYS2_ROOTS:
        for name in ["python3.exe", "python.exe"]:
            path = os.path.join(root, "bin", name)
            if os.path.isfile(path):
                # Verify gi is available in this Python
                check = subprocess.run(
                    [path, "-c", "import gi"],
                    capture_output=True,
                )
                if check.returncode == 0:
                    return path, root
    return None, None


def _launch_with_msys2():
    """Re-launch this script using MSYS2's Python."""
    python, root = find_msys2_python()
    if not python:
        print("ERROR: No Python with 'gi' (PyGObject) found.")
        print("Install via MSYS2: pacman -S mingw-w64-x86_64-python-gobject")
        sys.exit(1)

    # Build PYTHONPATH with MSYS2 site-packages
    extra_paths = []
    for sp_glob in [os.path.join(root, "lib", "python3*", "site-packages")]:
        extra_paths.extend(glob.glob(sp_glob))

    env = os.environ.copy()
    env["GSETTINGS_SCHEMA_DIR"] = BUILD_DIR
    if extra_paths:
        env["PYTHONPATH"] = os.pathsep.join(extra_paths)

    # Also add MSYS2 bin to PATH so GStreamer plugins are found
    msys2_bin = os.path.join(root, "bin")
    env["PATH"] = msys2_bin + os.pathsep + env.get("PATH", "")

    result = subprocess.run([python, __file__] + sys.argv[1:], env=env)
    sys.exit(result.returncode)


# If gi is not importable, re-launch under MSYS2 Python
try:
    import gi  # noqa: E402
except ModuleNotFoundError:
    _launch_with_msys2()

# Verify build outputs exist
if not os.path.exists(GRESOURCE):
    print("ERROR: blanket.gresource not found.")
    print("Run setup_windows.py first.")
    sys.exit(1)

if not os.path.exists(SCHEMA_COMPILED):
    print("ERROR: gschemas.compiled not found.")
    print("Run setup_windows.py first.")
    sys.exit(1)

os.environ["GSETTINGS_SCHEMA_DIR"] = BUILD_DIR
sys.path.insert(0, BASE_DIR)

# Tell Windows to use Blanket's icon (not Python's) in the taskbar
try:
    import ctypes
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(
        "com.rafaelmardojai.Blanket"
    )
except Exception:
    pass

gi.require_version("Adw", "1")
gi.require_version("Gdk", "4.0")
gi.require_version("Gst", "1.0")
gi.require_version("GstPlay", "1.0")
gi.require_version("Gtk", "4.0")

from gi.repository import Gio, Gst  # noqa: E402

Gst.init(None)

resource = Gio.Resource.load(GRESOURCE)
Gio.resources_register(resource)

from blanket.main import main  # noqa: E402

sys.exit(main("0.8.1"))
