/// Which browser an iPhone or iPad visitor is using, so the "Add to Home
/// Screen" steps can point at the right buttons.
enum HomeScreenBrowser {
  /// Safari 26 or newer: Share sits inside the "•••" menu.
  safariNew,

  /// Older Safari: Share is right in the toolbar.
  safari,
  chrome,
  edge,
  firefox,

  /// Inside another app (Instagram, Facebook, TikTok, the Google app...):
  /// it has to be opened in Safari first.
  inApp,
  other,
}

/// Works out the browser from its user agent (pure, so it can be tested).
HomeScreenBrowser homeScreenBrowserFor(String ua) {
  if (RegExp(
    r'FBAN|FBAV|Instagram|Line/|Twitter|TikTok|musical_ly|Snapchat|GSA/|LinkedInApp|Pinterest',
  ).hasMatch(ua)) {
    return HomeScreenBrowser.inApp;
  }
  if (ua.contains('CriOS')) return HomeScreenBrowser.chrome;
  if (ua.contains('EdgiOS')) return HomeScreenBrowser.edge;
  if (ua.contains('FxiOS')) return HomeScreenBrowser.firefox;
  final safari = RegExp(r'Version/(\d+)').firstMatch(ua);
  if (safari != null && ua.contains('Safari')) {
    return int.parse(safari.group(1)!) >= 26
        ? HomeScreenBrowser.safariNew
        : HomeScreenBrowser.safari;
  }
  return HomeScreenBrowser.other;
}

/// An iPhone, iPod or iPad (iPads ask for the desktop site, so they look
/// like a Mac apart from having a touch screen).
bool isAppleMobile(String ua, {int maxTouchPoints = 0}) =>
    RegExp(r'iPhone|iPad|iPod').hasMatch(ua) ||
    (ua.contains('Macintosh') && maxTouchPoints > 1);

/// An Android phone or tablet.
bool isAndroidDevice(String ua) => ua.contains('Android');
