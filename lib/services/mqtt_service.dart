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
  
  // Device ID - GANTI dengan MAC address ESP32 Anda
  // Contoh: "12345678" atau "a1b2c3d4"
  // Lihat Serial Monitor ESP32 untuk mendapatkan ID yang benar
  String deviceId = ("a93c1c78").toLowerCase(); // ⚠️ GANTI INI dengan ID ESP32 Anda!
  
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

  Future<void> connect() async {
    try {
      // Initialize topics
      topicSensors = "hidroponik_esp32_$deviceId/sensors";
      topicStatus = "hidroponik_esp32_$deviceId/status";
      topicPumpControl = "hidroponik_esp32_$deviceId/pump/control";
      topicNutrientControl = "hidroponik_esp32_$deviceId/nutrient/control";
      topicCalibrate = "hidroponik_esp32_$deviceId/calibrate";
      topicRequest = "hidroponik_esp32_$deviceId/request";
      topicSettings = "hidroponik_esp32_$deviceId/settings";
      topicAutoMode = "hidroponik_esp32_$deviceId/auto/mode";

      _client = MqttServerClient('test.mosquitto.org', '');
      _client!.port = 1883;
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = true;
      _client!.logging(on: false);

      final connMessage = MqttConnectMessage()
          .withClientIdentifier('FlutterHydro_${DateTime.now().millisecondsSinceEpoch}')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      
      _client!.connectionMessage = connMessage;

      print('Connecting to MQTT broker...');
      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('MQTT Connected successfully');
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
    _client!.subscribe(topicNutrientControl, MqttQos.atLeastOnce);
    _client!.subscribe(topicCalibrate, MqttQos.atLeastOnce);
    _client!.subscribe(topicRequest, MqttQos.atLeastOnce);
    _client!.subscribe(topicSettings, MqttQos.atLeastOnce);
    _client!.subscribe(topicAutoMode, MqttQos.atLeastOnce);
    print('Subscribed to topics');
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
          final sensorData = SensorData.fromJson(data);
          _sensorDataController.add(sensorData);
          print('Sensor data processed');
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
    _client?.disconnect();
    _isConnected = false;
    _connectionStatusController.add(false);
    print('MQTT Disconnected');
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