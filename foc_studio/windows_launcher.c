#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>
#include <windows.h>

/* 启动器职责：设置应用根目录与 Python 搜索路径，再拉起 runtime 中的真实程序。 */

static void show_error_message(const wchar_t *message) {
    MessageBoxW(NULL, message, L"foc_studio launcher", MB_OK | MB_ICONERROR);
}

/* 读取当前启动器所在目录，作为应用资源根目录。 */
static int get_module_directory(wchar_t *buffer, size_t buffer_size) {
    DWORD length = GetModuleFileNameW(NULL, buffer, (DWORD)buffer_size);
    if (length == 0 || length >= buffer_size) {
        return 0;
    }

    for (size_t index = length; index > 0; --index) {
        if (buffer[index - 1] == L'\\' || buffer[index - 1] == L'/') {
            buffer[index - 1] = L'\0';
            return 1;
        }
    }
    return 0;
}

/* 组装目标路径，避免在 PowerShell 中拼接复杂的命令行字符串。 */
static int join_path(
    wchar_t *buffer,
    size_t buffer_size,
    const wchar_t *left,
    const wchar_t *right
) {
    int written = _snwprintf(buffer, buffer_size, L"%ls\\%ls", left, right);
    if (written < 0 || (size_t)written >= buffer_size) {
        return 0;
    }
    return 1;
}

/* 让真实运行时同时能看到根目录源码路径与 runtime 扩展模块路径。 */
static int set_python_path(const wchar_t *app_root, const wchar_t *runtime_dir) {
    const wchar_t *existing = _wgetenv(L"PYTHONPATH");
    size_t total = wcslen(app_root) + 1 + wcslen(runtime_dir) + 1;
    if (existing != NULL && existing[0] != L'\0') {
        total += wcslen(existing) + 1;
    }

    wchar_t *python_path = (wchar_t *)malloc(total * sizeof(wchar_t));
    if (python_path == NULL) {
        return 0;
    }

    if (existing != NULL && existing[0] != L'\0') {
        _snwprintf(python_path, total, L"%ls;%ls;%ls", app_root, runtime_dir, existing);
    } else {
        _snwprintf(python_path, total, L"%ls;%ls", app_root, runtime_dir);
    }
    python_path[total - 1] = L'\0';

    int success = SetEnvironmentVariableW(L"PYTHONPATH", python_path);
    free(python_path);
    return success;
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR command_line, int show_command) {
    (void)instance;
    (void)previous;
    (void)command_line;
    (void)show_command;

    wchar_t app_root[MAX_PATH];
    wchar_t runtime_dir[MAX_PATH];
    wchar_t target_exe[MAX_PATH];
    wchar_t command[MAX_PATH * 2];

    if (!get_module_directory(app_root, MAX_PATH)) {
        show_error_message(L"无法解析 foc_studio 启动器所在目录。");
        return 1;
    }
    if (!join_path(runtime_dir, MAX_PATH, app_root, L"runtime")) {
        show_error_message(L"无法拼接 runtime 目录路径。");
        return 1;
    }
    if (!join_path(target_exe, MAX_PATH, runtime_dir, L"foc_studio-runtime.exe")) {
        show_error_message(L"无法拼接真实运行时程序路径。");
        return 1;
    }

    DWORD attributes = GetFileAttributesW(target_exe);
    if (attributes == INVALID_FILE_ATTRIBUTES || (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
        show_error_message(L"未找到 runtime\\foc_studio-runtime.exe。");
        return 1;
    }

    if (!SetEnvironmentVariableW(L"FOC_STUDIO_APP_ROOT", app_root)) {
        show_error_message(L"无法设置 FOC_STUDIO_APP_ROOT 环境变量。");
        return 1;
    }
    if (!set_python_path(app_root, runtime_dir)) {
        show_error_message(L"无法设置 PYTHONPATH 环境变量。");
        return 1;
    }

    if (_snwprintf(command, MAX_PATH * 2, L"\"%ls\"", target_exe) < 0) {
        show_error_message(L"无法构造真实运行时程序命令行。");
        return 1;
    }
    command[(MAX_PATH * 2) - 1] = L'\0';

    STARTUPINFOW startup_info;
    PROCESS_INFORMATION process_info;
    ZeroMemory(&startup_info, sizeof(startup_info));
    ZeroMemory(&process_info, sizeof(process_info));
    startup_info.cb = sizeof(startup_info);

    if (!CreateProcessW(
            target_exe,
            command,
            NULL,
            NULL,
            FALSE,
            0,
            NULL,
            app_root,
            &startup_info,
            &process_info)) {
        show_error_message(L"启动 runtime\\foc_studio-runtime.exe 失败。");
        return 1;
    }

    CloseHandle(process_info.hThread);
    CloseHandle(process_info.hProcess);
    return 0;
}
