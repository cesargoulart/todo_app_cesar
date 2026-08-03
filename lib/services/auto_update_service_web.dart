/// No-op update service for the web build.
///
/// Native application updates download platform installers, which do not
/// apply when the app is running in a browser.
class AutoUpdateService {
  Future<void> initialize() async {}

  Future<void> manualUpdateCheck() async {}
}
