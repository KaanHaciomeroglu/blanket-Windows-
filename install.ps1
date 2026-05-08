# Blanket Windows Installer
# Run with: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Continue"

$MSYS2_ROOT = "C:\msys64"
$MSYS2_BIN  = "$MSYS2_ROOT\mingw64\bin"
$BASH       = "$MSYS2_ROOT\usr\bin\bash.exe"

$PACKAGES = @(
    "mingw-w64-x86_64-gtk4",
    "mingw-w64-x86_64-libadwaita",
    "mingw-w64-x86_64-gstreamer",
    "mingw-w64-x86_64-gst-plugins-base",
    "mingw-w64-x86_64-gst-plugins-good",
    "mingw-w64-x86_64-python-gobject",
    "mingw-w64-x86_64-blueprint-compiler",
    "mingw-w64-x86_64-librsvg"
)

function Write-Step($n, $total, $msg) {
    Write-Host ""
    Write-Host "[$n/$total] $msg" -ForegroundColor Cyan
}

function Write-OK($msg)  { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Err($msg) { Write-Host "  ERR $msg" -ForegroundColor Red; exit 1 }

# ─── Banner ───────────────────────────────────────────────────────────────────
Clear-Host
Write-Host "============================================" -ForegroundColor DarkCyan
Write-Host "        Blanket - Windows Installer         " -ForegroundColor White
Write-Host "============================================" -ForegroundColor DarkCyan

$TOTAL_STEPS = 6
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ─── Step 1: MSYS2 ────────────────────────────────────────────────────────────
Write-Step 1 $TOTAL_STEPS "MSYS2 kontrol ediliyor..."

if (Test-Path "$MSYS2_ROOT\usr\bin\bash.exe") {
    Write-OK "MSYS2 zaten kurulu: $MSYS2_ROOT"
} else {
    Write-Host "  MSYS2 bulunamadi, kuruluyor..." -ForegroundColor Yellow

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host "  winget ile MSYS2 indiriliyor..."
        winget install --id MSYS2.MSYS2 --source winget --silent --accept-package-agreements --accept-source-agreements
    } else {
        $installer = "$env:TEMP\msys2-installer.exe"
        $url = "https://github.com/msys2/msys2-installer/releases/download/2024-01-13/msys2-x86_64-20240113.exe"
        Write-Host "  Indiriliyor: $url"
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
        Write-Host "  Yukleniyor..."
        Start-Process -FilePath $installer -ArgumentList "install --root $MSYS2_ROOT --confirm-command" -Wait
        Remove-Item $installer -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path "$MSYS2_ROOT\usr\bin\bash.exe")) {
        Write-Err "MSYS2 kurulumu basarisiz. Lutfen https://www.msys2.org/ adresinden manuel kurun."
    }
    Write-OK "MSYS2 kuruldu."
}

# ─── Step 2: pacman database güncelle ─────────────────────────────────────────
Write-Step 2 $TOTAL_STEPS "Paket veritabani guncelleniyor..."
& $BASH -lc "pacman -Sy --noconfirm"
if ($LASTEXITCODE -ne 0) { Write-Err "pacman -Sy basarisiz." }
Write-OK "Paket veritabani guncellendi."

# ─── Step 3: Bağımlılıkları kur ───────────────────────────────────────────────
Write-Step 3 $TOTAL_STEPS "Bagimliliklar kuruluyor..."
$pkgList = $PACKAGES -join " "
& $BASH -lc "pacman -S --noconfirm --needed $pkgList"
if ($LASTEXITCODE -ne 0) { Write-Err "Paket kurulumu basarisiz." }
Write-OK "Tum bagimliliklar kuruldu."

# ─── Step 4: UI kaynaklarını derle ────────────────────────────────────────────
Write-Step 4 $TOTAL_STEPS "UI kaynaklari ve sema derleniyor..."
$python = "$MSYS2_BIN\python3.exe"
if (-not (Test-Path $python)) { $python = "$MSYS2_BIN\python.exe" }

& $python "$scriptDir\setup_windows.py"
if ($LASTEXITCODE -ne 0) { Write-Err "setup_windows.py basarisiz." }
Write-OK "Kaynaklar derlendi."

