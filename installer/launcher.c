/*
 * Blanket.exe - Windows launcher
 * Finds MSYS2 Python and runs run_windows.py from the install directory.
 * Compiled with: gcc -mwindows -o Blanket.exe launcher.c -lshlwapi
 */
#include <windows.h>
#include <shlwapi.h>
#include <stdio.h>

/* Known MSYS2 mingw64 Python locations */
static const char* PYTHON_CANDIDATES[] = {
    "C:\\msys64\\mingw64\\bin\\python3.exe",
    "C:\\msys64\\mingw64\\bin\\python.exe",
    "C:\\msys64\\ucrt64\\bin\\python3.exe",
    "C:\\msys64\\ucrt64\\bin\\python.exe",
    "C:\\msys2\\mingw64\\bin\\python3.exe",
    "C:\\msys2\\mingw64\\bin\\python.exe",
    NULL
};

static int find_python(char* out, DWORD size) {
    for (int i = 0; PYTHON_CANDIDATES[i]; i++) {
        if (PathFileExistsA(PYTHON_CANDIDATES[i])) {
            strncpy(out, PYTHON_CANDIDATES[i], size - 1);
            out[size - 1] = '\0';
            return 1;
        }
    }
    return 0;
}

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmd, int nShow) {
    char install_dir[MAX_PATH];
    char python[MAX_PATH];
    char script[MAX_PATH];
    char cmd[MAX_PATH * 3 + 10];

    /* Resolve directory of this .exe */
    GetModuleFileNameA(NULL, install_dir, MAX_PATH);
    PathRemoveFileSpecA(install_dir);

    /* Find Python */
    if (!find_python(python, sizeof(python))) {
        MessageBoxA(NULL,
            "Python (MSYS2 mingw64) bulunamadi.\n\n"
            "Lutfen once install.ps1 calistirin veya\n"
            "MSYS2'yi https://www.msys2.org/ adresinden kurun.",
            "Blanket - Hata", MB_ICONERROR | MB_OK);
        return 1;
    }

    snprintf(script, sizeof(script), "%s\\run_windows.py", install_dir);
    if (!PathFileExistsA(script)) {
        MessageBoxA(NULL, "run_windows.py bulunamadi. Kurulum bozuk olabilir.",
            "Blanket - Hata", MB_ICONERROR | MB_OK);
        return 1;
    }

    snprintf(cmd, sizeof(cmd), "\"%s\" \"%s\"", python, script);

    STARTUPINFOA si = {0};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi = {0};

    if (!CreateProcessA(NULL, cmd, NULL, NULL, FALSE,
                        CREATE_NO_WINDOW, NULL, install_dir, &si, &pi)) {
        char msg[512];
        snprintf(msg, sizeof(msg), "Uygulama baslatılamadi.\nKomut: %s\nHata kodu: %lu",
                 cmd, GetLastError());
        MessageBoxA(NULL, msg, "Blanket - Hata", MB_ICONERROR | MB_OK);
        return 1;
    }

    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD exit_code = 0;
    GetExitCodeProcess(pi.hProcess, &exit_code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return (int)exit_code;
}
