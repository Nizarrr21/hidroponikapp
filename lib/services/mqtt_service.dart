import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/sensor_data.dart';
import '../models/system_status.dart';
import '../models/auto_mode_settings.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  MqttServerClient? _client;
  bool _isConnected = false;
  
  // Device ID - akan diubah sesuai device yang dipilih user
  String _deviceId = ("a93c1c78").toLowerCase();
  
  // Getter and Setter untuk deviceId dengan auto-reconnect
  String get deviceId => _deviceId;
  set deviceId(String value) {
    final newId = value.toLowerCase();
    if (_deviceId != newId) {
      print('📱 Device ID changed from $_deviceId to $newId');
      _deviceId = newId;
      
      // Update topics
      _updateTopics();
      
      // Reconnect if already connected
      if (_isConnected) {
        print('🔄 Reconnecting to new device...');
        disconnect();
        connect();
      }
    }
  }
  
  // MQTT Topics (akan di-generate otomatis berdasarkan deviceId)
  late String topicSensors;
  late String topicStatus;
  late String topicPumpControl;
  late String topicNutrientControl;
  late String topicCalibrate;
  late String topicRequest;
  late String topicSettings;
  late String topicAutoMode;

  // Stream controllers
  final _sensorDataController = StreamController<SensorData>.broadcast();
  final _systemStatusController = StreamController<SystemStatus>.broadcast();
  final _autoModeSettingsController = StreamController<AutoModeSettings>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  // Streams
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;
  Stream<SystemStatus> get systemStatusStream => _systemStatusController.stream;
  Stream<AutoModeSettings> get autoModeSettingsStream => _autoModeSettingsController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  bool get isConnected => _isConnected;

  // Update topics based on current deviceId
  void _updateTopics() {
    topicSensors = "hidroponik_esp32_$_deviceId/sensors";
    topicStatus = "hidroponik_esp32_$_deviceId/status";
    topicPumpControl = "hidroponik_esp32_$_deviceId/pump/control";
    topicNutrientControl = "hidroponik_esp32_$_deviceId/nutrient/control";
    topicCalibrate = "hidroponik_esp32_$_deviceId/calibrate";
    topicRequest = "hidroponik_esp32_$_deviceId/request";
    topicSettings = "hidroponik_esp32_$_deviceId/settings";
    topicAutoMode = "hidroponik_esp32_$_deviceId/auto/mode";
    print('📡 Topics updated for device: $_deviceId');
  }

  Future<void> connect() async {
    try {
      // Initialize topics before connecting
      _updateTopics();

      _client = MqttServerClient('test.mosquitto.org', '');
      _client!.port = 1883;
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = true;
      _client!.logging(on: false);

      final connMessage = MqttConnectMessage()
          .withClientIdentifier('FlutterHydro_$_deviceId${DateTime.now().millisecondsSinceEpoch}')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      
      _client!.connectionMessage = connMessage;

      print('🔌 Connecting to MQTT broker with device: $_deviceId');
      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('✅ MQTT Connected successfully to device: $_deviceId');
        _isConnected = true;
        _connectionStatusController.add(true);
        
        // Subscribe to topics
        _subscribeToTopics();
        
        // Setup message listener
        _client!.updates!.listen(_onMessage);
        
        // Request initial data
        requestData();
      } else {
        print('MQTT Connection failed');
        _isConnected = false;
        _connectionStatusController.add(false);
      }
    } catch (e) {
      print('MQTT Connection error: $e');
      _isConnected = false;
      _connectionStatusController.add(false);
    }
  }

  void _subscribeToTopics() {
    _client!.subscribe(topicSensors, MqttQos.atLeastOnce);
    _client!.subscribe(topicStatus, MqttQos.atLeastOnce);
    _client!.subscribe(topicSettings, MqttQos.atLeastOnce);
    _client!.subscribe(topicPumpControl, MqttQos.atLeastOnce);
    _client!.subscribe(topicNutrientControl, MqttQos.atLeastOnce);
    _client!.subscribe(topicAutoMode, MqttQos.atLeastOnce);
    _client!.subscribe(topicCalibrate, MqttQos.atLeastOnce);
    _client!.subscribe(topicRequest, MqttQos.atLeastOnce);
    print('📬 Subscribed to topics for device: $_deviceId');
  }
  
  /// Switch to a different device and reconnect
  Future<void> switchDevice(String newDeviceId) async {
    print('🔄 Switching device from $_deviceId to $newDeviceId');
    
    // Disconnect from current device
    if (_isConnected) {
      disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Set new device ID (will trigger setter)
    deviceId = newDeviceId;
    
    // Connect to new device
    await connect();
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (var message in messages) {
      final topic = message.topic;
      String payload;

      try {
        payload = MqttPublishPayload.bytesToStringAsString(
          (message.payload as MqttPublishMessage).payload.message,
        );
        
        print('Received message on topic: $topic');
        print('Payload: $payload');

        final data = jsonDecode(payload);
        
        if (topic == topicSensors) {
          print('Processing sensor data...');
          // Parse sensor data and add real timestamp
          final sensorData = SensorData.fromJson(data);
          
          // Create new sensor data with real timestamp
          final dataWithRealTimestamp = SensorData(
            temperature: sensorData.temperature,
            tds: sensorData.tds,
            waterLevel: sensorData.waterLevel,
            pumpStatus: sensorData.pumpStatus,
            nutrientPumpStatus: sensorData.nutrientPumpStatus,
            pumpSpeed: sensorData.pumpSpeed,
            nutrientPumpSpeed: sensorData.nutrientPumpSpeed,
            autoMode: sensorData.autoMode,
            systemUptime: sensorData.systemUptime,
            calibrationFactor: sensorData.calibrationFactor,
            timestamp: DateTime.now().millisecondsSinceEpoch, // Real timestamp
          );
          
          _sensorDataController.add(dataWithRealTimestamp);
          print('Sensor data processed with timestamp: ${DateTime.now()}');
        } else if (topic == topicStatus) {
          print('Processing system status...');
          final status = SystemStatus.fromJson(data);
          _systemStatusController.add(status);
          print('Status processed');
        } else if (topic == topicAutoMode) {
          print('Processing auto mode settings...');
          final settings = AutoModeSettings.fromJson(data);
          _autoModeSettingsController.add(settings);
          print('Auto mode settings processed');
        }
      } catch (e, stackTrace) {
        print('Error processing message on topic $topic:');
        print('Error: $e');
        print('Stack trace: $stackTrace');
      }
    }
  }

  // Control pump
  void controlPump(bool state, int speed) {
    if (!_isConnected) return;
    
    final payload = jsonEncode({
      'state': state ? 'on' : 'off',
      'speed': speed,
    });
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topicPumpControl, MqttQos.atLeastOnce, builder.payload!);
    print('Pump control sent: $payload');
  }

  // Control nutrient pump
  void controlNutrientPump(bool state, int speed) {
    if (!_isConnected) return;
    
    final payload = jsonEncode({
      'state': state ? 'on' : 'off',
      'speed': speed,
    });
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topicNutrientControl, MqttQos.atLeastOnce, builder.payload!);
    print('Nutrient pump control sent: $payload');
  }

  // Update settings
  void updateSettings(Map<String, dynamic> settings) {
    if (!_isConnected) return;
    
    final payload = jsonEncode(settings);
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topicSettings, MqttQos.atLeastOnce, builder.payload!);
    print('Settings updated: $payload');
  }

  // Toggle auto mode
  void toggleAutoMode(bool enabled) {
    if (!_isConnected) return;
    
    final payload = jsonEncode({'enabled': enabled});
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topicAutoMode, MqttQos.atLeastOnce, builder.payload!);
    print('Auto mode toggled: $enabled');
  }

  void toggleNutrientPump(bool enabled) {
    if (!_isConnected) return;
    
    final payload = jsonEncode({'enabled': enabled});
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topicNutrientControl, MqttQos.atLeastOnce, builder.payload!);
    print('Nutrient pump toggled: $enabled');
  }

  void toggleWaterPump(bool enabled) {
    if (!_isConnected) return;
    
    final payload = jsonEncode({'enabled': enabled});
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topicPumpControl, MqttQos.atLeastOnce, builder.payload!);
    print('Water pump toggled: $enabled');
  }

  void calibrateSensor(String sensorType, double value) {
    if (!_isConnected) return;
    
    final payload = jsonEncode({
      'sensor': sensorType,
      'value': value,
    });
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topicCalibrate, MqttQos.atLeastOnce, builder.payload!);
    print('Calibration sent - $sensorType: $value');
  }

  void calibrateWaterLevel({double? min, double? max}) {
    if (!_isConnected) return;
    
    final Map<String, dynamic> payload = {'sensor': 'water_level'};
    if (min != null) payload['min'] = min;
    if (max != null) payload['max'] = max;
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    _client!.publishMessage(topicCalibrate, MqttQos.atLeastOnce, builder.payload!);
    print('Water level calibration sent - min: $min, max: $max');
  }

  // Request data
  void requestData() {
    if (!_isConnected) return;
    
    final builder = MqttClientPayloadBuilder();
    builder.addString('request_data');
    _client!.publishMessage(topicRequest, MqttQos.atLeastOnce, builder.payload!);
    
    builder.clear();
    builder.addString('request_status');
    _client!.publishMessage(topicRequest, MqttQos.atLeastOnce, builder.payload!);
    
    print('Data requested');
  }

  void disconnect() {
    if (_client != null) {
      _client!.disconnect();
      print('🔌 MQTT Disconnected from device: $_deviceId');
    }
    _isConnected = false;
    _connectionStatusController.add(false);
  }

  void requestStatus() {
    if (!_isConnected) return;
    
    final builder = MqttClientPayloadBuilder();
    builder.addString('request_status');
    _client!.publishMessage(topicRequest, MqttQos.atLeastOnce, builder.payload!);
    print('Status requested');
  }

  void calibrateTDS(double value) {
    if (!_isConnected) return;
    
    final payload = jsonEncode({'tds': value});
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topicCalibrate, MqttQos.atLeastOnce, builder.payload!);
    print('TDS calibration sent: $payload');
  }

  void dispose() {
    _sensorDataController.close();
    _systemStatusController.close();
    _autoModeSettingsController.close();
    _connectionStatusController.close();
    disconnect();
  }
}