import 'dart:ffi' show Abi;

/// The Android ABI name the app is running as ("arm64-v8a", ...), or null
/// off Android.
String? currentAndroidAbi() => switch (Abi.current()) {
  Abi.androidArm64 => 'arm64-v8a',
  Abi.androidArm => 'armeabi-v7a',
  Abi.androidX64 => 'x86_64',
  _ => null,
};
