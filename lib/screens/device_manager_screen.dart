import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/mqtt_service.dart';
import '../services/device_helper.dart';
import 'home_screen.dart';
import 'device_setup_screen.dart';

class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({Key? key}) : super(key: key);

  @override
  State<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen> {
  List<Map<String, String>> _savedDevices = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedDevices();
  }

  Future<void> _loadSavedDevices() async {
    setState(() => _isLoading = true);
    
    final devices = await DeviceHelper.getAllDevices();
    
    setState(() {
      _savedDevices = devices;
      _isLoading = false;
    });
  }

  Future<void> _deleteDevice(String deviceId) async {
    await DeviceHelper.deleteDevice(deviceId);
    
    setState(() {
      _savedDevices.removeWhere((d) => d['id'] == deviceId);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Device $deviceId dihapus'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Check if no devices left
    if (_savedDevices.isEmpty) {
      print('⚠️ All devices deleted, redirecting to device setup...');
      
      // Disconnect MQTT
      final mqttService = MQTTService();
      mqttService.disconnect();
      
      // Show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada device tersimpan, silakan tambah device baru'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Navigate to device setup after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DeviceSetupScreen()),
          (route) => false, // Remove all routes
        );
      }
    }
  }

  Future<void> _renameDevice(String deviceId, String oldName) async {
    final controller = TextEditingController(text: oldName);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Rename Device',
          style: TextStyle(color: AppTheme.textPrimaryColor),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimaryColor),
          decoration: InputDecoration(
            labelText: 'Nama Device',
            labelStyle: TextStyle(color: AppTheme.textSecondaryColor.withOpacity(0.7)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    
    if (newName != null && newName.isNotEmpty && newName != oldName) {
      await DeviceHelper.renameDevice(deviceId, newName);
      
      setState(() {
        final index = _savedDevices.indexWhere((d) => d['id'] == deviceId);
        if (index != -1) {
          _savedDevices[index]['name'] = newName;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device berhasil direname'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _connectToDevice(String deviceId, String deviceName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      print('🔄 Switching to device: $deviceId');
      
      final mqttService = MQTTService();
      
      // Use switchDevice method for clean transition
      await mqttService.switchDevice(deviceId.toLowerCase());
      
      await Future.delayed(const Duration(seconds: 2));
      
      if (mqttService.isConnected) {
        // Save as last used device
        await DeviceHelper.saveDevice(deviceId, deviceName);
        
        print('✅ Successfully switched to device: $deviceId');
        
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        throw Exception('Tidak dapat terhubung ke device');
      }
    } catch (e) {
      print('❌ Failed to switch device: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal connect: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(String deviceId, String deviceName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Hapus Device?',
          style: TextStyle(color: AppTheme.textPrimaryColor),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "$deviceName"?',
          style: const TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDevice(deviceId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showAddDeviceDialog() {
    final deviceIdController = TextEditingController();
    final deviceNameController = TextEditingController();
    String? errorMessage;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: Row(
              children: const [
                Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                SizedBox(width: 12),
                Text(
                  'Tambah Device Baru',
                  style: TextStyle(color: AppTheme.textPrimaryColor, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device ID',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: deviceIdController,
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'a1b2c3d4',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondaryColor.withOpacity(0.3),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      prefixIcon: const Icon(
                        Icons.memory,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      counterText: '',
                    ),
                    maxLength: 8,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nama Device (Opsional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: deviceNameController,
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Hidroponik Rumah',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondaryColor.withOpacity(0.3),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      prefixIcon: const Icon(
                        Icons.label,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final deviceId = deviceIdController.text.trim();
                        final deviceName = deviceNameController.text.trim();

                        // Validate
                        if (deviceId.isEmpty) {
                          setDialogState(() {
                            errorMessage = 'Device ID tidak boleh kosong';
                          });
                          return;
                        }

                        if (deviceId.length != 8) {
                          setDialogState(() {
                            errorMessage = 'Device ID harus 8 karakter';
                          });
                          return;
                        }

                        final hexPattern = RegExp(r'^[0-9a-fA-F]+$');
                        if (!hexPattern.hasMatch(deviceId)) {
                          setDialogState(() {
                            errorMessage = 'Device ID harus hexadecimal (0-9, a-f)';
                          });
                          return;
                        }

                        // Start loading
                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });

                        try {
                          print('🔄 Adding new device: $deviceId');

                          final mqttService = MQTTService();
                          await mqttService.switchDevice(deviceId.toLowerCase());
                          await Future.delayed(const Duration(seconds: 2));

                          if (mqttService.isConnected) {
                            // Save device
                            await DeviceHelper.saveDevice(
                              deviceId.toLowerCase(),
                              deviceName.isEmpty ? 'Device $deviceId' : deviceName,
                            );

                            print('✅ Device added successfully: $deviceId');

                            // Reload devices
                            await _loadSavedDevices();

                            if (context.mounted) {
                              Navigator.pop(context); // Close dialog

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Device $deviceId berhasil ditambahkan'),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // Navigate to home with new device
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => const HomeScreen()),
                              );
                            }
                          } else {
                            throw Exception('Tidak dapat terhubung ke device');
                          }
                        } catch (e) {
                          print('❌ Failed to add device: $e');
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Tambah & Connect'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Kelola Device',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    // Add New Device Button
                    IconButton(
                      onPressed: _showAddDeviceDialog,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      tooltip: 'Tambah Device Baru',
                    ),
                  ],
                ),
              ),
              
              // Device List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _savedDevices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.devices_other,
                                  size: 80,
                                  color: AppTheme.textSecondaryColor.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada device tersimpan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textSecondaryColor.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _showAddDeviceDialog,
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: const Text('Tambah Device Pertama'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _savedDevices.length,
                            itemBuilder: (context, index) {
                              final device = _savedDevices[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: AppTheme.glassDecoration,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.primaryColor.withOpacity(0.3),
                                          AppTheme.secondaryColor.withOpacity(0.3),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.router,
                                      color: AppTheme.primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    device['name']!,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    device['id']!,
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor.withOpacity(0.7),
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                    color: const Color(0xFF1E1E2E),
                                    onSelected: (value) {
                                      if (value == 'rename') {
                                        _renameDevice(device['id']!, device['name']!);
                                      } else if (value == 'delete') {
                                        _showDeleteConfirmation(device['id']!, device['name']!);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'rename',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 18, color: AppTheme.primaryColor),
                                            SizedBox(width: 12),
                                            Text(
                                              'Rename',
                                              style: TextStyle(color: AppTheme.textPrimaryColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 18, color: Colors.red),
                                            SizedBox(width: 12),
                                            Text(
                                              'Hapus',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    _connectToDevice(device['id']!, device['name']!);
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _savedDevices.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddDeviceDialog,
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Tambah Device',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}
