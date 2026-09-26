import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Data saver": my camera starts off in consultations (I can still switch
/// it on), and the doctor's camera preference defaults to off. Stored on
/// this device only.
final dataSaverProvider = StateNotifierProvider<DataSaver, bool>(
  (ref) => DataSaver(),
);

class DataSaver extends StateNotifier<bool> {
  DataSaver() : super(false) {
    _load();
  }

  static const _key = 'data_saver';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) state = prefs.getBool(_key) ?? false;
    } catch (_) {
      // No storage (private window, tests): keep the default.
    }
  }

  Future<void> set(bool on) async {
    state = on;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, on);
    } catch (_) {}
  }
}

/// Rough mobile data used by a consultation, for the waiting room hint.
/// Video at the low bitrate we'll use is about 1.5 MB a minute; audio only
/// about 0.3 MB.
String estimateCallData({required bool myVideo, required bool theirVideo}) {
  const minutes = 10;
  final perMinute = (myVideo ? 0.75 : 0.15) + (theirVideo ? 0.75 : 0.15);
  final mb = (perMinute * minutes).round();
  return 'About $mb MB for 10 minutes';
}
