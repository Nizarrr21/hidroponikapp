import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mqtt_service.dart';
import 'notification_service.dart';

class ScheduleItem {
  String id;
  String name;
  TimeOfDay time;
  bool enabled;
  List<int> days; // 1=Mon, 7=Sun
  String action; // 'water', 'nutrient', 'notify'
  int duration; // seconds

  ScheduleItem({
    required this.id,
    required this.name,
    required this.time,
    required this.enabled,
    required this.days,
    required this.action,
    required this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hour': time.hour,
      'minute': time.minute,
      'enabled': enabled,
      'days': days,
      'action': action,
      'duration': duration,
    };
  }

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'],
      name: json['name'],
      time: TimeOfDay(hour: json['hour'], minute: json['minute']),
      enabled: json['enabled'],
      days: List<int>.from(json['days']),
      action: json['action'],
      duration: json['duration'],
    );
  }
}

class ScheduleService {
  static final ScheduleService _instance = ScheduleService._internal();
  factory ScheduleService() => _instance;
  ScheduleService._internal();

  static const String _keySchedules = 'schedules';
  final MQTTService _mqttService = MQTTService();
  final NotificationService _notificationService = NotificationService();
  
  Timer? _scheduleTimer;
  Timer? _countdownTimer;
  
  // Stream controllers for UI updates
  final StreamController<String> _countdownController = StreamController<String>.broadcast();
  final StreamController<ScheduleItem> _activeScheduleController = StreamController<ScheduleItem>.broadcast();
  
  Stream<String> get countdownStream => _countdownController.stream;
  Stream<ScheduleItem> get activeScheduleStream => _activeScheduleController.stream;
  
  bool _isRunning = false;

