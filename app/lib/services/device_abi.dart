// Which Android CPU type this phone runs, so updates download only the APK
// built for it. Web builds have no dart:ffi, hence the conditional import.
export 'device_abi_stub.dart' if (dart.library.ffi) 'device_abi_ffi.dart';
