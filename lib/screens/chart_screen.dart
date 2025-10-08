import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
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
  
  late TabController _tabController;
  
  List<SensorData> _historicalData = [];
  String _timeRange = '1h'; // 1h, 6h, 24h, 7d
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistoricalData();
    _setupListeners();
  }

  void _setupListeners() {
    _mqttService.sensorDataStream.listen((data) {
      _storageService.saveData(data);
      _loadHistoricalData();
    });
  }

  Future<void> _loadHistoricalData() async {
    final data = await _storageService.getDataByTimeRange(_timeRange);
    if (mounted) {
      setState(() {
        _historicalData = data;
      });
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
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTemperatureChart(),
                    _buildTDSChart(),
                    _buildWaterLevelChart(),
                  ],
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
      child: Row(
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
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportData,
          ),
        ],
      ),
    );
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
    if (_historicalData.isEmpty) {
      return _buildEmptyState('No temperature data available');
    }

    final spots = _historicalData
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.temperature))
        .toList();

    return _buildChart(
      spots: spots,
      color: AppTheme.accentColor,
      title: 'Temperature (°C)',
      minY: 0,
      maxY: 50,
      leftTitles: ['0', '10', '20', '30', '40', '50'],
    );
  }

  Widget _buildTDSChart() {
    if (_historicalData.isEmpty) {
      return _buildEmptyState('No TDS data available');
    }

    final spots = _historicalData
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.tds))
        .toList();

    return _buildChart(
      spots: spots,
      color: AppTheme.secondaryColor,
      title: 'TDS Level (ppm)',
      minY: 0,
      maxY: 1500,
      leftTitles: ['0', '300', '600', '900', '1200', '1500'],
    );
  }

  Widget _buildWaterLevelChart() {
    if (_historicalData.isEmpty) {
      return _buildEmptyState('No water level data available');
    }

    final spots = _historicalData
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.waterLevel))
        .toList();

    return _buildChart(
      spots: spots,
      color: AppTheme.primaryColor,
      title: 'Water Level (%)',
      minY: 0,
      maxY: 100,
      leftTitles: ['0', '20', '40', '60', '80', '100'],
    );
  }

  Widget _buildChart({
    required List<FlSpot> spots,
    required Color color,
    required String title,
    required double minY,
    required double maxY,
    required List<String> leftTitles,
  }) {
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
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 5,
                  getDrawingHorizontalLine: (value) {
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
                      interval: spots.length / 5,
                      getTitlesWidget: (value, meta) {
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
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: (maxY - minY) / 5,
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
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: spots.length.toDouble() - 1,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
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
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 64,
            color: AppTheme.textSecondaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTheme.bodyStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Data will appear once collected',
            style: AppTheme.labelStyle,
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
    // TODO: Implement CSV export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}