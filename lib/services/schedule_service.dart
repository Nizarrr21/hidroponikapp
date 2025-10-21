import 'dart:convert';
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

  // Check and execute schedules (should be called periodically)
  Future<void> checkAndExecuteSchedules() async {
    final schedules = await getSchedules();
    final now = DateTime.now();
    final currentDay = now.weekday; // 1=Mon, 7=Sun
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);

    for (var schedule in schedules) {
      if (schedule.enabled && schedule.days.contains(currentDay)) {
        // Check if current time matches schedule time (within 1 minute tolerance)
        if (schedule.time.hour == currentTime.hour &&
            (schedule.time.minute - currentTime.minute).abs() <= 1) {
          await _executeSchedule(schedule);
        }
      }
    }
  }

  Future<void> _executeSchedule(ScheduleItem schedule) async {
    switch (schedule.action) {
      case 'water':
        _mqttService.toggleWaterPump(true);
        await Future.delayed(Duration(seconds: schedule.duration));
        _mqttService.toggleWaterPump(false);
        
        await _notificationService.showCustomNotification(
          '💧 ${schedule.name}',
          'Water pump ran for ${schedule.duration} seconds',
        );
        break;

      case 'nutrient':
        _mqttService.toggleNutrientPump(true);
        await Future.delayed(Duration(seconds: schedule.duration));
        _mqttService.toggleNutrientPump(false);
        
        await _notificationService.showCustomNotification(
          '🥤 ${schedule.name}',
          'Nutrient pump ran for ${schedule.duration} seconds',
        );
        break;

      case 'notify':
        await _notificationService.showCustomNotification(
          '🔔 ${schedule.name}',
          'Scheduled reminder',
        );
        break;
    }
  }

  Future<void> clearAllSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySchedules);
  }
}
