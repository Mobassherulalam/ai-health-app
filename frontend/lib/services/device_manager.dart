import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class DeviceManager {
  static final DeviceManager _instance = DeviceManager._internal();
  factory DeviceManager() => _instance;
  DeviceManager._internal();

  bool _ecgMonitorEnabled = true;
  bool _heartRateMonitorEnabled = true;
  bool _spo2MonitorEnabled = true;
  bool _bloodPressureMonitorEnabled = true;
  bool _temperatureMonitorEnabled = true;
  bool _pulseOximeterEnabled = false;
  bool _glucoseMonitorEnabled = false;

  int _ecgSyncInterval = 5;
  int _vitalsSyncInterval = 5;
  int _temperatureSyncInterval = 7;

  final StreamController<Map<String, bool>> _deviceStateController =
      StreamController<Map<String, bool>>.broadcast();
  final StreamController<Map<String, int>> _syncIntervalController =
      StreamController<Map<String, int>>.broadcast();

  bool get ecgMonitorEnabled => _ecgMonitorEnabled;
  bool get heartRateMonitorEnabled => _heartRateMonitorEnabled;
  bool get spo2MonitorEnabled => _spo2MonitorEnabled;
  bool get bloodPressureMonitorEnabled => _bloodPressureMonitorEnabled;
  bool get temperatureMonitorEnabled => _temperatureMonitorEnabled;
  bool get pulseOximeterEnabled => _pulseOximeterEnabled;
  bool get glucoseMonitorEnabled => _glucoseMonitorEnabled;

  int get ecgSyncInterval => _ecgSyncInterval;
  int get vitalsSyncInterval => _vitalsSyncInterval;
  int get temperatureSyncInterval => _temperatureSyncInterval;

  Stream<Map<String, bool>> get deviceStateStream =>
      _deviceStateController.stream;
  Stream<Map<String, int>> get syncIntervalStream =>
      _syncIntervalController.stream;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    _ecgMonitorEnabled = prefs.getBool('ecgMonitorEnabled') ?? true;
    _heartRateMonitorEnabled = prefs.getBool('heartRateMonitorEnabled') ?? true;
    _spo2MonitorEnabled = prefs.getBool('spo2MonitorEnabled') ?? true;
    _bloodPressureMonitorEnabled =
        prefs.getBool('bloodPressureMonitorEnabled') ?? true;
    _temperatureMonitorEnabled =
        prefs.getBool('temperatureMonitorEnabled') ?? true;
    _pulseOximeterEnabled = prefs.getBool('pulseOximeterEnabled') ?? false;
    _glucoseMonitorEnabled = prefs.getBool('glucoseMonitorEnabled') ?? false;

    _ecgSyncInterval = prefs.getInt('ecgSyncInterval') ?? 5;
    _vitalsSyncInterval = prefs.getInt('vitalsSyncInterval') ?? 5;
    _temperatureSyncInterval = prefs.getInt('temperatureSyncInterval') ?? 7;

    _notifyDeviceStateChange();
    _notifySyncIntervalChange();
  }

  Future<void> updateDeviceState(String deviceType, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    switch (deviceType) {
      case 'ecg':
        _ecgMonitorEnabled = enabled;
        await prefs.setBool('ecgMonitorEnabled', enabled);
        break;
      case 'heartRate':
        _heartRateMonitorEnabled = enabled;
        await prefs.setBool('heartRateMonitorEnabled', enabled);
        break;
      case 'spo2':
        _spo2MonitorEnabled = enabled;
        await prefs.setBool('spo2MonitorEnabled', enabled);
        break;
      case 'bloodPressure':
        _bloodPressureMonitorEnabled = enabled;
        await prefs.setBool('bloodPressureMonitorEnabled', enabled);
        break;
      case 'temperature':
        _temperatureMonitorEnabled = enabled;
        await prefs.setBool('temperatureMonitorEnabled', enabled);
        break;
      case 'pulseOximeter':
        _pulseOximeterEnabled = enabled;
        await prefs.setBool('pulseOximeterEnabled', enabled);
        break;
      case 'glucose':
        _glucoseMonitorEnabled = enabled;
        await prefs.setBool('glucoseMonitorEnabled', enabled);
        break;
    }
    _notifyDeviceStateChange();
  }

  Future<void> updateSyncInterval(String intervalType, int interval) async {
    final prefs = await SharedPreferences.getInstance();

    switch (intervalType) {
      case 'ecg':
        _ecgSyncInterval = interval;
        await prefs.setInt('ecgSyncInterval', interval);
        break;
      case 'vitals':
        _vitalsSyncInterval = interval;
        await prefs.setInt('vitalsSyncInterval', interval);
        break;
      case 'temperature':
        _temperatureSyncInterval = interval;
        await prefs.setInt('temperatureSyncInterval', interval);
        break;
    }
    _notifySyncIntervalChange();
  }

  void _notifyDeviceStateChange() {
    _deviceStateController.add({
      'ecg': _ecgMonitorEnabled,
      'heartRate': _heartRateMonitorEnabled,
      'spo2': _spo2MonitorEnabled,
      'bloodPressure': _bloodPressureMonitorEnabled,
      'temperature': _temperatureMonitorEnabled,
      'pulseOximeter': _pulseOximeterEnabled,
      'glucose': _glucoseMonitorEnabled,
    });
  }

  void _notifySyncIntervalChange() {
    _syncIntervalController.add({
      'ecg': _ecgSyncInterval,
      'vitals': _vitalsSyncInterval,
      'temperature': _temperatureSyncInterval,
    });
  }

  bool get isVitalsMonitoringEnabled =>
      _heartRateMonitorEnabled ||
      _spo2MonitorEnabled ||
      _bloodPressureMonitorEnabled;

  List<String> getEnabledVitals() {
    List<String> enabled = [];
    if (_heartRateMonitorEnabled) enabled.add('heartRate');
    if (_spo2MonitorEnabled) enabled.add('spo2');
    if (_bloodPressureMonitorEnabled) enabled.add('bloodPressure');
    return enabled;
  }

  void dispose() {
    _deviceStateController.close();
    _syncIntervalController.close();
  }
}
