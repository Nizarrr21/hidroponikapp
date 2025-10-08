import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  SensorData? _lastData;
  
  // Notification enabled states
  bool _temperatureAlertsEnabled = true;
  bool _tdsAlertsEnabled = true;
  bool _waterLevelAlertsEnabled = true;
  bool _pumpStatusAlertsEnabled = true;
  
  // Notification thresholds
  double tempMin = 20.0;
  double tempMax = 30.0;
  double tdsMin = 600.0;
  double tdsMax = 1000.0;
  double waterLevelMin = 30.0;
  double waterLevelMax = 80.0;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Load notification preferences
    await _loadNotificationPreferences();

    _isInitialized = true;
    print('Notification service initialized');
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Handle notification tap - navigate to specific screen
  }

  Future<void> checkAndNotify(SensorData data) async {
    if (!_isInitialized) await initialize();

    // Temperature alerts
    if (_temperatureAlertsEnabled) {
      if (data.temperature < tempMin) {
        await _showNotification(
          'Temperature Alert',
          '❄️ Temperature too low: ${data.temperature.toStringAsFixed(1)}°C',
          'temperature_low',
          Importance.high,
        );
      } else if (data.temperature > tempMax) {
        await _showNotification(
          'Temperature Alert',
          '🔥 Temperature too high: ${data.temperature.toStringAsFixed(1)}°C',
          'temperature_high',
          Importance.high,
        );
      }
    }

    // TDS alerts
    if (_tdsAlertsEnabled) {
      if (data.tds < tdsMin) {
        await _showNotification(
          'TDS Alert',
          '💧 TDS level low: ${data.tds.toStringAsFixed(0)} ppm',
          'tds_low',
          Importance.high,
        );
      } else if (data.tds > tdsMax) {
        await _showNotification(
          'TDS Alert',
          '⚠️ TDS level high: ${data.tds.toStringAsFixed(0)} ppm',
          'tds_high',
          Importance.high,
        );
      }
    }

    // Water level alerts
    if (_waterLevelAlertsEnabled) {
      if (data.waterLevel < waterLevelMin) {
        await _showNotification(
          'Water Level Alert',
          '🚨 Water level critical: ${data.waterLevel.toStringAsFixed(0)}%',
          'water_low',
          Importance.max,
        );
      } else if (data.waterLevel > waterLevelMax) {
        await _showNotification(
          'Water Level Alert',
          '🌊 Water level high: ${data.waterLevel.toStringAsFixed(0)}%',
          'water_high',
          Importance.defaultImportance,
        );
      }
    }

    // Pump status changes
    if (_pumpStatusAlertsEnabled && _lastData != null) {
      if (data.pumpStatus != _lastData!.pumpStatus) {
        await _showNotification(
          'Pump Status',
          '💧 Water pump ${data.pumpStatus ? "started" : "stopped"}',
          'pump_status',
          Importance.low,
        );
      }
      if (data.nutrientPumpStatus != _lastData!.nutrientPumpStatus) {
        await _showNotification(
          'Pump Status',
          '🥤 Nutrient pump ${data.nutrientPumpStatus ? "started" : "stopped"}',
          'nutrient_pump_status',
          Importance.low,
        );
      }
    }

    _lastData = data;
  }

  Future<void> _showNotification(
    String title,
    String body,
    String payload,
    Importance importance,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      'hydroponic_alerts',
      'Hydroponic Alerts',
      channelDescription: 'Important alerts for hydroponic system',
      importance: importance,
      priority: Priority.high,
      ticker: 'Hydroponic Alert',
      color: const Color(0xFF00D9A3),
      enableLights: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      payload.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showCustomNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    await _showNotification(
      title,
      body,
      payload ?? 'custom',
      Importance.defaultImportance,
    );
  }

  Future<void> scheduleNotification(
    String title,
    String body,
    DateTime scheduledTime,
  ) async {
    if (!_isInitialized) await initialize();

    final androidDetails = const AndroidNotificationDetails(
      'hydroponic_scheduled',
      'Scheduled Notifications',
      channelDescription: 'Scheduled notifications for maintenance',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final zonedTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _notifications.zonedSchedule(
      scheduledTime.millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      zonedTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  void updateThresholds({
    double? tempMin,
    double? tempMax,
    double? tdsMin,
    double? tdsMax,
    double? waterMin,
    double? waterMax,
  }) {
    if (tempMin != null) this.tempMin = tempMin;
    if (tempMax != null) this.tempMax = tempMax;
    if (tdsMin != null) this.tdsMin = tdsMin;
    if (tdsMax != null) this.tdsMax = tdsMax;
    if (waterMin != null) waterLevelMin = waterMin;
    if (waterMax != null) waterLevelMax = waterMax;
  }

  // Getters for notification states
  bool get temperatureAlertsEnabled => _temperatureAlertsEnabled;
  bool get tdsAlertsEnabled => _tdsAlertsEnabled;
  bool get waterLevelAlertsEnabled => _waterLevelAlertsEnabled;
  bool get pumpStatusAlertsEnabled => _pumpStatusAlertsEnabled;

  // Methods to update notification states
  Future<void> setTemperatureAlertsEnabled(bool enabled) async {
    _temperatureAlertsEnabled = enabled;
    await _saveNotificationPreferences();
  }

  Future<void> setTdsAlertsEnabled(bool enabled) async {
    _tdsAlertsEnabled = enabled;
    await _saveNotificationPreferences();
  }

  Future<void> setWaterLevelAlertsEnabled(bool enabled) async {
    _waterLevelAlertsEnabled = enabled;
    await _saveNotificationPreferences();
  }

  Future<void> setPumpStatusAlertsEnabled(bool enabled) async {
    _pumpStatusAlertsEnabled = enabled;
    await _saveNotificationPreferences();
  }

  // Load notification preferences from SharedPreferences
  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _temperatureAlertsEnabled = prefs.getBool('temp_alerts_enabled') ?? true;
    _tdsAlertsEnabled = prefs.getBool('tds_alerts_enabled') ?? true;
    _waterLevelAlertsEnabled = prefs.getBool('water_alerts_enabled') ?? true;
    _pumpStatusAlertsEnabled = prefs.getBool('pump_alerts_enabled') ?? true;
  }

  // Save notification preferences to SharedPreferences
  Future<void> _saveNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('temp_alerts_enabled', _temperatureAlertsEnabled);
    await prefs.setBool('tds_alerts_enabled', _tdsAlertsEnabled);
    await prefs.setBool('water_alerts_enabled', _waterLevelAlertsEnabled);
    await prefs.setBool('pump_alerts_enabled', _pumpStatusAlertsEnabled);
  }
}