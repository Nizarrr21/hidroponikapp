import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/mqtt_service.dart';
import '../services/plant_settings_service.dart';
import '../models/plant_data.dart';

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
  PlantData? _selectedPlant;
  bool _isManualOverride = false;
  bool _isUserEditing = false;
  bool _hasLoadedInitialData = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupListeners();
    _loadPlantData();
    _mqttService.requestData();
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPlantData(); // Reload when widget updates
  }

  Future<void> _loadPlantData() async {
    _selectedPlant = await PlantSettingsService.getSelectedPlant();
    if (_selectedPlant != null) {
      final targetTds = await PlantSettingsService.getTargetTds();
      final threshold = await PlantSettingsService.getTdsThreshold();
      
      if (mounted) {
        setState(() {
          _targetTdsController.text = targetTds.toStringAsFixed(0);
          _tdsThresholdController.text = threshold.toStringAsFixed(0);
        });
      }
    }
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
    
    // Mark as editing when user changes any field
    _targetTdsController.addListener(_markUserEditing);
    _tdsThresholdController.addListener(_markUserEditing);
    _minWaterController.addListener(_markUserEditing);
    _maxWaterController.addListener(_markUserEditing);
    _nutrientOnTimeController.addListener(_markUserEditing);
    _nutrientOffTimeController.addListener(_markUserEditing);
    _waterOnTimeController.addListener(_markUserEditing);
  }

  void _setupListeners() {
    _mqttService.autoModeSettingsStream.listen((settings) {
      // Only update from MQTT if user is not editing
      if (mounted && !_isUserEditing) {
        setState(() {
          _isAutoMode = settings.autoMode;
          _autoNutrientSpeed = settings.autoNutrientSpeed;
          _autoWaterSpeed = settings.autoWaterSpeed;
          
          // Only update text fields if this is initial load
          if (!_hasLoadedInitialData) {
            _targetTdsController.text = settings.targetTds.toStringAsFixed(0);
            _tdsThresholdController.text = settings.tdsThreshold.toStringAsFixed(0);
            _minWaterController.text = settings.minWaterLevel.toStringAsFixed(0);
            _maxWaterController.text = settings.maxWaterLevel.toStringAsFixed(0);
            _nutrientOnTimeController.text = (settings.nutrientOnTime / 1000).toStringAsFixed(0);
            _nutrientOffTimeController.text = (settings.nutrientOffTime / 1000).toStringAsFixed(0);
            _waterOnTimeController.text = (settings.waterOnTime / 1000).toStringAsFixed(0);
            _hasLoadedInitialData = true;
          }
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
  
  void _markUserEditing() {
    setState(() {
      _isUserEditing = true;
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

  void _saveSettings() async {
    // Check if TDS values were manually changed
    final targetTdsInput = double.tryParse(_targetTdsController.text) ?? 800.0;
    final thresholdInput = double.tryParse(_tdsThresholdController.text) ?? 50.0;
    
    // If plant is selected and values changed, warn user
    if (_selectedPlant != null && !_isManualOverride) {
      final plantTargetTds = await PlantSettingsService.getTargetTds();
      final plantThreshold = await PlantSettingsService.getTdsThreshold();
      
      if ((targetTdsInput - plantTargetTds).abs() > 1 || 
          (thresholdInput - plantThreshold).abs() > 1) {
        if (!mounted) return;
        final shouldOverride = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.warning_amber, color: AppTheme.warningColor),
                SizedBox(width: 12),
                Text('Override Plant Settings?'),
              ],
            ),
            content: Text(
              'Anda mengubah nilai TDS/PPM dari rekomendasi tanaman ${_selectedPlant!.namaIndonesia}.\n\n'
              'Rekomendasi: ${plantTargetTds.toStringAsFixed(0)} ppm ± ${plantThreshold.toStringAsFixed(0)} ppm\n'
              'Input Anda: ${targetTdsInput.toStringAsFixed(0)} ppm ± ${thresholdInput.toStringAsFixed(0)} ppm\n\n'
              'Apakah Anda yakin ingin menggunakan nilai manual?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningColor,
                ),
                child: const Text('Ya, Override'),
              ),
            ],
          ),
        );
        
        if (shouldOverride != true) {
          return;
        }
        
        setState(() {
          _isManualOverride = true;
        });
      }
    }
    
    final settings = {
      'auto': _isAutoMode,
      'target_tds': targetTdsInput,
      'tds_threshold': thresholdInput,
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
    
    // Reset editing flag after save
    setState(() {
      _isUserEditing = false;
    });
    
    if (!mounted) return;
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

  Future<void> _resetToPlantValues() async {
    if (_selectedPlant == null) return;
    
    final targetTds = await PlantSettingsService.getTargetTds();
    final threshold = await PlantSettingsService.getTdsThreshold();
    
    setState(() {
      _targetTdsController.text = targetTds.toStringAsFixed(0);
      _tdsThresholdController.text = threshold.toStringAsFixed(0);
      _isManualOverride = false;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.restart_alt, color: Colors.white),
            SizedBox(width: 12),
            Text('Nilai TDS direset ke rekomendasi tanaman'),
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
                    if (_selectedPlant != null) ...[
                      _buildPlantInfoCard(),
                      const SizedBox(height: 24),
                    ],
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

  Widget _buildPlantInfoCard() {
    if (_selectedPlant == null) return const SizedBox.shrink();
    
    Color _getPlantColor() {
      try {
        return Color(int.parse(_selectedPlant!.color.replaceAll('#', '0xff')));
      } catch (e) {
        return AppTheme.primaryColor;
      }
    }
    
    return Container(
      decoration: AppTheme.cardDecoration.copyWith(
        gradient: LinearGradient(
          colors: [
            _getPlantColor().withOpacity(0.1),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getPlantColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedPlant!.icon,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tanaman Aktif',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedPlant!.namaIndonesia,
                      style: AppTheme.subheadingStyle.copyWith(fontSize: 18),
                    ),
                    Text(
                      _selectedPlant!.namaInggris,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isManualOverride)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.warningColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.edit, color: AppTheme.warningColor, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Manual',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.science,
                      color: AppTheme.secondaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rekomendasi PPM',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          Text(
                            '${_selectedPlant!.ppmMin} - ${_selectedPlant!.ppmMax} ppm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.bolt,
                      color: AppTheme.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nilai EC',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          Text(
                            '${_selectedPlant!.ecMin.toStringAsFixed(1)} - ${_selectedPlant!.ecMax.toStringAsFixed(1)} mS/cm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_isManualOverride) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.successColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nilai TDS otomatis disesuaikan dengan tanaman',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.successColor,
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
    return Column(
      children: [
        if (_selectedPlant != null && _isManualOverride) ...[
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.successColor, width: 2),
              borderRadius: BorderRadius.circular(26),
            ),
            child: ElevatedButton(
              onPressed: _resetToPlantValues,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppTheme.successColor,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.restart_alt, size: 22),
                  SizedBox(width: 12),
                  Text(
                    'Reset ke Nilai Tanaman',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
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
        ),
      ],
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