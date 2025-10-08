import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/mqtt_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final MQTTService _mqttService = MQTTService();
  late TextEditingController _targetTdsController;
  late TextEditingController _tdsThresholdController;
  late TextEditingController _minWaterController;
  late TextEditingController _maxWaterController;
  late TextEditingController _nutrientOnTimeController;
  late TextEditingController _nutrientOffTimeController;
  late TextEditingController _waterOnTimeController;
  late TextEditingController _calibrationTdsController;

  bool _isAutoMode = false;
  int _autoNutrientSpeed = 30;
  int _autoWaterSpeed = 50;
  double _currentCalibrationFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupListeners();
    _mqttService.requestData();
  }

  void _initializeControllers() {
    _targetTdsController = TextEditingController(text: '800');
    _tdsThresholdController = TextEditingController(text: '50');
    _minWaterController = TextEditingController(text: '20');
    _maxWaterController = TextEditingController(text: '80');
    _nutrientOnTimeController = TextEditingController(text: '5');
    _nutrientOffTimeController = TextEditingController(text: '30');
    _waterOnTimeController = TextEditingController(text: '10');
    _calibrationTdsController = TextEditingController(text: '1000');
  }

  void _setupListeners() {
    _mqttService.autoModeSettingsStream.listen((settings) {
      if (mounted) {
        setState(() {
          _isAutoMode = settings.autoMode;
          _autoNutrientSpeed = settings.autoNutrientSpeed;
          _autoWaterSpeed = settings.autoWaterSpeed;
          
          _targetTdsController.text = settings.targetTds.toStringAsFixed(0);
          _tdsThresholdController.text = settings.tdsThreshold.toStringAsFixed(0);
          _minWaterController.text = settings.minWaterLevel.toStringAsFixed(0);
          _maxWaterController.text = settings.maxWaterLevel.toStringAsFixed(0);
          _nutrientOnTimeController.text = (settings.nutrientOnTime / 1000).toStringAsFixed(0);
          _nutrientOffTimeController.text = (settings.nutrientOffTime / 1000).toStringAsFixed(0);
          _waterOnTimeController.text = (settings.waterOnTime / 1000).toStringAsFixed(0);
        });
      }
    });

    _mqttService.sensorDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentCalibrationFactor = data.calibrationFactor;
        });
      }
    });
  }

  void _calibrateTDS() {
    final calibrationValue = double.tryParse(_calibrationTdsController.text);
    if (calibrationValue == null || calibrationValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Please enter a valid TDS value'),
            ],
          ),
          backgroundColor: AppTheme.dangerColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _mqttService.calibrateTDS(calibrationValue);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.science, color: Colors.white),
            SizedBox(width: 12),
            Text('Calibration in progress...'),
          ],
        ),
        backgroundColor: AppTheme.secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveSettings() {
    final settings = {
      'auto': _isAutoMode,
      'target_tds': double.tryParse(_targetTdsController.text) ?? 800.0,
      'tds_threshold': double.tryParse(_tdsThresholdController.text) ?? 50.0,
      'min_water_level': double.tryParse(_minWaterController.text) ?? 20.0,
      'max_water_level': double.tryParse(_maxWaterController.text) ?? 80.0,
      'nutrient_on_time': (int.tryParse(_nutrientOnTimeController.text) ?? 5) * 1000,
      'nutrient_off_time': (int.tryParse(_nutrientOffTimeController.text) ?? 30) * 1000,
      'water_on_time': (int.tryParse(_waterOnTimeController.text) ?? 10) * 1000,
      'auto_nutrient_speed': _autoNutrientSpeed,
      'auto_water_speed': _autoWaterSpeed,
      'calibration_factor': _currentCalibrationFactor,
    };

    _mqttService.updateSettings(settings);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Settings saved successfully!'),
          ],
        ),
        backgroundColor: AppTheme.successColor,
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
                    _buildAutoModeCard(),
                    const SizedBox(height: 24),
                    const Text(
                      'Target Settings',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: 16),
                    _buildTargetSettings(),
                    const SizedBox(height: 24),
                    const Text(
                      'Automation Timing',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: 16),
                    _buildTimingSettings(),
                    const SizedBox(height: 24),
                    const Text(
                      'Auto Speed Control',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: 16),
                    _buildSpeedSettings(),
                    const SizedBox(height: 24),
                    const Text(
                      'TDS Calibration',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: 16),
                    _buildTDSCalibration(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                    const SizedBox(height: 40),
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
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accentColor.withOpacity(0.3),
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

  Widget _buildAutoModeCard() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isAutoMode
                      ? AppTheme.successColor.withOpacity(0.2)
                      : AppTheme.warningColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isAutoMode ? Icons.auto_mode : Icons.pan_tool,
                  color: _isAutoMode ? AppTheme.successColor : AppTheme.warningColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Automation Mode',
                      style: AppTheme.subheadingStyle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isAutoMode
                          ? 'System will automatically control pumps'
                          : 'Manual control only',
                      style: AppTheme.bodyStyle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.1,
                child: Switch(
                  value: _isAutoMode,
                  onChanged: (value) {
                    setState(() {
                      _isAutoMode = value;
                    });
                  },
                  activeColor: AppTheme.successColor,
                  activeTrackColor: AppTheme.successColor.withOpacity(0.5),
                ),
              ),
            ],
          ),
          if (_isAutoMode) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pumps will activate based on sensor readings and configured settings',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetSettings() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSettingField(
            'Target TDS',
            _targetTdsController,
            'ppm',
            Icons.water_drop,
            AppTheme.secondaryColor,
          ),
          const SizedBox(height: 16),
          _buildSettingField(
            'TDS Threshold',
            _tdsThresholdController,
            'ppm',
            Icons.tune,
            AppTheme.secondaryColor,
          ),
          const SizedBox(height: 16),
          _buildSettingField(
            'Min Water Level',
            _minWaterController,
            '%',
            Icons.arrow_downward,
            AppTheme.warningColor,
          ),
          const SizedBox(height: 16),
          _buildSettingField(
            'Max Water Level',
            _maxWaterController,
            '%',
            Icons.arrow_upward,
            AppTheme.successColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTimingSettings() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSettingField(
            'Nutrient Pump ON Time',
            _nutrientOnTimeController,
            'seconds',
            Icons.timer,
            AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          _buildSettingField(
            'Nutrient Pump OFF Time',
            _nutrientOffTimeController,
            'seconds',
            Icons.timer_off,
            AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          _buildSettingField(
            'Water Pump ON Time',
            _waterOnTimeController,
            'seconds',
            Icons.timer,
            AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedSettings() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSpeedSlider(
            'Nutrient Pump Speed',
            _autoNutrientSpeed,
            AppTheme.secondaryColor,
            Icons.local_drink,
            (value) {
              setState(() {
                _autoNutrientSpeed = value.toInt();
              });
            },
          ),
          const SizedBox(height: 20),
          _buildSpeedSlider(
            'Water Pump Speed',
            _autoWaterSpeed,
            AppTheme.primaryColor,
            Icons.water,
            (value) {
              setState(() {
                _autoWaterSpeed = value.toInt();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingField(
    String label,
    TextEditingController controller,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            suffixText: unit,
            suffixStyle: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedSlider(
    String label,
    int value,
    Color color,
    IconData icon,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTheme.bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Text(
                '$value%',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.save, size: 24),
            SizedBox(width: 12),
            Text(
              'Save Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTDSCalibration() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.science,
                  color: AppTheme.secondaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TDS Calibration',
                      style: AppTheme.subheadingStyle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Calibrate TDS sensor with a reference solution',
                      style: AppTheme.bodyStyle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.secondaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights,
                      color: AppTheme.secondaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Calibration Factor: ${_currentCalibrationFactor.toStringAsFixed(3)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
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
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'How to calibrate TDS sensor:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Clean the TDS sensor with distilled water',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '2. Place sensor in calibration solution',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '3. Enter the known TDS value below',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '4. Press Calibrate button',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSettingField(
            'Reference TDS',
            _calibrationTdsController,
            'ppm',
            Icons.colorize,
            AppTheme.secondaryColor,
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.secondaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _calibrateTDS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.science, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Calibrate',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _targetTdsController.dispose();
    _tdsThresholdController.dispose();
    _minWaterController.dispose();
    _maxWaterController.dispose();
    _nutrientOnTimeController.dispose();
    _nutrientOffTimeController.dispose();
    _waterOnTimeController.dispose();
    _calibrationTdsController.dispose();
    super.dispose();
  }
}