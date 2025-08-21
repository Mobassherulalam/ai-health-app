import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/vitals_record.dart';
import '../models/ecg_record.dart';
import '../services/api_service.dart';
import '../services/device_manager.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Critical', 'Warning', 'Info', 'ECG', 'Heart Rate', 'SpO2', 'AI Prediction'];
  final ApiService _apiService = ApiService('http://127.0.0.1:8000');
  List<Map<String, dynamic>> alerts = [];
  bool isLoading = true;
  Timer? _refreshTimer;
  late StreamSubscription _deviceSubscription;
  
  // Device states
  bool _ecgEnabled = true;
  bool _vitalsEnabled = true;
  
  // Alert priority levels
  final Map<String, int> _alertPriority = {
    'Critical': 3,
    'Warning': 2,
    'Info': 1,
  };

  @override
  void initState() {
    super.initState();
    _initializeDeviceStates();
    _fetchAlertsFromVitals();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _deviceSubscription.cancel();
    super.dispose();
  }

  void _initializeDeviceStates() {
    final deviceManager = DeviceManager();
    _ecgEnabled = deviceManager.ecgMonitorEnabled;
    _vitalsEnabled = deviceManager.heartRateMonitorEnabled || 
                     deviceManager.spo2MonitorEnabled || 
                     deviceManager.bloodPressureMonitorEnabled;
    
    _deviceSubscription = deviceManager.deviceStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _ecgEnabled = state['ecg'] ?? deviceManager.ecgMonitorEnabled;
          _vitalsEnabled = (state['heartRate'] ?? deviceManager.heartRateMonitorEnabled) ||
                          (state['spo2'] ?? deviceManager.spo2MonitorEnabled) ||
                          (state['bloodPressure'] ?? deviceManager.bloodPressureMonitorEnabled);
        });
        // Refresh alerts when device states change
        _fetchAlertsFromVitals();
      }
    });
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && (_ecgEnabled || _vitalsEnabled)) {
        _fetchAlertsFromVitals();
      }
    });
  }

  Future<void> _fetchAlertsFromVitals() async {
    setState(() { isLoading = true; });
    try {
      final List<Map<String, dynamic>> generatedAlerts = [];
      
      // Only fetch data for enabled devices
      List<VitalsRecord> vitalsData = [];
      List<ECGRecord> ecgData = [];
      
      if (_vitalsEnabled) {
        vitalsData = await _apiService.fetchVitals(50); // Optimized data load
      }
      
      if (_ecgEnabled) {
        ecgData = await _apiService.fetchEcg(50); // Optimized data load
      }

      // Process ECG Anomalies (only if ECG is enabled)
      if (_ecgEnabled && ecgData.isNotEmpty) {
        for (final ecg in ecgData) {
          final ts = DateFormat('MMM d, yyyy h:mm a').format(ecg.timestamp);
          if (ecg.prediction.label != 'Normal') {
            final (alertType, recommendations) = _getEcgAlertInfo(ecg.prediction.label);
            generatedAlerts.add({
              'type': 'Critical',
              'icon': Icons.monitor_heart,
              'color': Colors.red.shade100,
              'iconColor': Colors.red,
              'title': 'ECG Anomaly Detected: ${ecg.prediction.label}',
              'message': 'ECG shows signs of $alertType.\n\nRecommendations:\n$recommendations',
              'timestamp': ts,
              'read': false,
              'deviceType': 'ECG',
            });
          }
        }
      }

      // Process Vital Signs (only if vitals monitoring is enabled)
      if (_vitalsEnabled && vitalsData.isNotEmpty) {
        for (final v in vitalsData) {
          final ts = DateFormat('MMM d, yyyy h:mm a').format(v.timestamp);
          
          // Heart Rate Risk Assessment with improved severity calculation
          if (v.vitals.heartRate > 120 || v.vitals.heartRate < 50) {
            final (severity, alertType, recommendations) = _getHeartRateAlertInfo(v.vitals.heartRate);
            generatedAlerts.add({
              'type': alertType,
              'icon': Icons.favorite,
              'color': alertType == 'Critical' ? Colors.red.shade100 : Colors.orange.shade100,
              'iconColor': alertType == 'Critical' ? Colors.red : Colors.orange,
              'title': severity,
              'message': 'Heart rate of ${v.vitals.heartRate.round()} bpm detected.\n\nRecommendations:\n$recommendations',
              'timestamp': ts,
              'read': false,
              'deviceType': 'Heart Rate',
              'severity': _calculateSeverityScore(v.vitals.heartRate, 'heartRate'),
            });
          }

          // SpO2 Risk Assessment with severity scoring
          if (v.vitals.spo2 < 95) {
            final (severity, recommendations) = _getSpO2AlertInfo(v.vitals.spo2);
            generatedAlerts.add({
              'type': v.vitals.spo2 < 90 ? 'Critical' : 'Warning',
              'icon': Icons.air,
              'color': v.vitals.spo2 < 90 ? Colors.red.shade100 : Colors.orange.shade100,
              'iconColor': v.vitals.spo2 < 90 ? Colors.red : Colors.orange,
              'title': '$severity Oxygen Saturation',
              'message': 'SpO₂ of ${v.vitals.spo2.round()}% detected.\n\nRecommendations:\n$recommendations',
              'timestamp': ts,
              'read': false,
              'deviceType': 'SpO2',
              'severity': _calculateSeverityScore(v.vitals.spo2, 'spo2'),
            });
          }

          // Risk Prediction with Contextual Alerts
          if (v.prediction.risk != 'Normal') {
            final probability = v.prediction.probability * 100;
            final (alertType, recommendations) = _getRiskAlertInfo(v.prediction.risk, probability);
            generatedAlerts.add({
              'type': probability > 75 ? 'Critical' : 'Warning',
              'icon': probability > 75 ? Icons.warning_rounded : Icons.info_outline,
              'color': probability > 75 ? Colors.red.shade100 : Colors.orange.shade100,
              'iconColor': probability > 75 ? Colors.red : Colors.orange,
              'title': '$alertType Risk Level',
              'message': 'AI Risk Assessment: ${probability.toStringAsFixed(1)}%\n\nRecommendations:\n$recommendations',
              'timestamp': ts,
              'read': false,
              'deviceType': 'AI Prediction',
            });
          }
        }
      }
      
      // Add device status alerts
      _addDeviceStatusAlerts(generatedAlerts);
      
      // Remove duplicate alerts and sort by priority
      final uniqueAlerts = _removeDuplicateAlerts(generatedAlerts);
      final sortedAlerts = _sortAlertsByPriority(uniqueAlerts);
      
      setState(() {
        alerts = sortedAlerts.reversed.toList(); // Most recent first
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; });
      // Add error alert
      _addErrorAlert('Failed to fetch health data: ${e.toString()}');
    }
  }

  void _addDeviceStatusAlerts(List<Map<String, dynamic>> alertsList) {
    final deviceManager = DeviceManager();
    final now = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
    
    // Check for disabled devices individually
    if (!deviceManager.ecgMonitorEnabled) {
      alertsList.add({
        'type': 'Info',
        'icon': Icons.info_outline,
        'color': Colors.blue.shade100,
        'iconColor': Colors.blue,
        'title': 'ECG Monitoring Disabled',
        'message': 'ECG monitoring is currently turned off. Enable it in Profile settings to receive heart rhythm alerts.',
        'timestamp': now,
        'read': false,
        'deviceType': 'System',
      });
    }
    
    if (!deviceManager.heartRateMonitorEnabled) {
      alertsList.add({
        'type': 'Info',
        'icon': Icons.info_outline,
        'color': Colors.blue.shade100,
        'iconColor': Colors.blue,
        'title': 'Heart Rate Monitoring Disabled',
        'message': 'Heart rate monitoring is disabled. Enable it in Profile settings for heart rate alerts.',
        'timestamp': now,
        'read': false,
        'deviceType': 'System',
      });
    }
    
    if (!deviceManager.spo2MonitorEnabled) {
      alertsList.add({
        'type': 'Info',
        'icon': Icons.info_outline,
        'color': Colors.blue.shade100,
        'iconColor': Colors.blue,
        'title': 'SpO₂ Monitoring Disabled',
        'message': 'SpO₂ monitoring is disabled. Enable it in Profile settings for oxygen saturation alerts.',
        'timestamp': now,
        'read': false,
        'deviceType': 'System',
      });
    }
  }

  void _addErrorAlert(String errorMessage) {
    final now = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
    setState(() {
      alerts.insert(0, {
        'type': 'Warning',
        'icon': Icons.error_outline,
        'color': Colors.orange.shade100,
        'iconColor': Colors.orange,
        'title': 'Data Fetch Error',
        'message': errorMessage,
        'timestamp': now,
        'read': false,
        'deviceType': 'System',
      });
    });
  }

  List<Map<String, dynamic>> _removeDuplicateAlerts(List<Map<String, dynamic>> alertsList) {
    final seen = <String>{};
    return alertsList.where((alert) {
      final key = '${alert['title']}_${alert['deviceType']}_${alert['type']}';
      return seen.add(key);
    }).toList();
  }

  List<Map<String, dynamic>> _sortAlertsByPriority(List<Map<String, dynamic>> alertsList) {
    alertsList.sort((a, b) {
      final priorityA = _alertPriority[a['type']] ?? 0;
      final priorityB = _alertPriority[b['type']] ?? 0;
      
      // First sort by priority (higher priority first)
      if (priorityA != priorityB) {
        return priorityB.compareTo(priorityA);
      }
      
      // Then sort by timestamp (newer first)
      final timestampA = a['timestamp'] as String? ?? '';
      final timestampB = b['timestamp'] as String? ?? '';
      return timestampB.compareTo(timestampA);
    });
    return alertsList;
  }

  List<Map<String, dynamic>> get filteredAlerts {
    if (selectedFilter == 'All') return alerts;
    
    // Filter by alert type (Critical, Warning, Info)
    if (['Critical', 'Warning', 'Info'].contains(selectedFilter)) {
      return alerts.where((alert) => alert['type'] == selectedFilter).toList();
    }
    
    // Filter by device type
    return alerts.where((alert) => alert['deviceType'] == selectedFilter).toList();
  }

  void _clearAllAlerts() {
    setState(() {
      alerts.clear();
    });
  }

  void _markAlertAsRead(int index) {
    setState(() {
      filteredAlerts[index]['read'] = true;
    });
  }

  void _showAlertDetails(Map<String, dynamic> alert) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(alert['icon'], color: alert['iconColor']),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert['title'],
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (alert['deviceType'] != null) ...[
                Text(
                  'Device: ${alert['deviceType']}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (alert['timestamp'] != null) ...[
                Text(
                  'Time: ${alert['timestamp']}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                alert['message'],
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _markAlertAsRead(filteredAlerts.indexOf(alert));
              },
              child: Text('Acknowledge', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  (String, String) _getEcgAlertInfo(String anomalyType) {
    switch (anomalyType.toLowerCase()) {
      case 'atrial_fibrillation':
        return (
          'Atrial Fibrillation',
          '• Stay calm and seated\n• Take prescribed medications\n• Monitor pulse\n• Contact your healthcare provider\n• Avoid strenuous activity'
        );
      case 'heart_block':
        return (
          'Heart Block',
          '• Rest in a comfortable position\n• Have someone stay with you\n• Seek immediate medical attention\n• Keep track of any symptoms'
        );
      case 'premature_beats':
        return (
          'Premature Beats',
          '• Practice deep breathing\n• Avoid caffeine and stimulants\n• Monitor frequency of episodes\n• Report persistent symptoms to doctor'
        );
      case 'st_elevation':
        return (
          'ST Elevation',
          '• Call emergency services immediately\n• Chew aspirin if prescribed\n• Remain still and calm\n• Keep nitroglycerine nearby if prescribed'
        );
      default:
        return (
          'Abnormal ECG Pattern',
          '• Monitor your symptoms\n• Record any unusual feelings\n• Contact your healthcare provider\n• Avoid strenuous activity'
        );
    }
  }

  (String, String, String) _getHeartRateAlertInfo(double heartRate) {
    if (heartRate > 150) {
      return (
        'Severe Tachycardia',
        'Critical',
        '• Seek immediate medical attention\n• Rest in a quiet place\n• Practice deep breathing\n• Contact healthcare provider immediately\n• Avoid caffeine and stimulants'
      );
    } else if (heartRate > 120) {
      return (
        'Moderate Tachycardia',
        'Warning',
        '• Rest in a quiet place\n• Practice deep breathing\n• Contact healthcare provider if symptoms persist\n• Avoid caffeine and stimulants\n• Monitor for 15 minutes'
      );
    } else if (heartRate < 40) {
      return (
        'Severe Bradycardia',
        'Critical',
        '• Seek immediate medical attention\n• Sit or lie down\n• Have someone stay with you\n• Check medications with your doctor\n• Monitor for dizziness or chest pain'
      );
    } else if (heartRate < 50) {
      return (
        'Moderate Bradycardia',
        'Warning',
        '• Sit or lie down\n• Check medications with your doctor\n• Monitor for dizziness or fatigue\n• Contact provider if symptoms worsen\n• Avoid sudden position changes'
      );
    } else {
      return ('Normal', 'Info', 'Heart rate is within normal range');
    }
  }

  double _calculateSeverityScore(double value, String type) {
    switch (type) {
      case 'heartRate':
        if (value > 150 || value < 40) return 10.0; // Critical
        if (value > 120 || value < 50) return 7.0;  // Warning
        if (value > 100 || value < 60) return 3.0;  // Mild concern
        return 0.0; // Normal
      case 'spo2':
        if (value < 85) return 10.0; // Critical
        if (value < 90) return 8.0;  // High warning
        if (value < 95) return 5.0;  // Warning
        return 0.0; // Normal
      default:
        return 0.0;
    }
  }

  (String, String) _getSpO2AlertInfo(double spo2) {
    if (spo2 < 85) {
      return (
        'Severe Low',
        '• Seek emergency medical attention immediately\n• Sit upright and focus on slow deep breaths\n• Use supplemental oxygen if prescribed\n• Move to well-ventilated area'
      );
    } else if (spo2 < 90) {
      return (
        'Critical Low',
        '• Contact healthcare provider immediately\n• Practice pursed-lip breathing\n• Use prescribed oxygen therapy\n• Avoid physical exertion'
      );
    } else if (spo2 < 95) {
      return (
        'Moderate Low',
        '• Monitor levels closely\n• Practice deep breathing exercises\n• Consider using prescribed oxygen\n• Report persistent low levels to doctor'
      );
    } else {
      return (
        'Borderline',
        '• Continue monitoring\n• Record any symptoms\n• Maintain good ventilation\n• Follow up with healthcare provider'
      );
    }
  }

  (String, String) _getRiskAlertInfo(String riskLevel, double probability) {
    if (riskLevel == 'High' && probability > 90) {
      return (
        'Critical',
        '• Immediate medical attention required\n• Have emergency contacts ready\n• Stay with someone if possible\n• Prepare medical history for healthcare providers'
      );
    } else if (riskLevel == 'High') {
      return (
        'High',
        '• Contact healthcare provider urgently\n• Monitor vital signs closely\n• Avoid strenuous activity\n• Have someone check on you regularly'
      );
    } else if (riskLevel == 'Medium' && probability > 60) {
      return (
        'Elevated',
        '• Schedule urgent medical review\n• Monitor symptoms closely\n• Record any changes in condition\n• Take prescribed medications as directed'
      );
    } else {
      return (
        'Moderate',
        '• Follow up with healthcare provider\n• Continue monitoring vital signs\n• Maintain prescribed treatment plan\n• Report any worsening symptoms'
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedFilter == 'All' ? 'Health Alerts' : selectedFilter,
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${filteredAlerts.length} alert${filteredAlerts.length != 1 ? 's' : ''}',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          // Device status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Icon(
                  Icons.monitor_heart,
                  color: _ecgEnabled ? Colors.green : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.favorite,
                  color: _vitalsEnabled ? Colors.green : Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _fetchAlertsFromVitals,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          _buildAlertSummary(),
          _buildQuickActions(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredAlerts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredAlerts.length + 1, // +1 for clear all
                        itemBuilder: (context, index) {
                          if (index == filteredAlerts.length) {
                            return _buildClearAllButton();
                          }
                          return GestureDetector(
                            onTap: () => _markAlertAsRead(index),
                            child: _buildAlertCard(filteredAlerts[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            bool isSelected = selectedFilter == filter;
            int filterCount = filter == 'All' 
                ? alerts.length 
                : ((['Critical', 'Warning', 'Info'].contains(filter))
                    ? alerts.where((alert) => alert['type'] == filter).length
                    : alerts.where((alert) => alert['deviceType'] == filter).length);
            
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('$filter ($filterCount)'),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() => selectedFilter = filter);
                },
                backgroundColor: Colors.grey[200],
                selectedColor: Colors.blue[100],
                labelStyle: GoogleFonts.poppins(
                  color: isSelected ? Colors.blue : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAlertSummary() {
    if (alerts.isEmpty) return const SizedBox.shrink();
    
    final criticalCount = alerts.where((alert) => alert['type'] == 'Critical').length;
    final warningCount = alerts.where((alert) => alert['type'] == 'Warning').length;
    final unreadCount = alerts.where((alert) => alert['read'] != true).length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem('Critical', criticalCount, Colors.red),
          ),
          Expanded(
            child: _buildSummaryItem('Warning', warningCount, Colors.orange),
          ),
          Expanded(
            child: _buildSummaryItem('Unread', unreadCount, Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final criticalAlerts = alerts.where((alert) => 
        alert['type'] == 'Critical' && alert['read'] != true).toList();
    
    if (criticalAlerts.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${criticalAlerts.length} critical alert${criticalAlerts.length != 1 ? 's' : ''} need attention',
              style: GoogleFonts.poppins(
                color: Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                for (var alert in criticalAlerts) {
                  alert['read'] = true;
                }
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Acknowledge All',
              style: GoogleFonts.poppins(
                color: Colors.red.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            selectedFilter == 'All' ? 'No alerts found' : 'No $selectedFilter alerts',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your health monitoring is working normally',
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          if (!_ecgEnabled || !_vitalsEnabled) ...[
            const SizedBox(height: 16),
            Text(
              'Some devices are disabled in Profile settings',
              style: GoogleFonts.poppins(
                color: Colors.orange[600],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: alert['color'],
        borderRadius: BorderRadius.circular(12),
        border: alert['read'] == true ? Border.all(color: Colors.green, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  alert['icon'],
                  color: alert['iconColor'],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              alert['title'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (alert['timestamp'] != null && alert['timestamp'] != '')
                            Text(
                              alert['timestamp'],
                              style: GoogleFonts.poppins(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Device type badge
                      if (alert['deviceType'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            alert['deviceType'],
                            style: GoogleFonts.poppins(
                              color: Colors.black54,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        alert['message'],
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      if (alert['read'] == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Acknowledged',
                            style: GoogleFonts.poppins(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Action buttons for critical alerts
            if (alert['type'] == 'Critical' && alert['read'] != true) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _markAlertAsRead(filteredAlerts.indexOf(alert)),
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(
                        'Acknowledge',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                        backgroundColor: Colors.green.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showAlertDetails(alert),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: Text(
                        'Details',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClearAllButton() {
    return Center(
      child: TextButton(
        onPressed: _clearAllAlerts,
        style: TextButton.styleFrom(
          backgroundColor: Colors.blue[50],
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          'Clear all',
          style: GoogleFonts.poppins(
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}