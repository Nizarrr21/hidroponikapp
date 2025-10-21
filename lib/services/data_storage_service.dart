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
    print('💾 Saving sensor data: ${history.length} total points');
    
    // Keep only recent data (limit storage)
    if (history.length > _maxStorageItems) {
      history.removeRange(0, history.length - _maxStorageItems);
      print('🗑️ Trimmed to ${history.length} points');
    }
    
    // Convert to JSON and save
    final jsonList = history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_keyDataHistory, jsonList);
    print('✅ Data saved successfully');
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
    print('📊 getDataByTimeRange($range): Total data points = ${allData.length}');
    
    final now = DateTime.now();
    
    Duration duration;
    int samplingInterval; // in seconds
    
    switch (range) {
      case '1h':
        duration = const Duration(hours: 1);
        samplingInterval = 1; // Every 1 second
        break;
      case '6h':
        duration = const Duration(hours: 6);
        samplingInterval = 60; // Every 1 minute
        break;
      case '24h':
        duration = const Duration(hours: 24);
        samplingInterval = 3600; // Every 1 hour (average)
        break;
      case '7d':
        duration = const Duration(days: 7);
        samplingInterval = 86400; // Every 1 day (average)
        break;
      default:
        duration = const Duration(hours: 1);
        samplingInterval = 1;
    }
    
    final cutoffTime = now.subtract(duration).millisecondsSinceEpoch;
    final filteredData = allData.where((data) => data.timestamp >= cutoffTime).toList();
    
    print('📊 Filtered to ${filteredData.length} points within $range range');
    
    // Apply sampling based on range
    final sampledData = _sampleData(filteredData, samplingInterval, range);
    print('📊 After sampling: ${sampledData.length} points');
    
    return sampledData;
  }

  List<SensorData> _sampleData(List<SensorData> data, int intervalSeconds, String range) {
    if (data.isEmpty) return data;
    
    // For 1h, return all data points (every second)
    if (range == '1h') {
      return data;
    }
    
    // For other ranges, group by interval and average
    final sampledData = <SensorData>[];
    
    if (range == '6h') {
      // Group by minute, take one sample per minute
      for (int i = 0; i < data.length; i++) {
        if (i == 0 || 
            (data[i].timestamp - data[i - 1].timestamp) >= 60000) { // 1 minute
          sampledData.add(data[i]);
        }
      }
    } else if (range == '24h') {
      // Group by hour, calculate average per hour
      final Map<int, List<SensorData>> hourlyGroups = {};
      
      for (var item in data) {
        final hourKey = (item.timestamp / 3600000).floor(); // Group by hour
        hourlyGroups.putIfAbsent(hourKey, () => []).add(item);
      }
      
      // Calculate average for each hour
      for (var entry in hourlyGroups.entries) {
        final group = entry.value;
        if (group.isNotEmpty) {
          final avgTemp = group.map((e) => e.temperature).reduce((a, b) => a + b) / group.length;
          final avgTds = group.map((e) => e.tds).reduce((a, b) => a + b) / group.length;
          final avgWater = group.map((e) => e.waterLevel).reduce((a, b) => a + b) / group.length;
          
          sampledData.add(SensorData(
            temperature: avgTemp,
            tds: avgTds,
            waterLevel: avgWater,
            pumpStatus: group.last.pumpStatus,
            nutrientPumpStatus: group.last.nutrientPumpStatus,
            pumpSpeed: group.last.pumpSpeed,
            nutrientPumpSpeed: group.last.nutrientPumpSpeed,
            autoMode: group.last.autoMode,
            systemUptime: group.last.systemUptime,
            calibrationFactor: group.last.calibrationFactor,
            timestamp: group.first.timestamp,
          ));
        }
      }
    } else if (range == '7d') {
      // Group by day, calculate average per day
      final Map<int, List<SensorData>> dailyGroups = {};
      
      for (var item in data) {
        final dayKey = (item.timestamp / 86400000).floor(); // Group by day
        dailyGroups.putIfAbsent(dayKey, () => []).add(item);
      }
      
      // Calculate average for each day
      for (var entry in dailyGroups.entries) {
        final group = entry.value;
        if (group.isNotEmpty) {
          final avgTemp = group.map((e) => e.temperature).reduce((a, b) => a + b) / group.length;
          final avgTds = group.map((e) => e.tds).reduce((a, b) => a + b) / group.length;
          final avgWater = group.map((e) => e.waterLevel).reduce((a, b) => a + b) / group.length;
          
          sampledData.add(SensorData(
            temperature: avgTemp,
            tds: avgTds,
            waterLevel: avgWater,
            pumpStatus: group.last.pumpStatus,
            nutrientPumpStatus: group.last.nutrientPumpStatus,
            pumpSpeed: group.last.pumpSpeed,
            nutrientPumpSpeed: group.last.nutrientPumpSpeed,
            autoMode: group.last.autoMode,
            systemUptime: group.last.systemUptime,
            calibrationFactor: group.last.calibrationFactor,
            timestamp: group.first.timestamp,
          ));
        }
      }
    }
    
    return sampledData.isEmpty ? data : sampledData;
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