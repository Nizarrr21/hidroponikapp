class SystemStatus {
  final bool isOnline;
  final bool isPumpRunning;
  final bool isNutrientPumpRunning;
  final bool isAutoMode;
  final double systemUptime;
  final String lastError;
  final DateTime lastUpdate;

  SystemStatus({
    this.isOnline = false,
    this.isPumpRunning = false,
    this.isNutrientPumpRunning = false,
    this.isAutoMode = false,
    this.systemUptime = 0,
    this.lastError = '',
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      isOnline: json['isOnline'] ?? false,
      isPumpRunning: json['isPumpRunning'] ?? false,
      isNutrientPumpRunning: json['isNutrientPumpRunning'] ?? false,
      isAutoMode: json['isAutoMode'] ?? false,
      systemUptime: (json['systemUptime'] ?? 0).toDouble(),
      lastError: json['lastError'] ?? '',
      lastUpdate: json['lastUpdate'] != null 
          ? DateTime.parse(json['lastUpdate']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isOnline': isOnline,
      'isPumpRunning': isPumpRunning,
      'isNutrientPumpRunning': isNutrientPumpRunning,
      'isAutoMode': isAutoMode,
      'systemUptime': systemUptime,
      'lastError': lastError,
      'lastUpdate': lastUpdate.toIso8601String(),
    };
  }
}