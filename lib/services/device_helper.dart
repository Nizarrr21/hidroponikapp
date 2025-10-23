import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/device_setup_screen.dart';

class DeviceHelper {
  static const String _keyDevices = 'saved_devices';
  static const String _keyLastDeviceId = 'last_device_id';

  /// Check if there are any saved devices
  /// Returns true if devices exist, false otherwise
  static Future<bool> hasDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devices = prefs.getStringList(_keyDevices) ?? [];
    return devices.isNotEmpty;
  }

  /// Check device availability and redirect to setup if none found
  /// Returns true if devices exist, false if redirected to setup
  static Future<bool> checkAndRedirectIfNoDevices(BuildContext context) async {
    if (!context.mounted) return false;
    
    final hasDevice = await hasDevices();
    
    if (!hasDevice) {
      print('⚠️ No devices saved, redirecting to device setup...');
      
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DeviceSetupScreen()),
          (route) => false, // Remove all routes
        );
      }
      return false;
    }
    
    return true;
  }

  /// Get the last used device ID
  static Future<String?> getLastDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastDeviceId);
  }

  /// Get all saved devices
  static Future<List<Map<String, String>>> getAllDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getStringList(_keyDevices) ?? [];
    
    return devicesJson.map((json) {
      final parts = json.split('|');
      return {
        'id': parts[0],
        'name': parts.length > 1 ? parts[1] : 'Device ${parts[0]}',
      };
    }).toList();
  }

  /// Save a new device
  static Future<void> saveDevice(String deviceId, String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    final devices = await getAllDevices();
    
    // Check if device already exists
    final exists = devices.any((d) => d['id'] == deviceId);
    if (!exists) {
      devices.add({'id': deviceId, 'name': deviceName});
      
      final devicesJson = devices.map((d) => '${d['id']}|${d['name']}').toList();
      await prefs.setStringList(_keyDevices, devicesJson);
    }
    
    // Save as last used device
    await prefs.setString(_keyLastDeviceId, deviceId);
  }

  /// Delete a device
  static Future<void> deleteDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final devices = await getAllDevices();
    
    devices.removeWhere((d) => d['id'] == deviceId);
    
    final devicesJson = devices.map((d) => '${d['id']}|${d['name']}').toList();
    await prefs.setStringList(_keyDevices, devicesJson);
    
    // If this was the last used device, clear it
    final lastDeviceId = await getLastDeviceId();
    if (lastDeviceId == deviceId) {
      await prefs.remove(_keyLastDeviceId);
    }
  }

  /// Rename a device
  static Future<void> renameDevice(String deviceId, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final devices = await getAllDevices();
    
    final index = devices.indexWhere((d) => d['id'] == deviceId);
    if (index != -1) {
      devices[index]['name'] = newName;
      
      final devicesJson = devices.map((d) => '${d['id']}|${d['name']}').toList();
      await prefs.setStringList(_keyDevices, devicesJson);
    }
  }

  /// Clear all devices (for logout/reset)
  static Future<void> clearAllDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDevices);
    await prefs.remove(_keyLastDeviceId);
  }
}
