// Picks the real (package:web-based) implementation when compiling for web,
// and a no-op stub otherwise (e.g. `flutter test` on the Dart VM, which
// can't compile `package:web`'s JS interop). The app only ships as web per
// spec, so the stub branch never runs in production.
export 'pwa_install_service_stub.dart'
    if (dart.library.js_interop) 'pwa_install_service_web.dart';