  void startScheduleEngine() {
    if (_isRunning) return;
    
    _isRunning = true;
    print('🚀 Schedule Engine Started');
    
    // Check schedules every 10 seconds for accuracy
    _scheduleTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkSchedules();
    });
    
    // Update countdown every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }
  
  void stopScheduleEngine() {
    _isRunning = false;
    _scheduleTimer?.cancel();
    _countdownTimer?.cancel();
    print('⏹️ Schedule Engine Stopped');
  }
  
  Future<void> _checkSchedules() async {
    final schedules = await getSchedules();
    final now = DateTime.now();
    
    print('🔍 Checking ${schedules.length} schedules at ${now.hour}:${now.minute}:${now.second}');
    
    for (var schedule in schedules) {
      print('  📋 ${schedule.name}: enabled=${schedule.enabled}, days=${schedule.days}, time=${schedule.time.hour}:${schedule.time.minute}');
      
      if (schedule.enabled && schedule.days.contains(now.weekday)) {
        final scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          schedule.time.hour,
          schedule.time.minute,
        );
        
        final difference = scheduledTime.difference(now).inSeconds;
        print('    ⏱️ Time difference: ${difference}s (today weekday=${now.weekday})');
        
        // Execute if within 10 seconds of scheduled time
        if (difference >= -5 && difference <= 5) {
          print('⏰ Executing schedule: ${schedule.name}');
          await _executeSchedule(schedule);
        }
        
        // Show countdown alert 2 minutes before
        if (difference > 0 && difference <= 120) {
          _showCountdownAlert(schedule, difference);
        }
      }
    }
  }
  
  void _updateCountdown() async {
    final schedules = await getSchedules();
    final now = DateTime.now();
    
    ScheduleItem? nextSchedule;
    int minSeconds = 999999;
    
    for (var schedule in schedules) {
      if (!schedule.enabled) continue;
      
      for (var day in schedule.days) {
        final scheduledTime = _getNextScheduledDateTime(day, schedule.time);
        final difference = scheduledTime.difference(now).inSeconds;
        
        if (difference > 0 && difference < minSeconds) {
          minSeconds = difference;
          nextSchedule = schedule;
        }
      }
    }
    
    if (nextSchedule != null && minSeconds <= 300) { // 5 minutes
      final minutes = minSeconds ~/ 60;
      final seconds = minSeconds % 60;
      
      String countdown;
      if (minutes > 0) {
        countdown = '${minutes}m ${seconds}s';
      } else {
        countdown = '${seconds}s';
      }
      
      _countdownController.add('${nextSchedule.name} dalam $countdown');
      _activeScheduleController.add(nextSchedule);
    } else {
      _countdownController.add('');
    }
  }
  
  void _showCountdownAlert(ScheduleItem schedule, int secondsUntil) {
    final minutes = secondsUntil ~/ 60;
    final seconds = secondsUntil % 60;
    
    String actionText = '';
    switch (schedule.action) {
      case 'water':
        actionText = '💧 Pompa Air';
        break;
      case 'nutrient':
        actionText = '🥤 Pompa Nutrisi';
        break;
      case 'notify':
        actionText = '🔔 Notifikasi';
        break;
    }
    
    String timeText;
    if (minutes > 0) {
      timeText = '${minutes} menit ${seconds} detik';
    } else {
      timeText = '${seconds} detik';
    }
    
    _notificationService.showCustomNotification(
      '⏰ ${schedule.name}',
      '$actionText akan aktif dalam $timeText (${schedule.duration}s)',
    );
  }
  
  DateTime _getNextScheduledDateTime(int weekday, TimeOfDay time) {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If time has passed today and it's the right weekday, schedule for next week
    if (scheduledDate.weekday == weekday && scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    
    // Find the next occurrence of this weekday
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  void dispose() {
    stopScheduleEngine();
    _countdownController.close();
    _activeScheduleController.close();
  }

  Future<List<ScheduleItem>> getSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_keySchedules) ?? [];
    
    return jsonList.map((jsonStr) {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ScheduleItem.fromJson(json);
    }).toList();
  }

  Future<void> saveSchedules(List<ScheduleItem> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = schedules.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keySchedules, jsonList);
    
    // Schedule all notifications
    await _scheduleAllNotifications(schedules);
  }

  Future<void> addSchedule(ScheduleItem schedule) async {
    final schedules = await getSchedules();
    schedules.add(schedule);
    await saveSchedules(schedules);
  }

  Future<void> updateSchedule(ScheduleItem schedule) async {
    final schedules = await getSchedules();
    final index = schedules.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      schedules[index] = schedule;
      await saveSchedules(schedules);
    }
  }

  Future<void> deleteSchedule(String id) async {
    final schedules = await getSchedules();
    schedules.removeWhere((s) => s.id == id);
    await saveSchedules(schedules);
  }

  Future<void> toggleSchedule(String id, bool enabled) async {
    final schedules = await getSchedules();
    final index = schedules.indexWhere((s) => s.id == id);
    if (index != -1) {
      schedules[index].enabled = enabled;
      await saveSchedules(schedules);
    }
  }

  Future<void> _scheduleAllNotifications(List<ScheduleItem> schedules) async {
    // Cancel all existing notifications (handled internally by notification service)
    
    // Schedule new notifications for enabled schedules
    for (var schedule in schedules) {
      if (schedule.enabled) {
        await _scheduleNotification(schedule);
      }
    }
  }

  Future<void> _scheduleNotification(ScheduleItem schedule) async {
    // Schedule for each selected day
    for (var day in schedule.days) {
      final scheduledDate = _getNextScheduledDate(day, schedule.time);
      
      String actionText = '';
      switch (schedule.action) {
        case 'water':
          actionText = '💧 Water Pump';
          break;
        case 'nutrient':
          actionText = '🥤 Nutrient Pump';
          break;
        case 'notify':
          actionText = '🔔 Reminder';
          break;
      }
      
      await _notificationService.scheduleNotification(
        '${schedule.name}',
        '$actionText will run for ${schedule.duration}s',
        scheduledDate,
      );
    }
  }

  DateTime _getNextScheduledDate(int weekday, TimeOfDay time) {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Find the next occurrence of this weekday
    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> _executeSchedule(ScheduleItem schedule) async {
    print('🔄 Executing schedule: ${schedule.name} (${schedule.action})');
    
    switch (schedule.action) {
      case 'water':
        _mqttService.toggleWaterPump(true);
        print('💧 Water pump ON for ${schedule.duration}s');
        await Future.delayed(Duration(seconds: schedule.duration));
        _mqttService.toggleWaterPump(false);
        print('💧 Water pump OFF');
        
        await _notificationService.showCustomNotification(
          '💧 ${schedule.name} - Selesai',
          'Pompa air telah berjalan selama ${schedule.duration} detik',
        );
        break;

      case 'nutrient':
        _mqttService.toggleNutrientPump(true);
        print('🥤 Nutrient pump ON for ${schedule.duration}s');
        await Future.delayed(Duration(seconds: schedule.duration));
        _mqttService.toggleNutrientPump(false);
        print('🥤 Nutrient pump OFF');
        
        await _notificationService.showCustomNotification(
          '🥤 ${schedule.name} - Selesai',
          'Pompa nutrisi telah berjalan selama ${schedule.duration} detik',
        );
        break;

      case 'notify':
        await _notificationService.showCustomNotification(
          '🔔 ${schedule.name}',
          'Pengingat terjadwal',
        );
        print('🔔 Notification sent for: ${schedule.name}');
        break;
    }
  }

  Future<void> clearAllSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySchedules);
  }
}
