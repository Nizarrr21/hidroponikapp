import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/sensor_data.dart';
import '../services/mqtt_service.dart';
import '../widgets/sensor_card.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({Key? key}) : super(key: key);

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  final MQTTService _mqttService = MQTTService();
  SensorData _sensorData = SensorData.empty();
  
  bool _waterPumpOn = false;
  int _waterPumpSpeed = 50;
  bool _nutrientPumpOn = false;
  int _nutrientPumpSpeed = 30;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _mqttService.sensorDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _sensorData = data;
          _waterPumpOn = data.pumpStatus;
          _waterPumpSpeed = data.pumpSpeed;
          _nutrientPumpOn = data.nutrientPumpStatus;
          _nutrientPumpSpeed = data.nutrientPumpSpeed;
        });
      }
    });
  }

  void _toggleWaterPump() {
    setState(() {
      _waterPumpOn = !_waterPumpOn;
    });
    _mqttService.controlPump(_waterPumpOn, _waterPumpSpeed);
    _showSnackBar(
      _waterPumpOn ? 'Water pump turned ON' : 'Water pump turned OFF',
      _waterPumpOn ? AppTheme.successColor : AppTheme.warningColor,
    );
  }

  void _toggleNutrientPump() {
    setState(() {
      _nutrientPumpOn = !_nutrientPumpOn;
    });
    _mqttService.controlNutrientPump(_nutrientPumpOn, _nutrientPumpSpeed);
    _showSnackBar(
      _nutrientPumpOn ? 'Nutrient pump turned ON' : 'Nutrient pump turned OFF',
      _nutrientPumpOn ? AppTheme.successColor : AppTheme.warningColor,
    );
  }

  void _updateWaterSpeed(double speed) {
    setState(() {
      _waterPumpSpeed = speed.toInt();
    });
    if (_waterPumpOn) {
      _mqttService.controlPump(_waterPumpOn, _waterPumpSpeed);
    }
  }

  void _updateNutrientSpeed(double speed) {
    setState(() {
      _nutrientPumpSpeed = speed.toInt();
    });
    if (_nutrientPumpOn) {
      _mqttService.controlNutrientPump(_nutrientPumpOn, _nutrientPumpSpeed);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
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
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildAutoModeWarning(),
                    const SizedBox(height: 20),
                    const Text(
                      'Pump Control',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: 20),
                    PumpControlCard(
                      title: 'Water Pump',
                      icon: Icons.water,
                      isOn: _waterPumpOn,
                      speed: _waterPumpSpeed,
                      color: AppTheme.primaryColor,
                      onToggle: _toggleWaterPump,
                      onSpeedChanged: _updateWaterSpeed,
                    ),
                    const SizedBox(height: 16),
                    PumpControlCard(
                      title: 'Nutrient Pump',
                      icon: Icons.local_drink,
                      isOn: _nutrientPumpOn,
                      speed: _nutrientPumpSpeed,
                      color: AppTheme.secondaryColor,
                      onToggle: _toggleNutrientPump,
                      onSpeedChanged: _updateNutrientSpeed,
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Emergency Controls',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: 20),
                    _buildEmergencyButtons(),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Control Panel',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.secondaryColor.withOpacity(0.3),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutoModeWarning() {
    if (!_sensorData.autoMode) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warningColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.warningColor,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto Mode Active',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manual controls may be overridden by automation',
                  style: AppTheme.bodyStyle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButtons() {
    return Column(
      children: [
        _buildEmergencyButton(
          'Stop All Pumps',
          Icons.stop_circle,
          AppTheme.dangerColor,
          () {
            _mqttService.controlPump(false, 0);
            _mqttService.controlNutrientPump(false, 0);
            setState(() {
              _waterPumpOn = false;
              _nutrientPumpOn = false;
            });
            _showSnackBar('All pumps stopped!', AppTheme.dangerColor);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildEmergencyButton(
                'Max Water',
                Icons.speed,
                AppTheme.primaryColor,
                () {
                  _mqttService.controlPump(true, 100);
                  setState(() {
                    _waterPumpOn = true;
                    _waterPumpSpeed = 100;
                  });
                  _showSnackBar('Water pump at maximum speed!', AppTheme.primaryColor);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEmergencyButton(
                'Max Nutrient',
                Icons.speed,
                AppTheme.secondaryColor,
                () {
                  _mqttService.controlNutrientPump(true, 100);
                  setState(() {
                    _nutrientPumpOn = true;
                    _nutrientPumpSpeed = 100;
                  });
                  _showSnackBar('Nutrient pump at maximum speed!', AppTheme.secondaryColor);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmergencyButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}