import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firebase_patient_service.dart';
import '../services/api_service.dart';
import '../services/device_manager.dart';
import '../models/ecg_record.dart';
import '../models/vitals_record.dart';
import 'splash_screen.dart';
import '../services/chat_service.dart';
import 'chat_thread_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  String selectedTab = 'Schedule';
  String? doctorName;
  String? doctorSpecialty;
  final List<String> tabs = ['Schedule', 'Messages', 'Reports', 'Settings'];
  final ApiService _apiService = ApiService('http://127.0.0.1:8000');
  final DeviceManager _deviceManager = DeviceManager();
  Timer? _refreshTimer;
  StreamSubscription? _deviceSubscription;
  int _refreshIntervalSeconds = 30; // configurable in Settings
  
  final List<Map<String, dynamic>> appointments = [
    {
      'name': 'Sarah Johnson',
      'condition': 'Heart rate 120 BPM',
      'time': '20 mins ago',
      'severity': 'high',
    },
    {
      'name': 'Robert Williams',
      'condition': 'SpO2 94%',
      'time': '25 mins ago',
      'severity': 'medium',
    },
  ];

  Map<String, int> overview = {
    'appointments': 4,
    'urgent_cases': 2,
    'completed': 8,
    'total_patients': 12,
    'critical_alerts': 1,
    'pending_reviews': 3,
  };

  List<Map<String, dynamic>> patients = [];
  List<Map<String, dynamic>> realTimeAlerts = [];
  bool isLoading = true;
  String searchQuery = '';
  String selectedPriority = 'All';
  final List<String> priorityFilters = ['All', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _initializeRealTimeMonitoring();
    _startPeriodicUpdates();
    _loadDoctorProfile();
  }

  Future<void> _loadDoctorProfile() async {
    final id = await AuthService.getCurrentUserId();
    if (id == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('doctors').doc(id).get();
      if (snap.exists && mounted) {
        setState(() {
          doctorName = (snap.data()?['name'] as String?) ?? doctorName;
          doctorSpecialty = (snap.data()?['specialty'] as String?) ?? doctorSpecialty;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _deviceSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeRealTimeMonitoring() async {
    await _deviceManager.initialize();
    
    // Listen to device state changes for system-wide monitoring
    _deviceSubscription = _deviceManager.deviceStateStream.listen((deviceStates) {
      if (mounted) {
        _updateSystemOverview(deviceStates);
      }
    });
  }

  void _startPeriodicUpdates() {
    // Refresh data every 30 seconds
  _refreshTimer = Timer.periodic(Duration(seconds: _refreshIntervalSeconds), (timer) {
      if (mounted) {
        _fetchRealTimeAlerts();
        _updateOverviewMetrics();
      }
    });
    
    // Initial fetch
    _fetchRealTimeAlerts();
  }

  Future<void> _fetchRealTimeAlerts() async {
    try {
      // Fetch recent health data to generate alerts
      final vitalsData = await _apiService.fetchVitals(50); // Latest 50 records
      final ecgData = await _apiService.fetchEcg(50);
      
      List<Map<String, dynamic>> newAlerts = [];
      
      // Generate alerts from recent data - ensure we don't exceed data bounds
      final vitalsToCheck = vitalsData.take(math.min(5, vitalsData.length));
      for (int i = 0; i < vitalsToCheck.length; i++) {
        final vital = vitalsToCheck.elementAt(i);
        if (vital.vitals.heartRate > 120 || vital.vitals.heartRate < 50) {
          newAlerts.add({
            'patient': 'Patient ${(i + 1).toString().padLeft(3, '0')}',
            'type': 'critical',
            'message': 'Heart rate: ${vital.vitals.heartRate.round()} bpm',
            'timestamp': DateTime.now(),
            'icon': Icons.favorite,
          });
        }
        
        if (vital.vitals.spo2 < 95) {
          newAlerts.add({
            'patient': 'Patient ${(i + 1).toString().padLeft(3, '0')}',
            'type': 'warning',
            'message': 'SpO₂: ${vital.vitals.spo2.round()}%',
            'timestamp': DateTime.now(),
            'icon': Icons.air,
          });
        }
      }
      
      final ecgToCheck = ecgData.take(math.min(3, ecgData.length));
      for (int i = 0; i < ecgToCheck.length; i++) {
        final ecg = ecgToCheck.elementAt(i);
        if (ecg.prediction.label != 'Normal') {
          newAlerts.add({
            'patient': 'Patient ${(i + 1).toString().padLeft(3, '0')}',
            'type': 'critical',
            'message': 'ECG: ${ecg.prediction.label}',
            'timestamp': DateTime.now(),
            'icon': Icons.monitor_heart,
          });
        }
      }
      
      if (mounted) {
        setState(() {
          realTimeAlerts = newAlerts;
        });
      }
    } catch (e) {
      debugPrint('Error fetching real-time alerts: $e');
    }
  }

  void _updateSystemOverview(Map<String, bool> deviceStates) {
    // Update overview based on device states
    int activeDevices = deviceStates.values.where((enabled) => enabled).length;
    int disabledDevices = deviceStates.values.where((enabled) => !enabled).length;
    
    setState(() {
      overview['active_devices'] = activeDevices;
      overview['disabled_devices'] = disabledDevices;
    });
  }

  void _updateOverviewMetrics() {
    // Simulate dynamic updates to overview metrics
    setState(() {
      overview['critical_alerts'] = realTimeAlerts.where((alert) => alert['type'] == 'critical').length;
      overview['urgent_cases'] = realTimeAlerts.length;
    });
  }

  Future<void> _loadPatients() async {
    setState(() {
      isLoading = true;
    });
    final doctorId = await AuthService.getCurrentUserId();
    if (doctorId != null) {
      final fetchedPatients = await FirebasePatientService.fetchPatientsForDoctor(doctorId);
      setState(() {
        patients = fetchedPatients;
        isLoading = false;
      });
    } else {
      setState(() {
        patients = [];
        isLoading = false;
      });
    }
  }

  void _handleTabSelection(String tab) {
    setState(() => selectedTab = tab);
    // Here you would typically load different data based on the selected tab
  }

  Widget _buildScheduleTab() {
    // Restored original layout: overview + patients list
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildOverview(),
          const SizedBox(height: 24),
          _buildPatientsList(),
        ],
      ),
    );
  }


  Widget _buildMessagesTab() {
    return FutureBuilder<String?>(
      future: AuthService.getCurrentUserId(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final doctorId = snapshot.data!;
        return StreamBuilder(
          stream: ChatService.streamDoctorThreads(doctorId),
          builder: (context, AsyncSnapshot snapshot2) {
            if (snapshot2.hasError) {
              final msg = snapshot2.error.toString();
              // Common Firestore error hints
              String hint = '';
              if (msg.contains('permission-denied')) {
                hint = '\nPermission denied – verify Firestore rules allow doctor access to chat_threads.';
              } else if (msg.contains('FAILED_PRECONDITION') && msg.contains('index')) {
                hint = '\nFirestore requires an index for doctorId + updatedAt. Create the suggested index link from console.';
              }
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                    const SizedBox(height: 12),
                    Text('Failed to load conversations', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(msg + hint, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot2.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final threadDocs = (snapshot2.data.docs as List).cast<dynamic>();
            // Map patientId -> name from loaded patients
            final Map<String, String> patientNameById = {
              for (final p in patients)
                if (p['id'] != null) p['id'] as String: (p['name'] ?? 'Patient') as String
            };
            final Set<String> threadPatientIds = threadDocs
                .map<String>((d) => (d.data()['patientId'] as String))
                .toSet();

            // Build unified items list: existing threads + patients without threads
            final List<Map<String, dynamic>> items = [];

            for (final d in threadDocs) {
              final data = d.data();
              items.add({
                'patientId': data['patientId'],
                'lastMessage': data['lastMessage'] ?? '',
                'updatedAt': data['updatedAt'],
                'unreadForDoctor': data['unreadForDoctor'],
                'isThread': true,
              });
            }
            for (final p in patients) {
              final pid = p['id'];
              if (pid is String && !threadPatientIds.contains(pid)) {
                items.add({
                  'patientId': pid,
                  'lastMessage': '',
                  'updatedAt': null,
                  'unreadForDoctor': 0,
                  'isThread': false,
                });
              }
            }

            // Sort: threads with recent updatedAt first, then those without
            items.sort((a, b) {
              final at = a['updatedAt'];
              final bt = b['updatedAt'];
              if (at == null && bt == null) return 0;
              if (at == null) return 1;
              if (bt == null) return -1;
              try {
                return (bt.seconds as int).compareTo(at.seconds as int);
              } catch (_) { return 0; }
            });

            if (items.isEmpty) {
              return Center(
                child: isLoading
                    ? const CircularProgressIndicator()
                    : Text('No assigned patients', style: GoogleFonts.poppins(color: Colors.grey)),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final data = items[i];
                final patientId = data['patientId'] as String;
                final name = patientNameById[patientId] ?? 'Patient';
                final lastMessage = (data['lastMessage'] ?? '') as String;
                final updatedAt = data['updatedAt'];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    lastMessage.isEmpty ? 'Tap to open conversation' : lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildUnreadBadge(data['unreadForDoctor']),
                      if (updatedAt != null)
                        Text(
                          _formatUpdatedAt(updatedAt),
                          style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                  onTap: () async {
                    await ChatService.createThreadIfAbsent(
                      doctorId: doctorId,
                      patientId: patientId,
                    );
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatThreadScreen(
                          doctorId: doctorId,
                          patientId: patientId,
                          patientName: name,
                          doctorName: 'Doctor',
                          currentUserRole: 'doctor',
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatUpdatedAt(dynamic ts) {
    try {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 1) return 'now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m';
        if (diff.inHours < 24) return '${diff.inHours}h';
        return '${diff.inDays}d';
      }
    } catch (_) {}
    return '';
  }

  Widget _buildUnreadBadge(dynamic count) {
    if (count == null) return const SizedBox.shrink();
    final c = (count is int) ? count : 0;
    if (c <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$c', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
    );
  }

  void _startRealTimeMonitoring(Map<String, dynamic> patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.monitor_heart, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Start Real-Time Monitoring',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient: ${patient['name']}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Available monitoring options:',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...['ECG Monitor', 'Blood Pressure', 'Heart Rate', 'Blood Oxygen'].map(
              (option) => CheckboxListTile(
                title: Text(
                  option,
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
                value: true,
                dense: true,
                onChanged: null, // Keep checked for demo
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Enable all devices for monitoring
              await DeviceManager().updateDeviceState('ecg', true);
              await DeviceManager().updateDeviceState('bloodPressure', true);
              await DeviceManager().updateDeviceState('heartRate', true);
              await DeviceManager().updateDeviceState('spo2', true);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Real-time monitoring started for ${patient['name']}',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Start Monitoring',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  void _handlePatientAction(String action, Map<String, dynamic> patient) {
    switch (action) {
      case 'view':
        // Navigate to patient details screen
        _showPatientDetails(patient);
        break;
      case 'message':
        // Open messaging interface
        _showMessageDialog(patient);
        break;
      case 'more':
        // Show more options
        _showMoreOptions(patient);
        break;
    }
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PatientDetailsModal(patient: patient),
    );
  }

  void _showMessageDialog(Map<String, dynamic> patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Message ${patient['name']}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          decoration: InputDecoration(
            hintText: 'Type your message...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Handle message sending
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                'Schedule Appointment',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
                // Handle scheduling
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                'View History',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
                // Handle history view
              },
            ),
            ListTile(
              leading: const Icon(Icons.medical_services),
              title: Text(
                'Update Treatment',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
                // Handle treatment update
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildTabBar(),
              const SizedBox(height: 24),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (selectedTab == 'Messages') {
                      return _buildMessagesTab();
                    } else if (selectedTab == 'Reports') {
                      return _buildReportsTab();
                    } else if (selectedTab == 'Settings') {
                      return _buildSettingsTab();
                    } else {
                      return _buildScheduleTab();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return FutureBuilder<String?>(
      future: AuthService.getCurrentUserId(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final doctorId = snap.data!;
        return StreamBuilder(
          stream: ChatService.streamDoctorThreads(doctorId),
          builder: (context, threadSnap) {
            final threadDocs = threadSnap.hasData ? (threadSnap.data!.docs as List) : [];
            int totalThreads = threadDocs.length;
            final critical = realTimeAlerts.where((a) => a['type'] == 'critical').length;
            final warning = realTimeAlerts.where((a) => a['type'] == 'warning').length;
            final normal = (overview['total_patients'] ?? 0) - (critical + warning);

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reports & Analytics', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _metricCard('Patients', overview['total_patients']?.toString() ?? '--', Icons.groups, Colors.indigo),
                      _metricCard('Threads', '$totalThreads', Icons.chat_bubble_outline, Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Alert Distribution', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: _buildAlertPie(critical: critical, warning: warning, normal: normal < 0 ? 0 : normal),
                  ),
                  const SizedBox(height: 24),
                  Text('Recent Alerts', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (realTimeAlerts.isEmpty)
                    Text('No alerts generated yet', style: GoogleFonts.poppins(color: Colors.grey[600]))
                  else
                    ...realTimeAlerts.take(6).map((a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: (a['type']=='critical'? Colors.red: Colors.amber).withOpacity(.15), child: Icon(a['icon'] as IconData?, color: a['type']=='critical'? Colors.red: Colors.amber)),
                      title: Text(a['patient'] ?? 'Patient', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(a['message'] ?? '', style: GoogleFonts.poppins(fontSize: 12)),
                    )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildAlertPie({required int critical, required int warning, required int normal}) {
    final total = (critical + warning + normal).clamp(1, 100000);
    final List<PieChartSectionData> sections = [
      PieChartSectionData(value: critical.toDouble(), color: Colors.red, title: critical==0? '': critical.toString(), radius: 50, titleStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
      PieChartSectionData(value: warning.toDouble(), color: Colors.orange, title: warning==0? '': warning.toString(), radius: 50, titleStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
      PieChartSectionData(value: normal.toDouble(), color: Colors.green, title: normal==0? '': normal.toString(), radius: 50, titleStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
    ];
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              borderData: FlBorderData(show: false),
              centerSpaceColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legendDot('Critical', Colors.red),
            _legendDot('Warning', Colors.orange),
            _legendDot('Normal', Colors.green),
            const SizedBox(height: 8),
            Text('Total: $total', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        )
      ],
    );
  }

  Widget _legendDot(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 11)),
        ],
      ),
    );
  }

  void _updateRefreshInterval(int seconds) {
    setState(() {
      _refreshIntervalSeconds = seconds;
      _refreshTimer?.cancel();
      _startPeriodicUpdates();
    });
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _settingsCard(
            title: 'Data Refresh Interval',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _refreshIntervalSeconds.toDouble(),
                  min: 10,
                  max: 120,
                  divisions: 11,
                  label: '${_refreshIntervalSeconds}s',
                  onChanged: (v) => _updateRefreshInterval(v.round()),
                ),
                Text('Every $_refreshIntervalSeconds seconds', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
          _settingsCard(
            title: 'Account',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profile'),
                  subtitle: const Text('View or edit profile (future)'),
                  onTap: () {},
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () => _handleLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 8, offset: const Offset(0,4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }


  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundImage: null,
              child: Icon(Icons.person, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorName ?? 'Doctor',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (doctorSpecialty != null)
                  Text(
                    doctorSpecialty!,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'On Duty',
                style: GoogleFonts.poppins(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.power_settings_new, color: Colors.grey[700]),
              onPressed: () => _handleLogout(context),
            ),
          ],
        ),
      ],
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
                MaterialPageRoute(builder: (context) => const SplashScreen()),
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

  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          bool isSelected = selectedTab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 24),
            child: InkWell(
              onTap: () => _handleTabSelection(tab),
              child: Column(
                children: [
                  Text(
                    tab,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.black87 : Colors.grey,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isSelected)
                    Container(
                      height: 2,
                      width: 24,
                      color: Colors.black87,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'System Overview',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: realTimeAlerts.isNotEmpty ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    realTimeAlerts.isNotEmpty ? Icons.warning : Icons.check_circle,
                    size: 12,
                    color: realTimeAlerts.isNotEmpty ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    realTimeAlerts.isNotEmpty ? 'Active Alerts' : 'All Normal',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: realTimeAlerts.isNotEmpty ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // First row of metrics
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOverviewItem(
              overview['appointments'].toString(),
              'Appointments',
              Icons.calendar_today,
              Colors.blue,
            ),
            _buildOverviewItem(
              overview['urgent_cases'].toString(),
              'Urgent Cases',
              Icons.warning_rounded,
              Colors.orange,
            ),
            _buildOverviewItem(
              overview['completed'].toString(),
              'Completed',
              Icons.check_circle,
              Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row of metrics
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOverviewItem(
              overview['total_patients'].toString(),
              'Total Patients',
              Icons.people,
              Colors.purple,
            ),
            _buildOverviewItem(
              overview['critical_alerts'].toString(),
              'Critical Alerts',
              Icons.emergency,
              Colors.red,
            ),
            _buildOverviewItem(
              overview['pending_reviews'].toString(),
              'Pending Reviews',
              Icons.rate_review,
              Colors.indigo,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Real-time alerts panel
        _buildRealTimeAlertsPanel(),
        const SizedBox(height: 16),
        // Notifications panel
        _buildNotificationsPanel(),
      ],
    );
  }

  Widget _buildRealTimeAlertsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: realTimeAlerts.isNotEmpty ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: realTimeAlerts.isNotEmpty ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                realTimeAlerts.isNotEmpty ? Icons.priority_high : Icons.verified_rounded,
                color: realTimeAlerts.isNotEmpty ? Colors.red : Colors.green,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                realTimeAlerts.isNotEmpty ? 'Live Alerts (${realTimeAlerts.length})' : 'All Systems Normal',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: realTimeAlerts.isNotEmpty ? Colors.red.shade800 : Colors.green.shade800,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.circle,
                color: realTimeAlerts.isNotEmpty ? Colors.red : Colors.green,
                size: 8,
              ),
              const SizedBox(width: 4),
              Text(
                'LIVE',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: realTimeAlerts.isNotEmpty ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          if (realTimeAlerts.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...realTimeAlerts.take(3).map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    alert['type'] == 'critical' ? Icons.emergency : Icons.warning,
                    color: alert['type'] == 'critical' ? Colors.red : Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert['message'],
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'now',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )).toList(),
            if (realTimeAlerts.length > 3) ...[
              const SizedBox(height: 4),
              Text(
                '+ ${realTimeAlerts.length - 3} more alerts',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'No urgent alerts • All vitals within normal ranges',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewItem(
    String count,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          count,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
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

  Widget _buildNotificationsPanel() {
    final notifications = [
      {
        'title': 'Sarah Johnson',
        'message': 'Heart rate 120 BPM - Requires immediate attention',
        'time': '20 mins ago',
        'priority': 'high',
        'icon': Icons.favorite,
      },
      {
        'title': 'Robert Williams',
        'message': 'SpO2 94% - Below normal range',
        'time': '25 mins ago',
        'priority': 'medium',
        'icon': Icons.air,
      },
      {
        'title': 'Emma Davis',
        'message': 'Medication reminder due',
        'time': '1 hour ago',
        'priority': 'low',
        'icon': Icons.medication,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Notifications',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${notifications.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...notifications.map((notification) => _buildNotificationItem(notification)).toList(),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    Color priorityColor;
    Color bgColor;
    
    switch (notification['priority']) {
      case 'high':
        priorityColor = Colors.red;
        bgColor = Colors.red.shade50;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        bgColor = Colors.orange.shade50;
        break;
      default:
        priorityColor = Colors.blue;
        bgColor = Colors.blue.shade50;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: priorityColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: priorityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              notification['icon'],
              color: priorityColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['title'],
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: priorityColor,
                  ),
                ),
                Text(
                  notification['message'],
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Text(
            notification['time'],
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Patients',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                // Priority filter dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.indigo.shade50, Colors.indigo.shade100.withOpacity(.3)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: DropdownButton<String>(
                    value: selectedPriority,
                    underline: Container(),
                    isDense: true,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.indigo.shade700,
                    ),
                    items: priorityFilters.map((String priority) {
                      return DropdownMenuItem<String>(
                        value: priority,
                        child: Text(priority),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedPriority = newValue!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Search bar
                InkWell(
                  onTap: () => _showSearchDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.grey.shade100, Colors.grey.shade200]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 18, color: Colors.indigo.shade400),
                        const SizedBox(width: 4),
                        Text(
                          searchQuery.isEmpty ? 'Search' : searchQuery,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.indigo.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const Center(child: CircularProgressIndicator()),
        if (!isLoading && _filteredPatients.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'No patients found',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ..._filteredPatients.map((patient) => _buildEnhancedPatientCard(patient)).toList(),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredPatients {
    List<Map<String, dynamic>> filtered = List.from(patients);
    
    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((patient) {
        final name = patient['name']?.toString().toLowerCase() ?? '';
        final condition = patient['condition']?.toString().toLowerCase() ?? '';
        final searchLower = searchQuery.toLowerCase();
        return name.contains(searchLower) || condition.contains(searchLower);
      }).toList();
    }
    
    // Apply priority filter
    if (selectedPriority != 'All') {
      filtered = filtered.where((patient) {
        final priority = patient['priority']?.toString() ?? 'Low';
        return priority == selectedPriority;
      }).toList();
    }
    
    return filtered;
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Search Patients',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter patient name or condition...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                searchQuery = '';
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedPatientCard(Map<String, dynamic> patient) {
    // Add priority if not exists with safe access
    patient['priority'] ??= 'Low';
    patient['lastCheckup'] ??= '2 days ago';
    patient['vitalsStatus'] ??= 'Normal';
    patient['name'] ??= 'Unknown Patient';
    patient['age'] ??= 'N/A';
    patient['condition'] ??= 'No condition specified';
    
    Color priorityColor;
    IconData priorityIcon;
    
    switch (patient['priority']) {
      case 'High':
        priorityColor = Colors.red;
        priorityIcon = Icons.priority_high;
        break;
      case 'Medium':
        priorityColor = Colors.orange;
        priorityIcon = Icons.warning;
        break;
      default:
        priorityColor = Colors.green;
        priorityIcon = Icons.check_circle;
    }

    Color vitalsColor;
    switch (patient['vitalsStatus']) {
      case 'Critical':
        vitalsColor = Colors.red;
        break;
      case 'Warning':
        vitalsColor = Colors.orange;
        break;
      default:
        vitalsColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            priorityColor.withOpacity(.08),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: priorityColor.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(color: priorityColor.withOpacity(.12), blurRadius: 14, offset: const Offset(0,6)),
        ],
      ),
      child: Column(
        children: [
          // Header with priority indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: (patient['image'] != null && (patient['image'] as String).isNotEmpty)
                        ? NetworkImage(patient['image'])
                        : null,
                    child: (patient['image'] == null || (patient['image'] as String).isEmpty)
                        ? const Icon(Icons.person, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            patient['name']?.toString() ?? 'Unknown Patient',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(priorityIcon, size: 12, color: priorityColor),
                                const SizedBox(width: 2),
                                Text(
                                  patient['priority'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: priorityColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Age: ${patient['age']?.toString() ?? 'N/A'} | ${patient['condition']?.toString() ?? 'No condition'}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Real-time monitoring indicator
                          StreamBuilder<Map<String, bool>>(
                            stream: DeviceManager().deviceStateStream,
                            builder: (context, snapshot) {
                              final deviceStates = snapshot.data ?? {};
                              final isMonitoring = deviceStates.values.any((state) => state);
                              
                              if (isMonitoring) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'LIVE',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: vitalsColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.monitor_heart,
                  color: vitalsColor,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Status indicators
          Row(
            children: [
              Expanded(
                child: _buildStatusIndicator(
                  'Last Checkup',
                  patient['lastCheckup'],
                  Icons.schedule,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusIndicator(
                  'Vitals',
                  patient['vitalsStatus'],
                  Icons.favorite,
                  vitalsColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEnhancedActionButton(
                'Monitor',
                Icons.monitor_heart,
                Colors.red,
                onTap: () => _startRealTimeMonitoring(patient),
              ),
              _buildEnhancedActionButton(
                'Charts',
                Icons.analytics,
                Colors.blue,
                onTap: () => _handlePatientAction('view', patient),
              ),
              _buildEnhancedActionButton(
                'Call',
                Icons.phone,
                Colors.green,
                onTap: () => _showCallDialog(patient),
              ),
              _buildEnhancedActionButton(
                'More',
                Icons.more_horiz,
                Colors.grey,
                onTap: () => _handlePatientAction('more', patient),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedActionButton(
    String label,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCallDialog(Map<String, dynamic> patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.phone, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Call ${patient['name']}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.call, color: Colors.green),
              title: Text('Call Patient', style: GoogleFonts.poppins()),
              subtitle: Text('Primary number', style: GoogleFonts.poppins(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                // Handle calling patient
              },
            ),
            ListTile(
              leading: Icon(Icons.contact_emergency, color: Colors.red),
              title: Text('Emergency Contact', style: GoogleFonts.poppins()),
              subtitle: Text('Family member', style: GoogleFonts.poppins(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                // Handle calling emergency contact
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

}

class PatientDetailsModal extends StatefulWidget {
  final Map<String, dynamic> patient;
  
  const PatientDetailsModal({Key? key, required this.patient}) : super(key: key);
  
  @override
  State<PatientDetailsModal> createState() => _PatientDetailsModalState();
}

class _PatientDetailsModalState extends State<PatientDetailsModal> {
  final ApiService _apiService = ApiService('http://127.0.0.1:8000');
  List<ECGRecord> _allEcgData = [];
  List<VitalsRecord> _allVitalsData = [];
  bool _isLoadingChartData = false;
  Timer? _chartTimer;
  Timer? _vitalsTimer;
  int _visibleCount = 1;
  
  // Real-time vitals data
  double _currentHeartRate = 72.0;
  double _currentSpO2 = 98.0;
  double _currentTemp = 36.8;
  String _currentBPSystolic = '120';
  String _currentBPDiastolic = '80';
  String _heartRateStatus = 'Normal';
  String _spo2Status = 'Normal';

  @override
  void initState() {
    super.initState();
    _loadChartData();
    _startVitalsSimulation();
  }

  @override
  void dispose() {
    _chartTimer?.cancel();
    _vitalsTimer?.cancel();
    super.dispose();
  }

  void _startVitalsSimulation() {
    _vitalsTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      
      setState(() {
        // Simulate heart rate changes (60-100 normal range)
        _currentHeartRate = 65 + (35 * (0.5 + 0.5 * math.sin(timer.tick * 0.1)));
        _heartRateStatus = _currentHeartRate > 100 ? 'High' : 
                          _currentHeartRate < 60 ? 'Low' : 'Normal';
        
        // Simulate SpO2 changes (95-100 normal range)
        _currentSpO2 = 96 + (4 * (0.5 + 0.5 * math.cos(timer.tick * 0.15)));
        _spo2Status = _currentSpO2 < 95 ? 'Low' : 'Normal';
        
        // Simulate temperature changes (36.1-37.2 normal range)
        _currentTemp = 36.5 + (0.7 * (0.5 + 0.5 * math.sin(timer.tick * 0.05)));
        
        // Simulate blood pressure changes
        double systolic = 115 + (10 * (0.5 + 0.5 * math.sin(timer.tick * 0.08)));
        double diastolic = 75 + (10 * (0.5 + 0.5 * math.cos(timer.tick * 0.12)));
        _currentBPSystolic = systolic.toInt().toString();
        _currentBPDiastolic = diastolic.toInt().toString();
      });
    });
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isLoadingChartData = true;
    });
    
    try {
      debugPrint('Modal: Starting to load chart data...');
      
      final ecgData = await _apiService.fetchEcg(50);
      debugPrint('Modal: ECG data loaded: ${ecgData.length} records');
      
      final vitalsData = await _apiService.fetchVitals(50);
      debugPrint('Modal: Vitals data loaded: ${vitalsData.length} records');
      
      if (mounted) {
        setState(() {
          _allEcgData = ecgData;
          _allVitalsData = vitalsData;
          _visibleCount = 1;
          _isLoadingChartData = false;
        });
        
        debugPrint('Modal: State updated - ECG: ${_allEcgData.length}, Vitals: ${_allVitalsData.length}, Loading: $_isLoadingChartData');
        
        // Start streaming effect
        if (_allEcgData.isNotEmpty || _allVitalsData.isNotEmpty) {
          _chartTimer?.cancel();
          _chartTimer = Timer.periodic(const Duration(seconds: 2), (_) => _revealNextDataPoint());
          debugPrint('Modal: Started streaming timer');
        }
      }
    } catch (e) {
      debugPrint('Modal: Error loading chart data: $e');
      if (mounted) {
        setState(() {
          _isLoadingChartData = false;
        });
      }
    }
  }

  void _revealNextDataPoint() {
    if (!mounted) return;
    setState(() {
      // Check the maximum count based on available data
      int maxCount = 0;
      if (_allEcgData.isNotEmpty) {
        maxCount = math.max(maxCount, _allEcgData.length);
      }
      if (_allVitalsData.isNotEmpty) {
        maxCount = math.max(maxCount, _allVitalsData.length);
      }
      
      if (_visibleCount < maxCount) {
        _visibleCount++;
      } else {
        _chartTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Patient Details - ${widget.patient['name']}',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient basic info
                  _buildPatientBasicInfo(),
                  const SizedBox(height: 24),
                  
                  // Quick Actions Panel
                  _buildQuickActionsPanel(),
                  const SizedBox(height: 24),
                  
                  // ECG Chart
                  _buildECGChart(),
                  const SizedBox(height: 24),
                  
                  // BP Chart
                  _buildBPChart(),
                  const SizedBox(height: 24),
                  
                  // Additional Patient Info
                  _buildAdditionalInfo(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientBasicInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patient Information',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: (widget.patient['image'] != null && (widget.patient['image'] as String).isNotEmpty)
                    ? NetworkImage(widget.patient['image'])
                    : null,
                child: (widget.patient['image'] == null || (widget.patient['image'] as String).isEmpty)
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patient['name'],
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Age: ${widget.patient['age']}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Condition: ${widget.patient['condition']}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildECGChart() {
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
            child: _isLoadingChartData
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _allEcgData.isEmpty
                    ? Center(
                        child: Text(
                          'No ECG data available',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      )
                    : Padding(
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
                                spots: _allEcgData[_visibleCount - 1].signal.asMap().entries.map((entry) {
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

  Widget _buildBPChart() {
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
            child: _isLoadingChartData
                ? const Center(child: CircularProgressIndicator())
                : _allVitalsData.isEmpty
                    ? Center(
                        child: Text(
                          'No BP data available',
                          style: GoogleFonts.poppins(color: Colors.grey[600]),
                        ),
                      )
                    : LineChart(
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
                              spots: _allVitalsData.take(_visibleCount).toList().asMap().entries.map((entry) {
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
                              spots: _allVitalsData.take(_visibleCount).toList().asMap().entries.map((entry) {
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

  Widget _buildQuickActionsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Real-Time Vitals',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildVitalCard(
                  'Heart Rate',
                  '${_currentHeartRate.toInt()} bpm',
                  Icons.favorite,
                  _getHeartRateColor(),
                  _heartRateStatus,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVitalCard(
                  'SpO2',
                  '${_currentSpO2.toInt()}%',
                  Icons.air,
                  _getSpO2Color(),
                  _spo2Status,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildVitalCard(
                  'Temperature',
                  '${_currentTemp.toStringAsFixed(1)}°C',
                  Icons.thermostat,
                  _getTempColor(),
                  _getTempStatus(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVitalCard(
                  'Blood Pressure',
                  '$_currentBPSystolic/$_currentBPDiastolic',
                  Icons.monitor_heart,
                  _getBPColor(),
                  _getBPStatus(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getHeartRateColor() {
    if (_currentHeartRate > 100) return Colors.red;
    if (_currentHeartRate < 60) return Colors.orange;
    return Colors.green;
  }

  Color _getSpO2Color() {
    if (_currentSpO2 < 95) return Colors.red;
    return Colors.green;
  }

  Color _getTempColor() {
    if (_currentTemp > 37.5 || _currentTemp < 36.0) return Colors.red;
    if (_currentTemp > 37.2 || _currentTemp < 36.1) return Colors.orange;
    return Colors.green;
  }

  String _getTempStatus() {
    if (_currentTemp > 37.5) return 'High';
    if (_currentTemp < 36.0) return 'Low';
    if (_currentTemp > 37.2 || _currentTemp < 36.1) return 'Borderline';
    return 'Normal';
  }

  Color _getBPColor() {
    int systolic = int.tryParse(_currentBPSystolic) ?? 120;
    int diastolic = int.tryParse(_currentBPDiastolic) ?? 80;
    if (systolic > 140 || diastolic > 90) return Colors.red;
    if (systolic > 130 || diastolic > 85) return Colors.orange;
    return Colors.green;
  }

  String _getBPStatus() {
    int systolic = int.tryParse(_currentBPSystolic) ?? 120;
    int diastolic = int.tryParse(_currentBPDiastolic) ?? 80;
    if (systolic > 140 || diastolic > 90) return 'High';
    if (systolic > 130 || diastolic > 85) return 'Elevated';
    return 'Normal';
  }

  Widget _buildVitalCard(String title, String value, IconData icon, Color color, String status) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            status,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
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
            'Patient Summary',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Blood Type', 'O+', Icons.bloodtype),
          _buildInfoRow('Emergency Contact', '+1 (555) 123-4567', Icons.emergency),
          _buildInfoRow('Insurance', 'Blue Cross Blue Shield', Icons.health_and_safety),
          _buildInfoRow('Last Visit', '2 days ago', Icons.schedule),
          _buildInfoRow('Next Appointment', 'March 15, 2024', Icons.event),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}