import 'dart:async';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Gere o comportamento da janela e o ícone da área de notificação no Windows.
class WindowTrayService with WindowListener, TrayListener {
  WindowTrayService._();

  static final WindowTrayService instance = WindowTrayService._();

  bool _isQuitting = false;

  Future<void> initialize() async {
    await windowManager.ensureInitialized();

    windowManager.addListener(this);
    trayManager.addListener(this);

    await windowManager.setPreventClose(true);
    await trayManager.setIcon('windows/runner/resources/app_icon.ico');
    await trayManager.setToolTip('My Tasks');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show_window', label: 'Abrir My Tasks'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: 'Sair'),
        ],
      ),
    );
  }

  Future<void> _hideToTray() async {
    await windowManager.hide();
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.focus();
  }

  Future<void> _exitApp() async {
    _isQuitting = true;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    await trayManager.destroy();
    await windowManager.destroy();
  }

  @override
  void onWindowMinimize() {
    unawaited(_hideToTray());
  }

  @override
  void onWindowClose() {
    if (_isQuitting) return;
    unawaited(_hideToTray());
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        unawaited(_showWindow());
        return;
      case 'exit_app':
        unawaited(_exitApp());
        return;
    }
  }
}
