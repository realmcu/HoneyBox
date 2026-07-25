#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shellscalingapi.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // Window size is computed at runtime from the current machine's desktop work
  // area -- no hard-coded resolution, so it adapts to any PC / resolution / DPI
  // scaling. Target: a phone-portrait 9:19.5 full-screen aspect ratio, with a
  // height ~4/5 of the desktop work area, clamped to at least 640 on small
  // screens.
  //
  // DPI note: SPI_GETWORKAREA returns physical pixels, whereas
  // Win32Window::Create expects logical pixels (it scales them by the monitor
  // DPI internally). So convert the work area back to logical pixels first to
  // avoid double-scaling on high-DPI displays.
  RECT work_area = {0, 0, 1280, 720};  // conservative fallback if the query fails
  ::SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  const LONG work_w_px = work_area.right - work_area.left;
  const LONG work_h_px = work_area.bottom - work_area.top;

  // DPI scale factor of the primary monitor (96 DPI == 100%).
  double scale_factor = 1.0;
  const POINT origin_point = {work_area.left, work_area.top};
  HMONITOR monitor = ::MonitorFromPoint(origin_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi_x = 96, dpi_y = 96;
  if (SUCCEEDED(::GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y))) {
    scale_factor = dpi_x / 96.0;
  }

  // Convert to logical pixels, then compute the target window size.
  const double work_h_logical = work_h_px / scale_factor;
  const double work_w_logical = work_w_px / scale_factor;

  int win_h = static_cast<int>(work_h_logical * 0.8);  // ~4/5 of desktop height
  win_h = std::max(win_h, 640);                        // small-screen floor
  int win_w = static_cast<int>(win_h * 9.0 / 19.5);    // 9:19.5 aspect ratio

  // If that ends up wider than the work area (very small screens), clamp to the
  // work area width and derive the height from it.
  if (win_w > work_w_logical) {
    win_w = static_cast<int>(work_w_logical);
    win_h = static_cast<int>(win_w * 19.5 / 9.0);
  }

  // Center horizontally within the work area, slightly above middle vertically;
  // coordinates are logical pixels too.
  const int origin_x =
      static_cast<int>(work_area.left / scale_factor) +
      (static_cast<int>(work_w_logical) - win_w) / 2;
  const int origin_y = static_cast<int>(work_area.top / scale_factor) +
                       (static_cast<int>(work_h_logical) - win_h) / 4;

  Win32Window::Point origin(origin_x, origin_y);
  Win32Window::Size size(win_w, win_h);
  if (!window.Create(L"HoneyBox", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
