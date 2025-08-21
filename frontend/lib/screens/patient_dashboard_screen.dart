import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'patient_login_screen.dart';
import '../services/api_service.dart';
import '../services/device_manager.dart';
import '../models/vitals_record.dart';
import '../services/firebase_service.dart';
import 'chat_thread_screen.dart';
import '../services/chat_service.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final ApiService _apiService = ApiService('http://127.0.0.1:8000');
  final DeviceManager _deviceManager = DeviceManager();
  Timer? _timer;
  Timer? _tempTimer;
  StreamSubscription<Map<String, bool>>? _deviceStateSubscription;
  StreamSubscription<Map<String, int>>? _syncIntervalSubscription;
  
  List<VitalsRecord> _allVitalsData = [];
  int _currentIndex = 0;
  double _currentTemperature = 36.8; // Dynamic temperature
  
  // Device states
  bool _heartRateEnabled = true;
  bool _spo2Enabled = true;
  bool _temperatureEnabled = true;
  int _vitalsSyncInterval = 5;
  int _temperatureSyncInterval = 7;
  String? _patientName;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _initializeDeviceManager();
    _loadPatientProfile();
  }

  Future<void> _loadPatientProfile() async {
    final id = await AuthService.getCurrentUserId();
    if (id == null) return;
    try {
      final data = await FirebaseService.readDocument('patients', id);
      if (data != null && mounted) {
        setState(() { _patientName = data['name'] ?? _patientName; });
      }
    } catch (_) {}
  }

  Future<void> _initializeDeviceManager() async {
    await _deviceManager.initialize();
    
    // Sync device states
    setState(() {
      _heartRateEnabled = _deviceManager.heartRateMonitorEnabled;
      _spo2Enabled = _deviceManager.spo2MonitorEnabled;
      _temperatureEnabled = _deviceManager.temperatureMonitorEnabled;
      _vitalsSyncInterval = _deviceManager.vitalsSyncInterval;
      _temperatureSyncInterval = _deviceManager.temperatureSyncInterval;
    });

    // Listen to device state changes
    _deviceStateSubscription = _deviceManager.deviceStateStream.listen((deviceStates) {
      if (mounted) {
        setState(() {
          _heartRateEnabled = deviceStates['heartRate'] ?? true;
          _spo2Enabled = deviceStates['spo2'] ?? true;
          _temperatureEnabled = deviceStates['temperature'] ?? true;
        });
        // Restart data fetching based on enabled devices
        _restartDataFetching();
      }
    });

    // Listen to sync interval changes
    _syncIntervalSubscription = _deviceManager.syncIntervalStream.listen((intervals) {
      if (mounted) {
        setState(() {
          _vitalsSyncInterval = intervals['vitals'] ?? 5;
          _temperatureSyncInterval = intervals['temperature'] ?? 7;
        });
        // Restart timers with new intervals
        _restartDataFetching();
      }
    });

    _restartDataFetching();
  }

  void _restartDataFetching() {
    // Stop existing timers
    _timer?.cancel();
    _tempTimer?.cancel();

    // Start vitals fetching if heart rate or spo2 is enabled
    if (_heartRateEnabled || _spo2Enabled) {
      _fetchAllData();
    }

    // Start temperature simulation if enabled
    if (_temperatureEnabled) {
      _startTemperatureSimulation();
    }
  }

  Future<void> _fetchAllData() async {
    // Only fetch data if heart rate or SpO2 monitoring is enabled
    if (!_heartRateEnabled && !_spo2Enabled) {
      _timer?.cancel();
      setState(() {
        _allVitalsData = [];
        _currentIndex = 0;
      });
      return;
    }

    try {
      final vitalsData = await _apiService.fetchVitals(30); // Fetch 30 records
      if (mounted && vitalsData.isNotEmpty) {
        setState(() {
          _allVitalsData = vitalsData;
          _currentIndex = 0;
        });
        _timer?.cancel();
        _timer = Timer.periodic(Duration(seconds: _vitalsSyncInterval), (_) => _showNextRecord());
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

  void _showNextRecord() {
    if (!mounted || _allVitalsData.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _allVitalsData.length;
    });
  }

  void _startTemperatureSimulation() {
    // Only start temperature simulation if temperature monitoring is enabled
    if (!_temperatureEnabled) {
      _tempTimer?.cancel();
      return;
    }

    _tempTimer = Timer.periodic(Duration(seconds: _temperatureSyncInterval), (timer) {
      if (!mounted || !_temperatureEnabled) return;
      
      setState(() {
        // Generate random temperature in normal range (36.1°C - 37.2°C)
        // Using sine wave with random variation for realistic fluctuation
        final baseTemp = 36.65; // Average normal temperature
        final variation = 0.55; // Range variation (±0.55°C)
        final timeComponent = math.sin(timer.tick * 0.1) * 0.3;
        final randomComponent = (math.Random().nextDouble() - 0.5) * 0.4;
        
        _currentTemperature = baseTemp + (variation * timeComponent) + randomComponent;
        
        // Ensure temperature stays within reasonable bounds
        _currentTemperature = _currentTemperature.clamp(36.0, 37.5);
      });
    });
  }

  Color _getTemperatureColor() {
    if (_currentTemperature >= 37.3) return Colors.red; // High fever
    if (_currentTemperature >= 37.0) return Colors.orange; // Mild fever
    if (_currentTemperature <= 36.0) return Colors.blue; // Low temperature
    return Colors.green; // Normal temperature
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tempTimer?.cancel();
    _controller.dispose();
    _deviceStateSubscription?.cancel();
    _syncIntervalSubscription?.cancel();
    super.dispose();
  }

  Widget _buildVitalsGrid() {
    final hasData = _allVitalsData.isNotEmpty;
    final current = hasData ? _allVitalsData[_currentIndex] : null;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildVitalCard(
                'Heart Rate',
                _heartRateEnabled ? (hasData && current != null ? '${current.vitals.heartRate.toInt()}' : '--') : 'OFF',
                'bpm',
                Icons.favorite,
                _heartRateEnabled ? Colors.red : Colors.grey,
                isEnabled: _heartRateEnabled,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildVitalCard(
                'SpO₂',
                _spo2Enabled ? (hasData && current != null ? '${current.vitals.spo2.toInt()}' : '--') : 'OFF',
                '%',
                Icons.air,
                _spo2Enabled ? Colors.blue : Colors.grey,
                isEnabled: _spo2Enabled,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildVitalCard(
                'Weight',
                '75',
                'kg',
                Icons.monitor_weight,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildVitalCard(
                'Height',
                '175',
                'cm',
                Icons.height,
                Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildVitalCard(
                'Temperature',
                _temperatureEnabled ? '${_currentTemperature.toStringAsFixed(1)}' : 'OFF',
                '°C',
                Icons.thermostat,
                _temperatureEnabled ? _getTemperatureColor() : Colors.grey,
                isEnabled: _temperatureEnabled,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildVitalCard(
                'BMI',
                '24.5',
                'kg/m²',
                Icons.straighten,
                Colors.green,
              ),
            ),
          ],
        ),
        if (hasData && current != null && current.prediction.risk != 'Normal')
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildRiskAlert(current.prediction),
          ),
      ],
    );
  }

  Widget _buildVitalCard(String title, String value, String unit, IconData icon, Color color, {bool isEnabled = true}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isEnabled ? 0.1 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(isEnabled ? 0.1 : 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskAlert(VitalsPrediction prediction) {
    final isHighRisk = prediction.risk == 'High';
    final color = isHighRisk ? Colors.red : Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.shade50,
            color.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHighRisk ? Icons.warning : Icons.info_outline,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk Level: ${prediction.risk}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Probability: ${(prediction.probability * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: color.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader()
                    .animate()
                    .fadeIn(duration: 300.ms),
                const SizedBox(height: 24),
                Text(
                  'Current Vitals',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 16),
                _buildVitalsGrid()
                    .animate()
                    .fadeIn(duration: 300.ms),
                const SizedBox(height: 24),
                _buildQuickActions()
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 400.ms)
                    .slideY(begin: 30, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.1),
            const Color(0xFF6C63FF).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Hero(
                tag: 'profile_pic',
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6C63FF),
                      width: 2,
                    ),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: 'https://placekitten.com/100/100',
                    imageBuilder: (context, imageProvider) => CircleAvatar(
                      radius: 24,
                      backgroundImage: imageProvider,
                    ),
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: const CircleAvatar(radius: 24),
                    ),
                    errorWidget: (context, url, error) => const CircleAvatar(
                      radius: 24,
                      child: Icon(Icons.error),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _patientName != null ? 'Hello, ${_patientName!}' : 'Hello',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    DateFormat('MMMM d, yyyy').format(DateTime.now()),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.power_settings_new,
              color: Colors.grey[700],
            ),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await AuthService.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const PatientLoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton('View\nHistory', Icons.history_outlined, onTap: () {}),
        _buildActionButton('Send\nAlert', Icons.warning_outlined, onTap: () {}),
        _buildActionButton('Contact\nDoctor', Icons.phone_outlined, onTap: _openChatWithDoctor),
      ].animate(interval: 200.ms).slideY(begin: 30, end: 0).fadeIn(),
    );
  }

  Widget _buildActionButton(String label, IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: const Color(0xFF6C63FF),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black87,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChatWithDoctor() async {
    final patientId = await AuthService.getCurrentUserId();
    if (patientId == null) return;
    try {
      final patientData = await FirebaseService.readDocument('patients', patientId);
      if (patientData == null) return;
      final doctorId = patientData['assignedDoctorId'];
      if (doctorId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No doctor assigned')),
          );
        }
        return;
      }
      // Fetch doctor name (optional)
      final doctorData = await FirebaseService.readDocument('doctors', doctorId);
      final doctorName = doctorData != null ? (doctorData['name'] ?? 'Doctor') : 'Doctor';
      if (!mounted) return;
  // Ensure thread exists
  await ChatService.createThreadIfAbsent(doctorId: doctorId, patientId: patientId);
  if (!mounted) return;
  Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            doctorId: doctorId,
            patientId: patientId,
            patientName: patientData['name'] ?? 'Patient',
            doctorName: doctorName,
            currentUserRole: 'patient',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open chat: $e')),
        );
      }
    }
  }
}