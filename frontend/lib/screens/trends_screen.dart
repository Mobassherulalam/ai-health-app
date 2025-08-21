import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/device_manager.dart';
import '../models/ecg_record.dart';
import '../models/vitals_record.dart';
import 'dart:async';
import 'dart:math' as math;

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  final ApiService _apiService = ApiService('http://127.0.0.1:8000');
  final DeviceManager _deviceManager = DeviceManager();
  Timer? _timer;
  StreamSubscription<Map<String, bool>>? _deviceStateSubscription;
  StreamSubscription<Map<String, int>>? _syncIntervalSubscription;
  
  List<ECGRecord> _allEcgData = [];
  List<VitalsRecord> _allVitalsData = [];
  int _visibleCount = 1;
  
  // Device states
  bool _ecgEnabled = true;
  bool _vitalsEnabled = true;
  int _ecgSyncInterval = 5;
  int _vitalsSyncInterval = 5;

  @override
  void initState() {
    super.initState();
    _initializeDeviceManager();
  }

  Future<void> _initializeDeviceManager() async {
    await _deviceManager.initialize();
    
    // Sync device states
    setState(() {
      _ecgEnabled = _deviceManager.ecgMonitorEnabled;
      _vitalsEnabled = _deviceManager.isVitalsMonitoringEnabled;
      _ecgSyncInterval = _deviceManager.ecgSyncInterval;
      _vitalsSyncInterval = _deviceManager.vitalsSyncInterval;
    });

    // Listen to device state changes
    _deviceStateSubscription = _deviceManager.deviceStateStream.listen((deviceStates) {
      if (mounted) {
        setState(() {
          _ecgEnabled = deviceStates['ecg'] ?? true;
          _vitalsEnabled = _deviceManager.isVitalsMonitoringEnabled;
        });
        // Restart data fetching if enabled devices changed
        _fetchAllData();
      }
    });

    // Listen to sync interval changes
    _syncIntervalSubscription = _deviceManager.syncIntervalStream.listen((intervals) {
      if (mounted) {
        setState(() {
          _ecgSyncInterval = intervals['ecg'] ?? 5;
          _vitalsSyncInterval = intervals['vitals'] ?? 5;
        });
        // Restart timer with new intervals
        _restartTimer();
      }
    });

    _fetchAllData();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_ecgEnabled || _vitalsEnabled) {
      // Determine which intervals to use based on enabled devices
      List<int> activeIntervals = [];
      if (_ecgEnabled) activeIntervals.add(_ecgSyncInterval);
      if (_vitalsEnabled) activeIntervals.add(_vitalsSyncInterval);
      
      if (activeIntervals.isNotEmpty) {
        // Use the minimum interval for the timer
        final minInterval = activeIntervals.reduce((a, b) => a < b ? a : b);
        _timer = Timer.periodic(Duration(seconds: minInterval), (_) => _revealNextRow());
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _deviceStateSubscription?.cancel();
    _syncIntervalSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    if (!_ecgEnabled && !_vitalsEnabled) {
      // If no devices are enabled, clear data and stop timer
      setState(() {
        _allEcgData = [];
        _allVitalsData = [];
        _visibleCount = 0;
      });
      _timer?.cancel();
      return;
    }

    try {
      List<ECGRecord> ecgData = [];
      List<VitalsRecord> vitalsData = [];

      if (_ecgEnabled) {
        ecgData = await _apiService.fetchEcg(50);
      }
      
      if (_vitalsEnabled) {
        vitalsData = await _apiService.fetchVitals(50);
      }

      if (mounted) {
        setState(() {
          _allEcgData = ecgData;
          _allVitalsData = vitalsData;
          
          // Set initial visible count based on available data
          if ((_ecgEnabled && ecgData.isNotEmpty) || (_vitalsEnabled && vitalsData.isNotEmpty)) {
            _visibleCount = 1;
          } else {
            _visibleCount = 0;
          }
        });
        _restartTimer();
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    }
  }

  void _revealNextRow() {
    if (!mounted) return;
    setState(() {
      // Check the maximum count based on enabled devices
      int maxCount = 0;
      if (_ecgEnabled && _allEcgData.isNotEmpty) {
        maxCount = math.max(maxCount, _allEcgData.length);
      }
      if (_vitalsEnabled && _allVitalsData.isNotEmpty) {
        maxCount = math.max(maxCount, _allVitalsData.length);
      }
      
      if (maxCount > 0) {
        if (_visibleCount < maxCount) {
          _visibleCount++;
        } else {
          // Reset to beginning when we reach the end for continuous loop
          _visibleCount = 1;
        }
      } else {
        // No data available, cancel timer
        _timer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health Trends',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  if (_ecgEnabled) ...[
                    _buildECGSection(),
                    const SizedBox(height: 16),
                  ],
                  if (_vitalsEnabled && _allVitalsData.isNotEmpty && _visibleCount > 0) ...[
                    _buildBPTrendCard(_getVisibleVitalsData()),
                    const SizedBox(height: 16),
                    _buildMultiVitalsChart(_getVisibleVitalsData()),
                    const SizedBox(height: 16),
                    _buildSpO2Chart(_getVisibleVitalsData()),
                    const SizedBox(height: 16),
                  ],
                  if (!_ecgEnabled && !_vitalsEnabled) ...[
                    _buildNoDataMessage(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<VitalsRecord> _getVisibleVitalsData() {
    if (_allVitalsData.isEmpty || _visibleCount <= 0) return [];
    
    return _allVitalsData.take(_visibleCount).toList();
  }

  Widget _buildECGSection() {
    if (!_ecgEnabled) {
      return _buildDisabledCard('ECG Monitor', 'ECG monitoring is currently disabled');
    }

    if (_allEcgData.isEmpty || _visibleCount == 0) {
      return _buildLoadingCard('ECG Monitor', 'Loading ECG data...');
    }

    // Show the latest revealed ECG record (with wraparound)
    final ecgIndex = (_visibleCount - 1) % _allEcgData.length;
    final ecgRecord = _allEcgData[ecgIndex];

    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'ECG Monitor',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    horizontalInterval: 0.2,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.green.withOpacity(0.2),
                        strokeWidth: 0.5,
                      );
                    },
                    drawVerticalLine: true,
                    verticalInterval: 20,
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.green.withOpacity(0.2),
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  backgroundColor: Colors.black87,
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: ecgRecord.signal.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 1.5,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.1),
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

  Widget _buildBPTrendCard(List<VitalsRecord> vitalsData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Blood Pressure Trend',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  // Systolic BP line
                  LineChartBarData(
                    spots: vitalsData.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.vitals.systolicBp,
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                  // Diastolic BP line
                  LineChartBarData(
                    spots: vitalsData.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.vitals.diastolicBp,
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                ],
                minY: 40,
                maxY: 200,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Systolic', Colors.red),
              const SizedBox(width: 20),
              _buildLegendItem('Diastolic', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMultiVitalsChart(List<VitalsRecord> vitalsData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Heart Rate, Pulse Pressure & HRV',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawHorizontalLine: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, interval: 20, reservedSize: 40),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  // Heart Rate
                  LineChartBarData(
                    spots: vitalsData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.vitals.heartRate);
                    }).toList(),
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                  // Pulse Pressure
                  LineChartBarData(
                    spots: vitalsData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.vitals.derivedPulsePressure);
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                  // HRV
                  LineChartBarData(
                    spots: vitalsData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.vitals.derivedHrv);
                    }).toList(),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                ],
                minY: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Heart Rate', Colors.red),
              const SizedBox(width: 20),
              _buildLegendItem('Pulse Pressure', Colors.blue),
              const SizedBox(width: 20),
              _buildLegendItem('HRV', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpO2Chart(List<VitalsRecord> vitalsData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SpO₂',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawHorizontalLine: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: vitalsData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.vitals.spo2);
                    }).toList(),
                    isCurved: true,
                    color: Colors.purple,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.purple.withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 90,
                maxY: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTrendCard(String title, String unit, Color color, List<double> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  unit,
                  style: GoogleFonts.poppins(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
                        if (value.toInt() < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              labels[value.toInt()],
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      data.length,
                      (i) => FlSpot(i.toDouble(), data[i]),
                    ),
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: color,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.monitor_heart_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Monitoring Devices Enabled',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enable monitoring devices in your profile settings to view health trends',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledCard(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(
            Icons.monitor_heart_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
} 