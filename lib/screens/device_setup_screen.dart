import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/mqtt_service.dart';
import '../services/device_helper.dart';
import 'home_screen.dart';
import 'device_manager_screen.dart';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({Key? key}) : super(key: key);

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  List<Map<String, String>> _savedDevices = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedDevices();
  }

  Future<void> _loadSavedDevices() async {
    final devices = await DeviceHelper.getAllDevices();
    
    setState(() {
      _savedDevices = devices;
    });
  }

  Future<void> _connectToDevice(String deviceId, String deviceName) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate device ID format (8 characters hexadecimal)
      if (deviceId.length != 8) {
        throw Exception('Device ID harus 8 karakter');
      }
      
      final hexPattern = RegExp(r'^[0-9a-fA-F]+$');
      if (!hexPattern.hasMatch(deviceId)) {
        throw Exception('Device ID harus berupa hexadecimal (0-9, a-f)');
      }

      print('🔄 Connecting to device: $deviceId');
      
      // Use switchDevice method for clean connection
      final mqttService = MQTTService();
      await mqttService.switchDevice(deviceId.toLowerCase());
      
      // Wait a bit to check connection
      await Future.delayed(const Duration(seconds: 2));
      
      if (mqttService.isConnected) {
        // Save device using helper
        await DeviceHelper.saveDevice(
          deviceId.toLowerCase(), 
          deviceName.isEmpty ? 'Device $deviceId' : deviceName
        );
        
        print('✅ Successfully connected to device: $deviceId');
        
        // Navigate to home
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        throw Exception('Tidak dapat terhubung ke device');
      }
    } catch (e) {
      print('❌ Failed to connect: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Logo and Title
                Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
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
                        Icons.device_hub,
                        size: 50,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Setup Device ESP32',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Masukkan Device ID dari ESP32 Anda',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Input Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.glassDecoration,
                  child: Column(
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
                        controller: _deviceIdController,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 18,
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
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.memory,
                            color: AppTheme.primaryColor,
                          ),
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
                        controller: _deviceNameController,
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
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.label,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.errorColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.errorColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppTheme.errorColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_deviceIdController.text.isEmpty) {
                                  setState(() {
                                    _errorMessage = 'Device ID tidak boleh kosong';
                                  });
                                  return;
                                }
                                _connectToDevice(
                                  _deviceIdController.text,
                                  _deviceNameController.text,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Connect & Save',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                
                // Saved Devices Section
                if (_savedDevices.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Device Tersimpan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DeviceManagerScreen(),
                            ),
                          ).then((_) => _loadSavedDevices());
                        },
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('Kelola'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  ...List.generate(
                    _savedDevices.length > 3 ? 3 : _savedDevices.length,
                    (index) {
                      final device = _savedDevices[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: AppTheme.glassDecoration,
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryColor.withOpacity(0.2),
                            ),
                            child: const Icon(
                              Icons.router,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            device['name']!,
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            device['id']!,
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor.withOpacity(0.7),
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),
                          onTap: () {
                            _connectToDevice(device['id']!, device['name']!);
                          },
                        ),
                      );
                    },
                  ),
                  
                  if (_savedDevices.length > 3)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DeviceManagerScreen(),
                          ),
                        ).then((_) => _loadSavedDevices());
                      },
                      child: Text(
                        'Lihat semua (${_savedDevices.length} device)',
                        style: const TextStyle(color: AppTheme.primaryColor),
                      ),
                    ),
                ],
                
                const SizedBox(height: 32),
                
                // Help Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentColor.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.help_outline,
                            color: AppTheme.accentColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Cara mendapatkan Device ID:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '1. Buka Serial Monitor di Arduino IDE\n'
                        '2. Cari baris "Device ID: xxxxxxxx"\n'
                        '3. Copy 8 karakter hexadecimal tersebut\n'
                        '4. Paste di kolom Device ID di atas',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor.withOpacity(0.8),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }
}
