# Blanket - Installer Builder
# Produces dist\Blanket-0.8.0-setup.exe
# Run with: powershell -ExecutionPolicy Bypass -File create_installer.ps1

$ErrorActionPreference = "Continue"

$MSYS2_ROOT  = "C:\msys64"
$MSYS2_BIN   = "$MSYS2_ROOT\mingw64\bin"
$BASH        = "$MSYS2_ROOT\usr\bin\bash.exe"
$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$BUILD_DIR   = "$SCRIPT_DIR\build"
$DIST_DIR    = "$SCRIPT_DIR\dist"
$INSTALL_DIR = "$SCRIPT_DIR\installer"

$INNO_PATHS = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 5\ISCC.exe"
)
$INNO_PORTABLE = "$SCRIPT_DIR\installer\innosetup\ISCC.exe"
$INNO_DOWNLOAD = "https://jrsoftware.org/download.php/is.exe"

function Write-Step($n, $total, $msg) {
    Write-Host ""
    Write-Host "[$n/$total] $msg" -ForegroundColor Cyan
}
function Write-OK($msg)  { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Err($msg) { Write-Host "  ERR $msg" -ForegroundColor Red; exit 1 }

# ─── Banner ───────────────────────────────────────────────────────────────────
Clear-Host
Write-Host "================================================" -ForegroundColor DarkCyan
Write-Host "       Blanket - Installer Builder              " -ForegroundColor White
Write-Host "================================================" -ForegroundColor DarkCyan

$TOTAL = 5
$python = "$MSYS2_BIN\python3.exe"
if (-not (Test-Path $python)) { $python = "$MSYS2_BIN\python.exe" }

# ─── Step 1: Ön koşullar ─────────────────────────────────────────────────────
Write-Step 1 $TOTAL "On kosullar kontrol ediliyor..."

if (-not (Test-Path $MSYS2_BIN)) { Write-Err "MSYS2 bulunamadi. Once install.ps1 calistirin." }
Write-OK "MSYS2 hazir."

if (-not (Test-Path "$BUILD_DIR\blanket.gresource")) {
    Write-Host "  Build dosyalari eksik, setup_windows.py calistiriliyor..." -ForegroundColor Yellow
    & $python "$SCRIPT_DIR\setup_windows.py"
    if ($LASTEXITCODE -ne 0) { Write-Err "setup_windows.py basarisiz." }
}
if (-not (Test-Path "$BUILD_DIR\blanket.ico")) {
    Write-Err "blanket.ico bulunamadi. Once install.ps1 calistirin (ikon olusturulacak)."
}
Write-OK "Build dosyalari hazir."

# ─── Step 2: Blanket.exe derle (C launcher) ──────────────────────────────────
Write-Step 2 $TOTAL "Blanket.exe derleniyor..."

$gcc     = "$MSYS2_BIN\gcc.exe"
$windres = "$MSYS2_BIN\windres.exe"
$launcherC   = "$INSTALL_DIR\launcher.c"
$launcherRC  = "$INSTALL_DIR\launcher.rc"
$launcherRES = "$INSTALL_DIR\launcher.res"
$launcherEXE = "$INSTALL_DIR\Blanket.exe"

if (-not (Test-Path $gcc)) {
    Write-Host "  GCC bulunamadi, kuruluyor..." -ForegroundColor Yellow
    & $BASH -lc "pacman -S --noconfirm --needed mingw-w64-x86_64-gcc"
}

# windres ve gcc, yol icindeki boslukla calismaz.
# Tum derlemeyi C:\Temp\BlanketBuild (bosluksuz) altinda yap.
$tmpDir = "C:\Temp\BlanketBuild"
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

Copy-Item "$BUILD_DIR\blanket.ico"    "$tmpDir\blanket.ico"    -Force
Copy-Item "$launcherC"                "$tmpDir\launcher.c"     -Force

$rcContent = @"
#include <windows.h>
1 ICON "blanket.ico"
VS_VERSION_INFO VERSIONINFO
FILEVERSION 0,8,0,0 PRODUCTVERSION 0,8,0,0
FILEFLAGSMASK VS_FFI_FILEFLAGSMASK FILEFLAGS 0
FILEOS VOS_NT_WINDOWS32 FILETYPE VFT_APP FILESUBTYPE VFT2_UNKNOWN
BEGIN
  BLOCK "StringFileInfo"
  BEGIN
    BLOCK "040904B0"
    BEGIN
      VALUE "FileDescription","Blanket - Listen to different sounds"
      VALUE "FileVersion","0.8.0"
      VALUE "ProductName","Blanket"
      VALUE "ProductVersion","0.8.0"
      VALUE "LegalCopyright","GPL-3.0-or-later"
      VALUE "OriginalFilename","Blanket.exe"
    END
  END
  BLOCK "VarFileInfo"
  BEGIN
    VALUE "Translation",0x0409,1200
  END
END
"@
Set-Content -Path "$tmpDir\launcher.rc" -Value $rcContent -Encoding ASCII

$buildSh = "$tmpDir\build.sh"
Set-Content -Path $buildSh -Value @'
#!/bin/bash
export PATH=/mingw64/bin:$PATH
cd /c/Temp/BlanketBuild
windres launcher.rc -O coff -o launcher.res || exit 1
gcc -mwindows -o Blanket.exe launcher.c launcher.res -lshlwapi || exit 1
echo COMPILE_OK
'@ -Encoding ASCII
& $BASH "/c/Temp/BlanketBuild/build.sh"
if ($LASTEXITCODE -ne 0) { Write-Err "Derleme basarisiz." }

Copy-Item "$tmpDir\Blanket.exe" $launcherEXE -Force
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
Write-OK "Blanket.exe derlendi: $launcherEXE"

# ─── Step 3: Wizard bitmap olustur (164x314 BMP) ─────────────────────────────
Write-Step 3 $TOTAL "Installer gorseli olusturuluyor..."

$rsvg      = "$MSYS2_BIN\rsvg-convert.exe"
$wizardBmp = "$BUILD_DIR\blanket_wizard.bmp"

if (Test-Path $rsvg) {
    $wizPng = "$BUILD_DIR\_wizard_tmp.png"
    & $rsvg -w 164 -h 314 -o $wizPng "$SCRIPT_DIR\brand\logo.svg"
    if ($LASTEXITCODE -eq 0) {
        # PNG -> BMP via Python
        $bmpScript = @'
import sys, struct, zlib

png_path = sys.argv[1]
bmp_path = sys.argv[2]

with open(png_path, "rb") as f:
    png = f.read()

# Parse PNG to get pixel data via subprocess (use rsvg to get BMP directly if possible)
# Simpler: use Python to write a minimal 24-bit BMP from PNG via PIL if available
try:
    from PIL import Image
    img = Image.open(png_path).convert("RGB")
    img.save(bmp_path, "BMP")
    print(f"  BMP olusturuldu: {bmp_path}")
except ImportError:
    # Fallback: copy PNG as-is (Inno Setup 6 supports PNG for wizard image)
    import shutil
    shutil.copy(png_path, bmp_path.replace(".bmp", ".png"))
    print("  PIL bulunamadi, PNG kullanilacak.")
'@
        $bmpScriptPath = "$BUILD_DIR\_make_bmp.py"
        Set-Content -Path $bmpScriptPath -Value $bmpScript -Encoding UTF8
        & $python $bmpScriptPath $wizPng $wizardBmp
        Remove-Item $wizPng        -ErrorAction SilentlyContinue
        Remove-Item $bmpScriptPath -ErrorAction SilentlyContinue
        Write-OK "Wizard gorseli olusturuldu."
    }
} else {
    Write-Host "  rsvg-convert bulunamadi, wizard gorseli atlanıyor." -ForegroundColor Yellow
}

# Inno Setup wizard image PNG fallback (update .iss if BMP does not exist)
$issPath = "$INSTALL_DIR\blanket.iss"
if (-not (Test-Path $wizardBmp)) {
    # Remove wizard image line from .iss so Inno uses default
    (Get-Content $issPath) | Where-Object { $_ -notmatch "WizardSmallImageFile" } |
        Set-Content $issPath
    Write-Host "  Wizard gorseli olmadan devam ediliyor." -ForegroundColor Yellow
}

# ─── Step 4: Inno Setup kur / bul ────────────────────────────────────────────
Write-Step 4 $TOTAL "Inno Setup aranıyor..."

$iscc = $null
foreach ($p in $INNO_PATHS) {
    if (Test-Path $p) { $iscc = $p; break }
}

if (-not $iscc -and (Test-Path $INNO_PORTABLE)) {
    $iscc = $INNO_PORTABLE
}

if (-not $iscc) {
    Write-Host "  Inno Setup bulunamadi, winget ile yukleniyor..." -ForegroundColor Yellow
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        winget install --id JRSoftware.InnoSetup --source winget --silent --accept-package-agreements --accept-source-agreements
        foreach ($p in $INNO_PATHS) {
            if (Test-Path $p) { $iscc = $p; break }
        }
    }

    if (-not $iscc) {
        # Son çare: portable inno setup indir
        Write-Host "  Inno Setup portable indiriliyor..." -ForegroundColor Yellow
        $innoInstaller = "$env:TEMP\innosetup.exe"
        Invoke-WebRequest -Uri $INNO_DOWNLOAD -OutFile $innoInstaller -UseBasicParsing
        $innoDir = "$INSTALL_DIR\innosetup"
        New-Item -ItemType Directory -Force -Path $innoDir | Out-Null
        Start-Process -FilePath $innoInstaller `
            -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$innoDir`"" `
            -Wait
        Remove-Item $innoInstaller -ErrorAction SilentlyContinue
        if (Test-Path "$innoDir\ISCC.exe") { $iscc = "$innoDir\ISCC.exe" }
    }
}

if (-not $iscc) { Write-Err "Inno Setup kurulamadi. Lutfen https://jrsoftware.org/isinfo.php adresinden kurun." }
Write-OK "Inno Setup bulundu: $iscc"

# ─── Step 5: Setup.exe derle ─────────────────────────────────────────────────
Write-Step 5 $TOTAL "Setup.exe olusturuluyor..."

New-Item -ItemType Directory -Force -Path $DIST_DIR | Out-Null

& $iscc "$INSTALL_DIR\blanket.iss"
if ($LASTEXITCODE -ne 0) { Write-Err "Inno Setup derleme basarisiz." }

$output = Get-ChildItem "$DIST_DIR\Blanket-*-setup.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-OK "Setup olusturuldu: $($output.FullName)"

# ─── Tamamlandı ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================" -ForegroundColor DarkCyan
Write-Host "              Tamamlandi!                       " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "Yukleme dosyasi:" -ForegroundColor White
Write-Host "  $($output.FullName)" -ForegroundColor Yellow
Write-Host ""
