import 'package:shared_preferences/shared_preferences.dart';
import '../domain/smile_calibration.dart';

/// Stores derived thresholds only, never camera frames or expression samples.
class SmileCalibrationStore {
  static const _key = 'smile_calibration_v1';

  Future<SmileCalibration?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_key);
    if (values == null || values.length != 2) return null;
    final enter = double.tryParse(values[0]);
    final exit = double.tryParse(values[1]);
    if (enter == null || exit == null) return null;
    final calibration = SmileCalibration(enter: enter, exit: exit);
    return calibration.isValid ? calibration : null;
  }

  Future<void> save(SmileCalibration calibration) async {
    if (!calibration.isValid) throw ArgumentError('Invalid smile calibration');
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setStringList(_key, [
      calibration.enter.toString(),
      calibration.exit.toString(),
    ])) {
      throw StateError('Could not save smile calibration');
    }
  }
}
