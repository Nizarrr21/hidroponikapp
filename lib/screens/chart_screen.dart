import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../models/sensor_data.dart';
import '../services/mqtt_service.dart';
import '../services/data_storage_service.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({Key? key}) : super(key: key);

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> with SingleTickerProviderStateMixin {
  final MQTTService _mqttService = MQTTService();
  final DataStorageService _storageService = DataStorageService();
  final GlobalKey _chartKey = GlobalKey();
  
  late TabController _tabController;
  
  List<SensorData> _historicalData = [];
  String _timeRange = '1h'; // 1h, 6h, 24h, 7d
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _connectToMQTT();
    _loadHistoricalData();
    _setupListeners();
    _startPeriodicUpdate();
  }

  Future<void> _connectToMQTT() async {
    if (!_mqttService.isConnected) {
      await _mqttService.connect();
    }
  }

  void _setupListeners() {
    _mqttService.sensorDataStream.listen((data) {
      if (mounted) {
        print('📊 Chart: Received sensor data (temp=${data.temperature}°C, tds=${data.tds}ppm)');
        
        // Save immediately
        _storageService.saveData(data).then((_) {
          print('✅ Chart: Data saved, reloading view...');
          // Reload to show latest data
          _loadHistoricalData();
        });
      }
    });
  }

  void _startPeriodicUpdate() {
    // Update chart periodically based on time range
    Future.delayed(Duration(seconds: _getUpdateInterval()), () {
      if (mounted) {
        _loadHistoricalData();
        _startPeriodicUpdate();
      }
    });
  }

  int _getUpdateInterval() {
    switch (_timeRange) {
      case '1h':
        return 5; // Update every 5 seconds for real-time view
      case '6h':
        return 30; // Update every 30 seconds
      case '24h':
        return 60; // Update every 1 minute
      case '7d':
        return 300; // Update every 5 minutes
      default:
        return 30;
    }
  }

  Future<void> _loadHistoricalData() async {
    print('📈 Loading historical data for range: $_timeRange');
    final data = await _storageService.getDataByTimeRange(_timeRange);
    print('📈 Loaded ${data.length} data points from storage');
    
    if (mounted) {
      setState(() {
        _historicalData = data;
      });
      print('✅ Chart updated with ${data.length} points');
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
          child: Column(
            children: [
              _buildAppBar(),
              _buildTimeRangeSelector(),
              _buildTabBar(),
              Expanded(
                child: RepaintBoundary(
                  key: _chartKey,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTemperatureChart(),
                      _buildTDSChart(),
                      _buildWaterLevelChart(),
                    ],
                  ),
                ),
              ),
              _buildStatistics(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sensor Analytics',
                style: AppTheme.headingStyle,
              ),
              const Spacer(),
              if (_historicalData.isEmpty)
                IconButton(
                  icon: const Icon(Icons.add_chart),
                  onPressed: _addTestData,
                  tooltip: 'Tambah Data Test',
                ),
              IconButton(
                icon: const Icon(Icons.file_download),
                onPressed: _exportData,
              ),
            ],
          ),
          if (_historicalData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(width: 56),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.analytics, size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          _getSamplingInfo(),
                          style: AppTheme.labelStyle.copyWith(
                            fontSize: 11,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: AppTheme.successColor),
                        const SizedBox(width: 6),
                        Text(
                          '${_historicalData.length} points',
                          style: AppTheme.labelStyle.copyWith(
                            fontSize: 11,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getSamplingInfo() {
    switch (_timeRange) {
      case '1h':
        return 'Real-time • per second';
      case '6h':
        return 'Sampled • per minute';
      case '24h':
        return 'Average • per hour';
      case '7d':
        return 'Average • per day';
      default:
        return 'Real-time';
    }
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTimeRangeButton('1h', '1 Hour'),
          _buildTimeRangeButton('6h', '6 Hours'),
          _buildTimeRangeButton('24h', '24 Hours'),
          _buildTimeRangeButton('7d', '7 Days'),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String value, String label) {
    final isSelected = _timeRange == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _timeRange = value;
          });
          _loadHistoricalData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondaryColor,
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 3,
        tabs: const [
          Tab(icon: Icon(Icons.thermostat), text: 'Temperature'),
          Tab(icon: Icon(Icons.water_drop), text: 'TDS'),
          Tab(icon: Icon(Icons.waves), text: 'Water Level'),
        ],
      ),
    );
  }

  Widget _buildTemperatureChart() {
    List<FlSpot> spots = [];
    double minY = 0;
    double maxY = 50;
    bool hasData = _historicalData.isNotEmpty;

    if (hasData) {
      final validSpots = _historicalData
          .asMap()
          .entries
          .where((e) => e.value.temperature >= 0)
          .map((e) => FlSpot(e.key.toDouble(), e.value.temperature))
          .toList();

      if (validSpots.isNotEmpty) {
        spots = validSpots;
        final temperatures = spots.map((e) => e.y).toList();
        final minTemp = temperatures.reduce((a, b) => a < b ? a : b);
        final maxTemp = temperatures.reduce((a, b) => a > b ? a : b);
        final padding = (maxTemp - minTemp) * 0.1;
        if (padding == 0) {
          minY = (minTemp - 5).clamp(0, double.infinity);
          maxY = maxTemp + 5;
        } else {
          minY = (minTemp - padding).clamp(0, double.infinity);
          maxY = maxTemp + padding;
        }
      } else {
        hasData = false;
      }
    }

    return _buildChart(
      spots: spots,
      color: AppTheme.accentColor,
      title: 'Temperature (°C)',
      minY: minY,
      maxY: maxY,
      isEmpty: !hasData,
      emptyMessage: 'Tidak ada data suhu tersedia',
    );
  }

  Widget _buildTDSChart() {
    List<FlSpot> spots = [];
    double minY = 0;
    double maxY = 1500;
    bool hasData = _historicalData.isNotEmpty;

    if (hasData) {
      final validSpots = _historicalData
          .asMap()
          .entries
          .where((e) => e.value.tds >= 0)
          .map((e) => FlSpot(e.key.toDouble(), e.value.tds))
          .toList();

      if (validSpots.isNotEmpty) {
        spots = validSpots;
        final tdsValues = spots.map((e) => e.y).toList();
        final minTds = tdsValues.reduce((a, b) => a < b ? a : b);
        final maxTds = tdsValues.reduce((a, b) => a > b ? a : b);
        final padding = (maxTds - minTds) * 0.1;
        if (padding == 0) {
          minY = (minTds - 50).clamp(0, double.infinity);
          maxY = maxTds + 50;
        } else {
          minY = (minTds - padding).clamp(0, double.infinity);
          maxY = maxTds + padding;
        }
      } else {
        hasData = false;
      }
    }

    return _buildChart(
      spots: spots,
      color: AppTheme.secondaryColor,
      title: 'TDS Level (ppm)',
      minY: minY,
      maxY: maxY,
      isEmpty: !hasData,
      emptyMessage: 'Tidak ada data TDS tersedia',
    );
  }

  Widget _buildWaterLevelChart() {
    List<FlSpot> spots = [];
    double minY = 0;
    double maxY = 100;
    bool hasData = _historicalData.isNotEmpty;

    if (hasData) {
      final validSpots = _historicalData
          .asMap()
          .entries
          .where((e) => e.value.waterLevel >= 0)
          .map((e) => FlSpot(e.key.toDouble(), e.value.waterLevel))
          .toList();

      if (validSpots.isNotEmpty) {
        spots = validSpots;
        final waterValues = spots.map((e) => e.y).toList();
        final minWater = waterValues.reduce((a, b) => a < b ? a : b);
        final maxWater = waterValues.reduce((a, b) => a > b ? a : b);
        final padding = (maxWater - minWater) * 0.1;
        if (padding == 0) {
          minY = (minWater - 5).clamp(0, double.infinity);
          maxY = (maxWater + 5).clamp(0, 100);
        } else {
          minY = (minWater - padding).clamp(0, double.infinity);
          maxY = (maxWater + padding).clamp(0, 100);
        }
      } else {
        hasData = false;
      }
    }

    return _buildChart(
      spots: spots,
      color: AppTheme.primaryColor,
      title: 'Water Level (%)',
      minY: minY,
      maxY: maxY,
      isEmpty: !hasData,
      emptyMessage: 'Tidak ada data level air tersedia',
    );
  }

  Widget _buildChart({
    required List<FlSpot> spots,
    required Color color,
    required String title,
    required double minY,
    required double maxY,
    bool isEmpty = false,
    String emptyMessage = 'No data available',
  }) {
    // For empty charts, create placeholder spots for proper scaling
    List<FlSpot> displaySpots = isEmpty ? [] : spots;
    double chartMaxX = isEmpty ? 23.0 : (spots.isNotEmpty ? spots.length.toDouble() - 1 : 23.0);
    double chartMinX = 0.0;
    
    // Ensure proper intervals to avoid division by zero
    double horizontalInterval = (maxY - minY) > 0 ? (maxY - minY) / 5 : 10.0;
    double verticalInterval = chartMaxX > 0 ? chartMaxX / 5 : 4.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.subheadingStyle,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Stack(
              children: [
                LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      drawHorizontalLine: true,
                      horizontalInterval: horizontalInterval,
                      verticalInterval: verticalInterval,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.white.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: Colors.white.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: verticalInterval,
                          getTitlesWidget: (value, meta) {
                            if (isEmpty) {
                              // Show placeholder time labels for empty chart
                              final hours = [0, 6, 12, 18, 24];
                              final index = (value / (chartMaxX / 4)).round();
                              if (index >= 0 && index < hours.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${hours[index].toString().padLeft(2, '0')}:00',
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              }
                            } else {
                              final index = value.toInt();
                              if (index >= 0 && index < _historicalData.length) {
                                final time = DateTime.fromMillisecondsSinceEpoch(
                                  _historicalData[index].timestamp,
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              }
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          interval: horizontalInterval,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(0),
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    minX: chartMinX,
                    maxX: chartMaxX > chartMinX ? chartMaxX : chartMinX + 1,
                    minY: minY,
                    maxY: maxY > minY ? maxY : minY + 1,
                    lineBarsData: isEmpty ? [] : [
                      LineChartBarData(
                        spots: displaySpots,
                        isCurved: true,
                        color: color,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withOpacity(0.2),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: !isEmpty,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: AppTheme.cardColor,
                        tooltipRoundedRadius: 8,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              spot.y.toStringAsFixed(1),
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
                if (isEmpty)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.timeline,
                              size: 48,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak Ada Data',
                            style: AppTheme.bodyStyle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _mqttService.isConnected 
                              ? 'Menunggu data sensor...\n${_timeRange == "1h" ? "Data akan muncul setiap detik" : _timeRange == "6h" ? "Data per menit" : _timeRange == "24h" ? "Rata-rata per jam" : "Rata-rata harian"}'
                              : 'Koneksi MQTT terputus\nSambungkan sensor untuk melihat data',
                            style: AppTheme.labelStyle.copyWith(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    if (_historicalData.isEmpty) return const SizedBox.shrink();

    final avgTemp = _historicalData.map((e) => e.temperature).reduce((a, b) => a + b) / _historicalData.length;
    final avgTds = _historicalData.map((e) => e.tds).reduce((a, b) => a + b) / _historicalData.length;
    final avgWater = _historicalData.map((e) => e.waterLevel).reduce((a, b) => a + b) / _historicalData.length;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistics',
            style: AppTheme.subheadingStyle,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Temp Avg', avgTemp.toStringAsFixed(1), Icons.thermostat, AppTheme.accentColor),
              _buildStatItem('TDS Avg', avgTds.toStringAsFixed(1), Icons.water_drop, AppTheme.secondaryColor),
              _buildStatItem('Water Avg', avgWater.toStringAsFixed(1), Icons.waves, AppTheme.primaryColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTheme.labelStyle.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  Future<void> _exportData() async {
    try {
      // Show loading indicator
      _showMessage('Mengekspor chart...', isError: false);

      // Capture the chart as image
      final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _showMessage('Gagal menangkap chart', isError: true);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showMessage('Gagal mengkonversi chart ke gambar', isError: true);
        return;
      }

      final bytes = byteData.buffer.asUint8List();

      // Create filename with timestamp and chart type
      final chartTypes = ['Suhu', 'TDS', 'Level_Air'];
      final currentChart = chartTypes[_tabController.index];
      final now = DateTime.now();
      final timestamp = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
      final filename = 'Chart_Hidroponik_${currentChart}_$timestamp.png';
      
      // Get the appropriate directory for saving
      Directory? directory;
      String savedPath = '';
      
      if (Platform.isAndroid) {
        // For Android, try multiple approaches
        try {
          // First try external storage directory
          directory = await getExternalStorageDirectory();
          if (directory != null) {
            // Create a Pictures subfolder
            final picturesDir = Directory('${directory.path}/Pictures/Hidroponik');
            if (!await picturesDir.exists()) {
              await picturesDir.create(recursive: true);
            }
            directory = picturesDir;
          }
        } catch (e) {
          // Fallback to application documents directory
          directory = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop platforms
        directory = await getDownloadsDirectory();
        directory ??= await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        _showMessage('Gagal mengakses direktori penyimpanan', isError: true);
        return;
      }

      // Save the file
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);
      savedPath = file.path;

      _showMessage('Chart berhasil disimpan di: ${directory.path}', isError: false);
      
      // Show success dialog with more info
      _showExportSuccessDialog(filename, savedPath);
      
    } catch (e) {
      _showMessage('Ekspor gagal: ${e.toString()}', isError: true);
    }
  }

  void _showExportSuccessDialog(String filename, String path) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Export Berhasil', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File berhasil disimpan:', style: AppTheme.bodyStyle),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nama file:', style: AppTheme.labelStyle),
                    Text(filename, style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Lokasi:', style: AppTheme.labelStyle),
                    Text(path, style: AppTheme.bodyStyle.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.dangerColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  void _addTestData() {
    final now = DateTime.now();
    final testData = <SensorData>[];
    
    for (int i = 0; i < 24; i++) {
      final timestamp = now.subtract(Duration(hours: 23 - i)).millisecondsSinceEpoch;
      testData.add(SensorData(
        temperature: 25.0 + (i * 0.5) + (i % 3 * 2), // Varies between 25-35°C
        tds: 800.0 + (i * 10) + (i % 4 * 50), // Varies between 800-1200 ppm
        waterLevel: 60.0 + (i % 5 * 5), // Varies between 60-80%
        pumpStatus: i % 6 < 2, // On for 2 hours, off for 4 hours
        nutrientPumpStatus: i % 8 < 1, // On for 1 hour, off for 7 hours
        pumpSpeed: 50 + (i % 3 * 20),
        nutrientPumpSpeed: 30 + (i % 4 * 15),
        autoMode: true,
        systemUptime: i * 3600,
        calibrationFactor: 1.0,
        timestamp: timestamp,
      ));
    }
    
    setState(() {
      _historicalData = testData;
    });
    
    _showMessage('Data test berhasil ditambahkan! Lihat chart untuk melihat data sample.', isError: false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}