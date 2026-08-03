/// No-op window tray service for the web build.
class WindowTrayService {
  WindowTrayService._();

  static final WindowTrayService instance = WindowTrayService._();

  Future<void> initialize() async {}
}