# ─── Step 5: SVG → ICO dönüştür ───────────────────────────────────────────────
Write-Step 5 $TOTAL_STEPS "Uygulama ikonu olusturuluyor..."

$svgPath  = "$scriptDir\brand\logo.svg"
$icoPath  = "$scriptDir\build\blanket.ico"
$rsvg     = "$MSYS2_BIN\rsvg-convert.exe"

if (Test-Path $rsvg) {
    # SVG → 256x256 PNG, sonra Python ile PNG → ICO (çok boyutlu: 16,32,48,256)
    $pngPath = "$scriptDir\build\blanket_icon_tmp.png"
    & $rsvg -w 256 -h 256 -o $pngPath $svgPath

    if ($LASTEXITCODE -eq 0) {
        $icoScript = @'
import struct, sys, zlib

sizes = [16, 32, 48, 256]
src_png = sys.argv[1]
out_ico = sys.argv[2]
rsvg    = sys.argv[3]
import subprocess, os, tempfile

images = []
for s in sizes:
    tmp = tempfile.mktemp(suffix=".png")
    subprocess.run([rsvg, "-w", str(s), "-h", str(s), "-o", tmp, sys.argv[4]], check=True)
    with open(tmp, "rb") as f:
        data = f.read()
    images.append((s, data))
    os.remove(tmp)

# ICO header
count = len(images)
header = struct.pack("<HHH", 0, 1, count)
offset = 6 + count * 16
entries = b""
chunks  = b""
for (s, data) in images:
    sz = 0 if s == 256 else s   # 256 encoded as 0 in ICO spec
    entries += struct.pack("<BBBBHHII", sz, sz, 0, 0, 1, 32, len(data), offset)
    offset  += len(data)
    chunks  += data

with open(out_ico, "wb") as f:
    f.write(header + entries + chunks)
print(f"  ICO olusturuldu: {out_ico}")
'@
        $icoScriptPath = "$scriptDir\build\_make_ico.py"
        Set-Content -Path $icoScriptPath -Value $icoScript -Encoding UTF8
        & $python $icoScriptPath $pngPath $icoPath $rsvg $svgPath
        Remove-Item $pngPath      -ErrorAction SilentlyContinue
        Remove-Item $icoScriptPath -ErrorAction SilentlyContinue
        Write-OK "Ikon olusturuldu: $icoPath"
    } else {
        Write-Host "  UYARI: rsvg-convert basarisiz, ikon atlanıyor." -ForegroundColor Yellow
        $icoPath = $null
    }
} else {
    Write-Host "  UYARI: rsvg-convert bulunamadi, ikon atlanıyor." -ForegroundColor Yellow
    $icoPath = $null
}

# ─── Step 6: Kısayol oluştur ──────────────────────────────────────────────────
Write-Step 6 $TOTAL_STEPS "Masaustu kisayolu olusturuluyor..."

# .bat başlatıcı (terminalden çalıştırmak için)
$batPath = "$scriptDir\Blanket.bat"
Set-Content -Path $batPath -Value "@echo off`r`ncd /d `"%~dp0`"`r`npython run_windows.py" -Encoding ASCII

# .lnk kısayol (ikonlu, çift tık)
$lnkPath = "$scriptDir\Blanket.lnk"
$wsh  = New-Object -ComObject WScript.Shell
$link = $wsh.CreateShortcut($lnkPath)
$link.TargetPath       = "python"
$link.Arguments        = "`"$scriptDir\run_windows.py`""
$link.WorkingDirectory = $scriptDir
$link.Description      = "Blanket - Listen to different sounds"
if ($icoPath -and (Test-Path $icoPath)) {
    $link.IconLocation = $icoPath
}
$link.Save()

Write-OK "Baslatici olusturuldu : Blanket.bat"
Write-OK "Masaustu kisayolu     : Blanket.lnk"

# ─── Tamamlandı ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor DarkCyan
Write-Host "          Kurulum tamamlandi!               " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "Uygulamayi baslatmak icin:" -ForegroundColor White
Write-Host "  Blanket.lnk        (cift tikla - ikonlu kisayol)" -ForegroundColor Yellow
Write-Host "  Blanket.bat        (cift tikla - terminal penceresi ile)" -ForegroundColor Yellow
Write-Host "  python run_windows.py  (terminalden)" -ForegroundColor Yellow
Write-Host ""
