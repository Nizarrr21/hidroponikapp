import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';

class DataStorageService {
  static final DataStorageService _instance = DataStorageService._internal();
  factory DataStorageService() => _instance;
  DataStorageService._internal();

  static const String _keyDataHistory = 'sensor_data_history';
  static const int _maxStorageItems = 1000; // Max 1000 data points

  Future<void> saveData(SensorData data) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getAll();
    
    // Add new data
    history.add(data);
    
    // Keep only recent data (limit storage)
    if (history.length > _maxStorageItems) {
      history.removeRange(0, history.length - _maxStorageItems);
    }
    
    // Convert to JSON and save
    final jsonList = history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_keyDataHistory, jsonList);
  }

  Future<List<SensorData>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_keyDataHistory) ?? [];
    
    return jsonList.map((jsonStr) {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SensorData.fromJson(json);
    }).toList();
  }

  Future<List<SensorData>> getDataByTimeRange(String range) async {
    final allData = await getAll();
    final now = DateTime.now();
    
    Duration duration;
    switch (range) {
      case '1h':
        duration = const Duration(hours: 1);
        break;
      case '6h':
        duration = const Duration(hours: 6);
        break;
      case '24h':
        duration = const Duration(hours: 24);
        break;
      case '7d':
        duration = const Duration(days: 7);
        break;
      default:
        duration = const Duration(hours: 1);
    }
    
    final cutoffTime = now.subtract(duration).millisecondsSinceEpoch;
    
    return allData.where((data) => data.timestamp >= cutoffTime).toList();
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDataHistory);
  }

  Future<SensorData?> getLatest() async {
    final allData = await getAll();
    return allData.isEmpty ? null : allData.last;
  }

  Future<Map<String, dynamic>> getStatistics(String timeRange) async {
    final data = await getDataByTimeRange(timeRange);
    
    if (data.isEmpty) {
      return {
        'count': 0,
        'avgTemp': 0.0,
        'avgTds': 0.0,
        'avgWater': 0.0,
        'minTemp': 0.0,
        'maxTemp': 0.0,
        'minTds': 0.0,
        'maxTds': 0.0,
        'minWater': 0.0,
        'maxWater': 0.0,
      };
    }
    
    final temps = data.map((e) => e.temperature).toList();
    final tds = data.map((e) => e.tds).toList();
    final water = data.map((e) => e.waterLevel).toList();
    
    return {
      'count': data.length,
      'avgTemp': temps.reduce((a, b) => a + b) / temps.length,
      'avgTds': tds.reduce((a, b) => a + b) / tds.length,
      'avgWater': water.reduce((a, b) => a + b) / water.length,
      'minTemp': temps.reduce((a, b) => a < b ? a : b),
      'maxTemp': temps.reduce((a, b) => a > b ? a : b),
      'minTds': tds.reduce((a, b) => a < b ? a : b),
      'maxTds': tds.reduce((a, b) => a > b ? a : b),
      'minWater': water.reduce((a, b) => a < b ? a : b),
      'maxWater': water.reduce((a, b) => a > b ? a : b),
    };
  }
}