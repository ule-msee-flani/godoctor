// Picks the real (package:web-based) implementation when compiling for web,
// and a no-op stub otherwise (the Android app, and `flutter test` on the
// Dart VM, which can't compile `package:web`'s JS interop).
export 'pwa_install_service_stub.dart'
    if (dart.library.js_interop) 'pwa_install_service_web.dart';
