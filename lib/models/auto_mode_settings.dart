class AutoModeSettings {
  final bool autoMode;
  final double targetTds;
  final double tdsThreshold;
  final double minWaterLevel;
  final double maxWaterLevel;
  final int nutrientOnTime;
  final int nutrientOffTime;
  final int waterOnTime;
  final int autoNutrientSpeed;
  final int autoWaterSpeed;

  AutoModeSettings({
    required this.autoMode,
    required this.targetTds,
    required this.tdsThreshold,
    required this.minWaterLevel,
    required this.maxWaterLevel,
    required this.nutrientOnTime,
    required this.nutrientOffTime,
    required this.waterOnTime,
    required this.autoNutrientSpeed,
    required this.autoWaterSpeed,
  });

  factory AutoModeSettings.defaultSettings() {
    return AutoModeSettings(
      autoMode: false,
      targetTds: 800.0,
      tdsThreshold: 50.0,
      minWaterLevel: 20.0,
      maxWaterLevel: 80.0,
      nutrientOnTime: 5000,
      nutrientOffTime: 30000,
      waterOnTime: 10000,
      autoNutrientSpeed: 30,
      autoWaterSpeed: 50,
    );
  }

  factory AutoModeSettings.fromJson(Map<String, dynamic> json) {
    return AutoModeSettings(
      autoMode: json['enabled'] ?? false,
      targetTds: (json['target_tds'] ?? 800.0).toDouble(),
      tdsThreshold: (json['tds_threshold'] ?? 50.0).toDouble(),
      minWaterLevel: (json['min_water_level'] ?? 20.0).toDouble(),
      maxWaterLevel: (json['max_water_level'] ?? 80.0).toDouble(),
      nutrientOnTime: json['nutrient_on_time'] ?? 5000,
      nutrientOffTime: json['nutrient_off_time'] ?? 30000,
      waterOnTime: json['water_on_time'] ?? 10000,
      autoNutrientSpeed: json['auto_nutrient_speed'] ?? 30,
      autoWaterSpeed: json['auto_water_speed'] ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': autoMode,
      'target_tds': targetTds,
      'tds_threshold': tdsThreshold,
      'min_water_level': minWaterLevel,
      'max_water_level': maxWaterLevel,
      'nutrient_on_time': nutrientOnTime,
      'nutrient_off_time': nutrientOffTime,
      'water_on_time': waterOnTime,
      'auto_nutrient_speed': autoNutrientSpeed,
      'auto_water_speed': autoWaterSpeed,
    };
  }
}