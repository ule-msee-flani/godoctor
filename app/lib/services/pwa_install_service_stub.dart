/// Non-web fallback (used when running e.g. `flutter test` on the Dart VM,
/// which can't compile `package:web`'s JS interop). The app itself only ever
/// ships as web per spec, so this branch is never hit in production -- see
/// `pwa_install_service.dart` for the conditional export that picks this vs.
/// the real implementation.
class PwaInstallService {
  PwaInstallService._();

  static final PwaInstallService instance = PwaInstallService._();

  bool get isRunningStandalone => false;
  bool get isIOS => false;
  bool get shouldOfferInstall => false;
}
