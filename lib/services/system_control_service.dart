import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';

class SystemControlService {
  SystemControlService() {
    try {
      // Don't show system volume UI when we control it
      VolumeController().showSystemUI = false;
    } catch (_) {}
  }

  /// Set media volume (0-100)
  Future<String> setVolume(int level) async {
    try {
      final volume = (level / 100).clamp(0.0, 1.0);
      VolumeController().setVolume(volume);
      return 'Volume set to $level%';
    } catch (e) {
      return 'Error setting volume: $e';
    }
  }

  /// Get current volume (0-100)
  Future<int> getVolume() async {
    try {
      final volume = await VolumeController().getVolume();
      return (volume * 100).round();
    } catch (e) {
      return -1;
    }
  }

  /// Set screen brightness (0-100)
  Future<String> setBrightness(int level) async {
    try {
      final brightness = (level / 100).clamp(0.0, 1.0);
      await ScreenBrightness().setScreenBrightness(brightness);
      return 'Brightness set to $level%';
    } catch (e) {
      return 'Error setting brightness: $e';
    }
  }

  /// Get current brightness (0-100)
  Future<int> getBrightness() async {
    try {
      final brightness = await ScreenBrightness().current;
      return (brightness * 100).round();
    } catch (e) {
      return -1;
    }
  }
}
