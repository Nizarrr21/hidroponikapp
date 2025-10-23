import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/mqtt_service.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final MQTTService _mqttService = MQTTService();
  
  // Controllers untuk calibration values
  late TextEditingController _tdsFactorController;
  late TextEditingController _tempOffsetController;
  late TextEditingController _waterMinController;
  late TextEditingController _waterMaxController;
  late TextEditingController _tdsCalibrationValueController;
  
  // Current sensor readings
  double _currentTemp = 0.0;
  double _currentWaterLevelRaw = 0.0;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _connectToMQTT();
    _setupListener();
  }
  
  Future<void> _connectToMQTT() async {
    if (!_mqttService.isConnected) {
      await _mqttService.connect();
    }
  }
  
  void _initializeControllers() {
    _tdsFactorController = TextEditingController(text: '1.0');
    _tempOffsetController = TextEditingController(text: '0.0');
    _waterMinController = TextEditingController(text: '0');
    _waterMaxController = TextEditingController(text: '4095');
    _tdsCalibrationValueController = TextEditingController(text: '1000');
  }
  
  void _setupListener() {
    _mqttService.sensorDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentTemp = data.temperature;
          // Assuming raw value would be sent separately
          _currentWaterLevelRaw = data.waterLevel;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _tdsFactorController.dispose();
    _tempOffsetController.dispose();
    _waterMinController.dispose();
    _waterMaxController.dispose();
    _tdsCalibrationValueController.dispose();
    super.dispose();
  }
  
  void _calibrateTDS() {
    final value = double.tryParse(_tdsCalibrationValueController.text);
    if (value == null || value <= 0) {
      _showError('Masukkan nilai TDS yang valid (misal: 1000 ppm)');
      return;
    }
    
    _mqttService.calibrateSensor('tds', value);
    
    _showSuccess('Kalibrasi TDS berhasil!\n Nilai referensi: ${value.toStringAsFixed(0)} ppm');
  }
  
  void _calibrateTemperature() {
    final offset = double.tryParse(_tempOffsetController.text);
    if (offset == null || offset < -10 || offset > 10) {
      _showError('Offset suhu harus antara -10°C sampai +10°C');
      return;
    }
    
    _mqttService.calibrateSensor('temperature', offset);
    
    _showSuccess('Offset suhu disimpan!\nOffset: ${offset > 0 ? '+' : ''}${offset.toStringAsFixed(1)}°C');
  }
  
  void _calibrateWaterLevelMin() {
    final min = double.tryParse(_waterMinController.text);
    if (min == null || min < 0 || min > 4095) {
      _showError('Nilai minimum harus antara 0-4095');
      return;
    }
    
    _mqttService.calibrateWaterLevel(min: min);
    
    _showSuccess('Water Level MIN disimpan!\nNilai: ${min.toStringAsFixed(0)}');
  }
  
  void _calibrateWaterLevelMax() {
    final max = double.tryParse(_waterMaxController.text);
    if (max == null || max < 0 || max > 4095) {
      _showError('Nilai maximum harus antara 0-4095');
      return;
    }
    
    _mqttService.calibrateWaterLevel(max: max);
    
    _showSuccess('Water Level MAX disimpan!\nNilai: ${max.toStringAsFixed(0)}');
  }
  
  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber, color: AppTheme.warningColor),
            SizedBox(width: 12),
            Text('Reset Kalibrasi?'),
          ],
        ),
        content: const Text(
          'Semua nilai kalibrasi akan dikembalikan ke default.\n\n'
          'TDS Factor: 1.0\n'
          'Temp Offset: 0.0°C\n'
          'Water Min: 0\n'
          'Water Max: 4095',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetCalibration();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
  
  void _resetCalibration() {
    setState(() {
      _tdsFactorController.text = '1.0';
      _tempOffsetController.text = '0.0';
      _waterMinController.text = '0';
      _waterMaxController.text = '4095';
    });
    
    _mqttService.calibrateSensor('tds', 1.0);
    _mqttService.calibrateSensor('temperature', 0.0);
    _mqttService.calibrateWaterLevel(min: 0, max: 4095);
    
    _showSuccess('Kalibrasi direset ke default');
  }
  
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.dangerColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
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
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    const Text(
                      'Kalibrasi TDS',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: 16),
                    _buildTDSCalibrationCard(),
                    const SizedBox(height: 24),
                    const Text(
                      'Kalibrasi Suhu',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: 16),
                    _buildTemperatureCalibrationCard(),
                    const SizedBox(height: 24),
                    const Text(
                      'Kalibrasi Water Level',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: 16),
                    _buildWaterLevelCalibrationCard(),
                    const SizedBox(height: 24),
                    _buildResetButton(),
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
          'Calibration',
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
  
  Widget _buildInfoCard() {
    return Container(
      decoration: AppTheme.cardDecoration.copyWith(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 24),
              SizedBox(width: 12),
              Text(
                'Panduan Kalibrasi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('TDS', 'Gunakan larutan standar (misal: 1000 ppm) untuk kalibrasi akurat'),
          const SizedBox(height: 8),
          _buildInfoItem('Suhu', 'Bandingkan dengan termometer akurat, atur offset jika perlu'),
          const SizedBox(height: 8),
          _buildInfoItem('Water Level', 'Kalibrasi saat tangki kosong (MIN) dan penuh (MAX)'),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTDSCalibrationCard() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.science, color: AppTheme.secondaryColor, size: 28),
              SizedBox(width: 12),
              Text(
                'TDS Sensor',
                style: AppTheme.subheadingStyle,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.secondaryColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Langkah Kalibrasi:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. Siapkan larutan standar (misal: 1000 ppm)\n'
                  '2. Celupkan sensor TDS ke dalam larutan\n'
                  '3. Tunggu pembacaan stabil\n'
                  '4. Masukkan nilai standar dan tekan Kalibrasi',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tdsCalibrationValueController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nilai Standar (ppm)',
              hintText: '1000',
              prefixIcon: const Icon(Icons.water_drop, color: AppTheme.secondaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.secondaryColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _calibrateTDS,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Kalibrasi TDS',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTemperatureCalibrationCard() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.thermostat, color: AppTheme.primaryColor, size: 28),
              SizedBox(width: 12),
              Text(
                'Temperature Sensor',
                style: AppTheme.subheadingStyle,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.device_thermostat, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pembacaan Saat Ini',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    Text(
                      '${_currentTemp.toStringAsFixed(2)}°C',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Offset Kalibrasi:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Jika sensor menunjukkan 25.0°C tetapi termometer akurat menunjukkan 25.5°C, '
            'masukkan offset +0.5°C',
            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tempOffsetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Temperature Offset (°C)',
              hintText: '0.0',
              helperText: 'Range: -10.0 hingga +10.0°C',
              prefixIcon: const Icon(Icons.edit, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _calibrateTemperature,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Simpan Offset',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWaterLevelCalibrationCard() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.water, color: AppTheme.accentColor, size: 28),
              SizedBox(width: 12),
              Text(
                'Water Level Sensor',
                style: AppTheme.subheadingStyle,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warningColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: const [
                Text(
                  'Langkah Kalibrasi:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '1. MIN: Kosongkan tangki, catat nilai raw sensor\n'
                  '2. MAX: Isi tangki penuh, catat nilai raw sensor\n'
                  '3. Masukkan kedua nilai untuk kalibrasi akurat',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _waterMinController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nilai Minimum (Tangki Kosong)',
              hintText: '0',
              helperText: 'Nilai raw ADC saat tangki kosong',
              prefixIcon: const Icon(Icons.arrow_downward, color: AppTheme.dangerColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accentColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: _calibrateWaterLevelMin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Set MIN Value',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _waterMaxController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nilai Maximum (Tangki Penuh)',
              hintText: '4095',
              helperText: 'Nilai raw ADC saat tangki penuh',
              prefixIcon: const Icon(Icons.arrow_upward, color: AppTheme.successColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accentColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: _calibrateWaterLevelMax,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Set MAX Value',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResetButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.warningColor, width: 2),
        borderRadius: BorderRadius.circular(28),
      ),
      child: ElevatedButton(
        onPressed: _resetToDefaults,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.warningColor,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.restart_alt, size: 24),
            SizedBox(width: 12),
            Text(
              'Reset ke Default',
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
}
