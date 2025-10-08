class SensorData {
  final double temperature;
  final double tds;
  final double waterLevel;
  final bool pumpStatus;
  final bool nutrientPumpStatus;
  final int pumpSpeed;
  final int nutrientPumpSpeed;
  final bool autoMode;
  final int systemUptime;
  final double calibrationFactor;
  final int timestamp;

  SensorData({
    required this.temperature,
    required this.tds,
    required this.waterLevel,
    required this.pumpStatus,
    required this.nutrientPumpStatus,
    required this.pumpSpeed,
    required this.nutrientPumpSpeed,
    required this.autoMode,
    required this.systemUptime,
    required this.calibrationFactor,
    required this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      tds: (json['tds'] ?? 0.0).toDouble(),
      waterLevel: (json['water_level'] ?? 0.0).toDouble(),
      pumpStatus: json['pump_status'] ?? false,
      nutrientPumpStatus: json['nutrient_pump_status'] ?? false,
      pumpSpeed: json['pump_speed'] ?? 0,
      nutrientPumpSpeed: json['nutrient_pump_speed'] ?? 0,
      autoMode: json['auto_mode'] ?? false,
      systemUptime: json['system_uptime'] ?? 0,
      calibrationFactor: (json['calibration_factor'] ?? 1.0).toDouble(),
      timestamp: json['timestamp'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'tds': tds,
      'water_level': waterLevel,
      'pump_status': pumpStatus,
      'nutrient_pump_status': nutrientPumpStatus,
      'pump_speed': pumpSpeed,
      'nutrient_pump_speed': nutrientPumpSpeed,
      'auto_mode': autoMode,
      'system_uptime': systemUptime,
      'calibration_factor': calibrationFactor,
      'timestamp': timestamp,
    };
  }

  // Default empty data
  factory SensorData.empty() {
    return SensorData(
      temperature: 0.0,
      tds: 0.0,
      waterLevel: 0.0,
      pumpStatus: false,
      nutrientPumpStatus: false,
      pumpSpeed: 0,
      nutrientPumpSpeed: 0,
      autoMode: false,
      systemUptime: 0,
      calibrationFactor: 1.0,
      timestamp: 0,
    );
  }
}