import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../models/sensor_data.dart';
import '../services/mqtt_service.dart';
import '../services/notification_service.dart';
import '../services/data_storage_service.dart';
import '../services/plant_settings_service.dart';
import '../widgets/sensor_card.dart';
import 'settings_screen.dart';
import 'control_screen.dart';
import 'chart_screen.dart';
import 'schedule_screen.dart';
import 'plant_data_screen.dart';

class StatusIndicator extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final IconData? icon;

  const StatusIndicator({
    Key? key,
    required this.label,
    required this.isActive,
    required this.activeColor,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (icon != null)
          Icon(
            icon,
            size: 20,
            color: isActive ? activeColor : Colors.grey,
          )
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? activeColor : Colors.grey,
              boxShadow: [
                BoxShadow(
                  color: isActive ? activeColor.withOpacity(0.5) : Colors.transparent,
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? activeColor : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final MQTTService _mqttService = MQTTService();
  final NotificationService _notificationService = NotificationService();
  final DataStorageService _storageService = DataStorageService();
  
  SensorData _sensorData = SensorData.empty();
  bool _isConnected = false;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Notification toggle states
  bool _tempAlertsEnabled = true;
  bool _tdsAlertsEnabled = true;
  bool _waterAlertsEnabled = true;
  bool _pumpStatusEnabled = true;
  
  // Loading states for toggles
  bool _tempToggleLoading = false;
  bool _tdsToggleLoading = false;
  bool _waterToggleLoading = false;
  bool _pumpToggleLoading = false;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _initializeServices();
    _connectToMQTT();
    _setupListeners();
  }

  void _initAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _initializeServices() async {
    await _notificationService.initialize();
    _loadNotificationStates();
  }

  void _loadNotificationStates() {
    setState(() {
      _tempAlertsEnabled = _notificationService.temperatureAlertsEnabled;
      _tdsAlertsEnabled = _notificationService.tdsAlertsEnabled;
      _waterAlertsEnabled = _notificationService.waterLevelAlertsEnabled;
      _pumpStatusEnabled = _notificationService.pumpStatusAlertsEnabled;
    });
  }

  Future<void> _connectToMQTT() async {
    try {
      await _mqttService.connect();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to connect: $e');
    }
  }

  void _setupListeners() {
    _mqttService.sensorDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _sensorData = data;
        });
        
        // Save data for charts
        _storageService.saveData(data);
        
        // Check for alerts
        _notificationService.checkAndNotify(data);
      }
    });

    _mqttService.connectionStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isConnected = status;
        });
        
        // Show notification on connection change
        if (status) {
          _notificationService.showCustomNotification(
            'Connected',
            '✅ Successfully connected to hydroponic system',
          );
        }
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.dangerColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _getSensorStatus(double value, double min, double max) {
    if (value < min) return 'Low';
    if (value > max) return 'High';
    return 'Normal';
  }

  Future<void> _toggleAutoMode() async {
    final newMode = !_sensorData.autoMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              newMode ? Icons.auto_mode : Icons.pan_tool,
              color: newMode ? AppTheme.successColor : AppTheme.warningColor,
            ),
            const SizedBox(width: 12),
            Text(newMode ? 'Enable Auto Mode?' : 'Disable Auto Mode?'),
          ],
        ),
        content: Text(
          newMode
              ? 'Sistem akan otomatis mengatur nutrisi dan air berdasarkan sensor TDS dan water level.'
              : 'Anda perlu mengontrol nutrisi dan air secara manual.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newMode ? AppTheme.successColor : AppTheme.warningColor,
            ),
            child: Text(newMode ? 'Enable' : 'Disable'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      _mqttService.toggleAutoMode(newMode);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newMode ? Icons.auto_mode : Icons.pan_tool,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(newMode ? 'Auto Mode Enabled' : 'Manual Mode Enabled'),
              ],
            ),
            backgroundColor: newMode ? AppTheme.successColor : AppTheme.warningColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
          child: _isLoading
              ? _buildLoadingScreen()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildMainContent(),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Connecting to device...',
            style: AppTheme.bodyStyle.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: () async {
        _mqttService.requestData();
        await Future.delayed(const Duration(seconds: 1));
      },
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.cardColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatusCard(),
                const SizedBox(height: 20),
                _buildSensorCards(),
                const SizedBox(height: 20),
                _buildPlantInfoCard(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 20),
                _buildFeatureGrid(),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Hydroponic Monitor',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.3),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            // Show notification settings
            _showNotificationSettings();
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _mqttService.requestData(),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Container(
      decoration: AppTheme.glassDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatusIndicator(
                label: 'MQTT',
                isActive: _isConnected,
                activeColor: AppTheme.successColor,
              ),
              StatusIndicator(
                label: _sensorData.autoMode ? 'AUTO' : 'MANUAL',
                isActive: _sensorData.autoMode,
                activeColor: AppTheme.primaryColor,
              ),
              StatusIndicator(
                label: 'System',
                isActive: _isConnected,
                activeColor: AppTheme.secondaryColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatusIndicator(
                label: 'Nutrient',
                isActive: _sensorData.nutrientPumpStatus,
                activeColor: AppTheme.secondaryColor,
                icon: Icons.water_drop,
              ),
              StatusIndicator(
                label: 'Water',
                isActive: _sensorData.pumpStatus,
                activeColor: AppTheme.accentColor,
                icon: Icons.local_drink,
              ),
              StatusIndicator(
                label: 'TDS OK',
                isActive: _sensorData.tds >= 700 && _sensorData.tds <= 900,
                activeColor: AppTheme.successColor,
                icon: Icons.check_circle,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                Icons.access_time,
                'Uptime',
                _formatUptime(_sensorData.systemUptime),
              ),
              _buildInfoItem(
                Icons.speed,
                'Water',
                _sensorData.pumpStatus ? '${_sensorData.pumpSpeed}%' : 'OFF',
              ),
              _buildInfoItem(
                Icons.local_drink,
                'Nutrient',
                _sensorData.nutrientPumpStatus
                    ? '${_sensorData.nutrientPumpSpeed}%'
                    : 'OFF',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTheme.labelStyle.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSensorCards() {
    return Column(
      children: [
        SensorCard(
          title: 'Temperature',
          value: _sensorData.temperature.toStringAsFixed(1),
          unit: '°C',
          icon: Icons.thermostat,
          color: AppTheme.accentColor,
          progress: (_sensorData.temperature / 40 * 100).clamp(0, 100),
          status: _getSensorStatus(_sensorData.temperature, 20, 30),
        ),
        const SizedBox(height: 16),
        SensorCard(
          title: 'TDS Level',
          value: _sensorData.tds.toStringAsFixed(0),
          unit: 'ppm',
          icon: Icons.water_drop,
          color: AppTheme.secondaryColor,
          progress: (_sensorData.tds / 1500 * 100).clamp(0, 100),
          status: _getSensorStatus(_sensorData.tds, 600, 1000),
        ),
        const SizedBox(height: 16),
        SensorCard(
          title: 'Water Level',
          value: _sensorData.waterLevel.toStringAsFixed(0),
          unit: '%',
          icon: Icons.waves,
          color: AppTheme.primaryColor,
          progress: _sensorData.waterLevel,
          status: _getSensorStatus(_sensorData.waterLevel, 30, 80),
        ),
      ],
    );
  }

  Widget _buildPlantInfoCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: PlantSettingsService.getPlantRecommendations(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final plantInfo = snapshot.data!;
        final isCustom = plantInfo['isCustom'] as bool;
        
        if (isCustom) {
          return const SizedBox.shrink(); // Don't show for custom settings
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: PlantSettingsService.analyzeTdsStatus(_sensorData.tds),
          builder: (context, tdsSnapshot) {
            final tdsAnalysis = tdsSnapshot.data;
            
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration.copyWith(
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plantInfo['icon'],
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tanaman Aktif',
                              style: AppTheme.labelStyle,
                            ),
                            Text(
                              '${plantInfo['plantName']} (${plantInfo['plantNameEn']})',
                              style: AppTheme.bodyStyle.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PlantDataScreen(),
                            ),
                          ).then((_) => setState(() {})); // Refresh when coming back
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildPlantInfoItem(
                          'Target PPM',
                          plantInfo['ppmRange'],
                          Icons.water_drop,
                          AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPlantInfoItem(
                          'Masa Panen',
                          plantInfo['harvestTime'],
                          Icons.schedule,
                          AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                  
                  if (tdsAnalysis != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(int.parse('0xFF${tdsAnalysis['color']}')).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(int.parse('0xFF${tdsAnalysis['color']}')).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tdsAnalysis['isOptimal'] ? Icons.check_circle : Icons.warning,
                            color: Color(int.parse('0xFF${tdsAnalysis['color']}')),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status TDS: ${tdsAnalysis['status']}',
                                  style: AppTheme.bodyStyle.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Color(int.parse('0xFF${tdsAnalysis['color']}')),
                                  ),
                                ),
                                Text(
                                  tdsAnalysis['recommendation'],
                                  style: AppTheme.labelStyle.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlantInfoItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.labelStyle.copyWith(
                  fontSize: 11,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: AppTheme.subheadingStyle,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Control',
                Icons.tune,
                AppTheme.primaryColor,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ControlScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Auto Mode',
                _sensorData.autoMode ? Icons.auto_mode : Icons.pan_tool,
                _sensorData.autoMode ? AppTheme.successColor : AppTheme.warningColor,
                () => _toggleAutoMode(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Manual Control Buttons (only show when not in auto mode)
        if (!_sensorData.autoMode) ...[
          Row(
            children: [
              Expanded(
                child: _buildManualControlButton(
                  'Nutrient',
                  Icons.water_drop,
                  AppTheme.secondaryColor,
                  _sensorData.nutrientPumpStatus,
                  () => _mqttService.toggleNutrientPump(!_sensorData.nutrientPumpStatus),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildManualControlButton(
                  'Water',
                  Icons.local_drink,
                  AppTheme.accentColor,
                  _sensorData.pumpStatus,
                  () => _mqttService.toggleWaterPump(!_sensorData.pumpStatus),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildManualControlButton(
    String label,
    IconData icon,
    Color color,
    bool isActive,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.2) : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? color : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isActive ? color : AppTheme.textSecondaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isActive ? color : AppTheme.textPrimaryColor,
                      ),
                    ),
                    Text(
                      isActive ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? color : AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Features',
          style: AppTheme.subheadingStyle,
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildFeatureCard(
              'Charts',
              Icons.show_chart,
              AppTheme.accentColor,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChartScreen()),
                );
              },
            ),
            _buildFeatureCard(
              'Schedule',
              Icons.schedule,
              AppTheme.secondaryColor,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScheduleScreen()),
                );
              },
            ),
            _buildFeatureCard(
              'Plant Data',
              Icons.eco,
              AppTheme.successColor,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PlantDataScreen()),
                );
              },
            ),
            _buildFeatureCard(
              'Settings',
              Icons.settings,
              AppTheme.warningColor,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.6), color.withOpacity(0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleNotificationToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool currentValue,
    required VoidCallback onConfirm,
  }) async {
    final shouldToggle = await _showNotificationToggleDialog(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      currentValue: currentValue,
    );
    
    if (shouldToggle == true) {
      onConfirm();
    }
  }

  Future<bool?> _showNotificationToggleDialog({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool currentValue,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  currentValue ? 'Disable $title?' : 'Enable $title?',
                  style: AppTheme.subheadingStyle.copyWith(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: AppTheme.bodyStyle,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: currentValue 
                    ? AppTheme.warningColor.withOpacity(0.1)
                    : AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: currentValue 
                      ? AppTheme.warningColor.withOpacity(0.3)
                      : AppTheme.successColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      currentValue ? Icons.notifications_off : Icons.notifications_active,
                      color: currentValue ? AppTheme.warningColor : AppTheme.successColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentValue 
                          ? 'You will no longer receive these notifications'
                          : 'You will start receiving these notifications',
                        style: TextStyle(
                          fontSize: 12,
                          color: currentValue ? AppTheme.warningColor : AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                currentValue ? 'Disable' : 'Enable',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Notification Settings',
                  style: AppTheme.subheadingStyle,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildNotificationTile(
              'Temperature Alerts',
              'Get notified when temperature is out of range',
              Icons.thermostat,
              AppTheme.accentColor,
              _tempAlertsEnabled,
              _tempToggleLoading,
              () => _handleNotificationToggle(
                title: 'Temperature Alerts',
                subtitle: 'Get notified when temperature is out of range',
                icon: Icons.thermostat,
                color: AppTheme.accentColor,
                currentValue: _tempAlertsEnabled,
                onConfirm: () async {
                  setState(() => _tempToggleLoading = true);
                  await _notificationService.setTemperatureAlertsEnabled(!_tempAlertsEnabled);
                  setState(() {
                    _tempAlertsEnabled = !_tempAlertsEnabled;
                    _tempToggleLoading = false;
                  });
                },
              ),
            ),
            _buildNotificationTile(
              'TDS Alerts',
              'Get notified when TDS level needs attention',
              Icons.water_drop,
              AppTheme.secondaryColor,
              _tdsAlertsEnabled,
              _tdsToggleLoading,
              () => _handleNotificationToggle(
                title: 'TDS Alerts',
                subtitle: 'Get notified when TDS level needs attention',
                icon: Icons.water_drop,
                color: AppTheme.secondaryColor,
                currentValue: _tdsAlertsEnabled,
                onConfirm: () async {
                  setState(() => _tdsToggleLoading = true);
                  await _notificationService.setTdsAlertsEnabled(!_tdsAlertsEnabled);
                  setState(() {
                    _tdsAlertsEnabled = !_tdsAlertsEnabled;
                    _tdsToggleLoading = false;
                  });
                },
              ),
            ),
            _buildNotificationTile(
              'Water Level Alerts',
              'Get notified about water level changes',
              Icons.waves,
              AppTheme.primaryColor,
              _waterAlertsEnabled,
              _waterToggleLoading,
              () => _handleNotificationToggle(
                title: 'Water Level Alerts',
                subtitle: 'Get notified about water level changes',
                icon: Icons.waves,
                color: AppTheme.primaryColor,
                currentValue: _waterAlertsEnabled,
                onConfirm: () async {
                  setState(() => _waterToggleLoading = true);
                  await _notificationService.setWaterLevelAlertsEnabled(!_waterAlertsEnabled);
                  setState(() {
                    _waterAlertsEnabled = !_waterAlertsEnabled;
                    _waterToggleLoading = false;
                  });
                },
              ),
            ),
            _buildNotificationTile(
              'Pump Status',
              'Get notified when pumps start or stop',
              Icons.power,
              AppTheme.warningColor,
              _pumpStatusEnabled,
              _pumpToggleLoading,
              () => _handleNotificationToggle(
                title: 'Pump Status',
                subtitle: 'Get notified when pumps start or stop',
                icon: Icons.power,
                color: AppTheme.warningColor,
                currentValue: _pumpStatusEnabled,
                onConfirm: () async {
                  setState(() => _pumpToggleLoading = true);
                  await _notificationService.setPumpStatusAlertsEnabled(!_pumpStatusEnabled);
                  setState(() {
                    _pumpStatusEnabled = !_pumpStatusEnabled;
                    _pumpToggleLoading = false;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(
    String title, 
    String subtitle, 
    IconData icon, 
    Color color, 
    bool value,
    bool isLoading,
    VoidCallback onTap,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isLoading ? color.withOpacity(0.1) : Colors.transparent,
        border: isLoading ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: ListTile(
        leading: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoading 
            ? SizedBox(
                width: 24,
                height: 24,
                key: const ValueKey('loading'),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Icon(
                icon, 
                color: color,
                key: const ValueKey('icon'),
              ),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(subtitle, style: AppTheme.labelStyle),
        trailing: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoading
            ? Container(
                key: const ValueKey('loading-switch'),
                width: 51,
                height: 31,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: color.withOpacity(0.3),
                ),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
                ),
              )
            : Switch(
                key: const ValueKey('switch'),
                value: value,
                onChanged: isLoading ? null : (_) => onTap(),
                activeColor: color,
              ),
        ),
        onTap: isLoading ? null : onTap,
      ),
    );
  }

  String _formatUptime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}