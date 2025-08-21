import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/device_manager.dart';
import 'dart:async';
import 'help_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DeviceManager _deviceManager = DeviceManager();
  StreamSubscription<Map<String, bool>>? _deviceStateSubscription;
  StreamSubscription<Map<String, int>>? _syncIntervalSubscription;
  String selectedTab = 'Profile';

  // Toggle states
  bool pushNotifications = true;
  bool emailNotifications = false;
  bool lowBatteryAlerts = true;
  bool twoFactorAuth = false;

  // Device monitoring states - will be synced with DeviceManager
  bool ecgMonitorEnabled = true;
  bool heartRateMonitorEnabled = true;
  bool spo2MonitorEnabled = true;
  bool bloodPressureMonitorEnabled = true;
  bool temperatureMonitorEnabled = true;
  bool pulseOximetterEnabled = false;
  bool glucoseMonitorEnabled = false;
  
  // Data sync intervals (in seconds) - will be synced with DeviceManager
  int ecgSyncInterval = 5;
  int vitalsSyncInterval = 5;
  int temperatureSyncInterval = 7;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeDeviceManager();
  }

  Future<void> _initializeDeviceManager() async {
    await _deviceManager.initialize();
    
    // Sync local state with DeviceManager
    setState(() {
      ecgMonitorEnabled = _deviceManager.ecgMonitorEnabled;
      heartRateMonitorEnabled = _deviceManager.heartRateMonitorEnabled;
      spo2MonitorEnabled = _deviceManager.spo2MonitorEnabled;
      bloodPressureMonitorEnabled = _deviceManager.bloodPressureMonitorEnabled;
      temperatureMonitorEnabled = _deviceManager.temperatureMonitorEnabled;
      pulseOximetterEnabled = _deviceManager.pulseOximeterEnabled;
      glucoseMonitorEnabled = _deviceManager.glucoseMonitorEnabled;
      
      ecgSyncInterval = _deviceManager.ecgSyncInterval;
      vitalsSyncInterval = _deviceManager.vitalsSyncInterval;
      temperatureSyncInterval = _deviceManager.temperatureSyncInterval;
    });

    // Listen to device state changes
    _deviceStateSubscription = _deviceManager.deviceStateStream.listen((deviceStates) {
      if (mounted) {
        setState(() {
          ecgMonitorEnabled = deviceStates['ecg'] ?? true;
          heartRateMonitorEnabled = deviceStates['heartRate'] ?? true;
          spo2MonitorEnabled = deviceStates['spo2'] ?? true;
          bloodPressureMonitorEnabled = deviceStates['bloodPressure'] ?? true;
          temperatureMonitorEnabled = deviceStates['temperature'] ?? true;
          pulseOximetterEnabled = deviceStates['pulseOximeter'] ?? false;
          glucoseMonitorEnabled = deviceStates['glucose'] ?? false;
        });
      }
    });

    // Listen to sync interval changes
    _syncIntervalSubscription = _deviceManager.syncIntervalStream.listen((intervals) {
      if (mounted) {
        setState(() {
          ecgSyncInterval = intervals['ecg'] ?? 5;
          vitalsSyncInterval = intervals['vitals'] ?? 5;
          temperatureSyncInterval = intervals['temperature'] ?? 7;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deviceStateSubscription?.cancel();
    _syncIntervalSubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateDeviceState(String deviceType, bool enabled) async {
    await _deviceManager.updateDeviceState(deviceType, enabled);
  }

  Future<void> _updateSyncInterval(String intervalType, int interval) async {
    await _deviceManager.updateSyncInterval(intervalType, interval);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Text(
                'Profile',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            Tab(
              child: Text(
                'Devices',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            Tab(
              child: Text(
                'Privacy',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildDevicesTab(),
          _buildPrivacyTab(),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileInfo(),
          const Divider(height: 1),
          _buildNotificationPreferences(),
          const Divider(height: 1),
          _buildSecurity(),
          _buildHelpSupport(),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[200],
                child: Text(
                  'JD',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jane Doe!',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'jane.doe@example.com',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              // Handle edit profile
            },
            child: Text(
              'Edit Profile',
              style: GoogleFonts.poppins(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPreferences() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Preferences',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildToggleOption(
            'Push Notifications',
            'Receive alerts on your devices',
            pushNotifications,
            (value) => setState(() => pushNotifications = value),
          ),
          const SizedBox(height: 16),
          _buildToggleOption(
            'Email Notifications',
            'Receive alerts via email',
            emailNotifications,
            (value) => setState(() => emailNotifications = value),
          ),
          const SizedBox(height: 16),
          _buildToggleOption(
            'Low Battery Alerts',
            'Get notified when battery is low',
            lowBatteryAlerts,
            (value) => setState(() => lowBatteryAlerts = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurity() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              // Handle password change
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: Colors.blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Change Password',
              style: GoogleFonts.poppins(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildToggleOption(
            'Two-Factor Authentication',
            'Enhanced account security',
            twoFactorAuth,
            (value) => setState(() => twoFactorAuth = value),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSupport() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const HelpSupportScreen(),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.help_outline,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(
              'Help & Support',
              style: GoogleFonts.poppins(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildDevicesTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Health Monitoring Devices', 'Manage your connected health devices'),
          _buildDevicesList(),
          const SizedBox(height: 16),
          _buildSectionHeader('Data Sync Settings', 'Control how often data is updated'),
          _buildSyncSettings(),
          const SizedBox(height: 16),
          _buildSectionHeader('Device Status', 'Check connection and battery status'),
          _buildDeviceStatus(),
        ],
      ),
    );
  }

  Widget _buildPrivacyTab() {
    return const SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Privacy settings will be implemented here'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDeviceItem(
            'ECG Monitor',
            'Real-time heart rhythm monitoring',
            Icons.monitor_heart,
            Colors.red,
            ecgMonitorEnabled,
            (value) => _updateDeviceState('ecg', value),
          ),
          const Divider(height: 1),
          _buildDeviceItem(
            'Heart Rate Monitor',
            'Continuous heart rate tracking',
            Icons.favorite,
            Colors.pink,
            heartRateMonitorEnabled,
            (value) => _updateDeviceState('heartRate', value),
          ),
          const Divider(height: 1),
          _buildDeviceItem(
            'SpO₂ Monitor',
            'Blood oxygen saturation levels',
            Icons.air,
            Colors.blue,
            spo2MonitorEnabled,
            (value) => _updateDeviceState('spo2', value),
          ),
          const Divider(height: 1),
          _buildDeviceItem(
            'Blood Pressure Cuff',
            'Systolic and diastolic pressure',
            Icons.bloodtype,
            Colors.purple,
            bloodPressureMonitorEnabled,
            (value) => _updateDeviceState('bloodPressure', value),
          ),
          const Divider(height: 1),
          _buildDeviceItem(
            'Temperature Sensor',
            'Body temperature monitoring',
            Icons.thermostat,
            Colors.orange,
            temperatureMonitorEnabled,
            (value) => _updateDeviceState('temperature', value),
          ),
          const Divider(height: 1),
          _buildDeviceItem(
            'Pulse Oximeter',
            'Advanced oxygen monitoring',
            Icons.sensors,
            Colors.teal,
            pulseOximetterEnabled,
            (value) => _updateDeviceState('pulseOximeter', value),
          ),
          const Divider(height: 1),
          _buildDeviceItem(
            'Glucose Monitor',
            'Blood glucose level tracking',
            Icons.water_drop,
            Colors.green,
            glucoseMonitorEnabled,
            (value) => _updateDeviceState('glucose', value),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(String name, String description, IconData icon, Color color, bool isEnabled, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: isEnabled,
                onChanged: onChanged,
                activeColor: color,
              ),
              Text(
                isEnabled ? 'Active' : 'Inactive',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isEnabled ? color : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncSettings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSyncItem('ECG Data Sync', 'Every $ecgSyncInterval seconds', ecgSyncInterval, (value) {
            _updateSyncInterval('ecg', value);
          }),
          const Divider(height: 1),
          _buildSyncItem('Vitals Data Sync', 'Every $vitalsSyncInterval seconds', vitalsSyncInterval, (value) {
            _updateSyncInterval('vitals', value);
          }),
          const Divider(height: 1),
          _buildSyncItem('Temperature Sync', 'Every $temperatureSyncInterval seconds', temperatureSyncInterval, (value) {
            _updateSyncInterval('temperature', value);
          }),
        ],
      ),
    );
  }

  Widget _buildSyncItem(String title, String description, int currentValue, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Text(
                '${currentValue}s',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Fast', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              Expanded(
                child: Slider(
                  value: currentValue.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  activeColor: Colors.blue,
                  onChanged: (value) => onChanged(value.toInt()),
                ),
              ),
              Text('Slow', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStatusItem('ECG Monitor', 'Connected', 87, Colors.green),
          const Divider(height: 1),
          _buildStatusItem('Heart Rate Monitor', 'Connected', 92, Colors.green),
          const Divider(height: 1),
          _buildStatusItem('SpO₂ Monitor', 'Connected', 78, Colors.orange),
          const Divider(height: 1),
          _buildStatusItem('Blood Pressure Cuff', 'Disconnected', 0, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String deviceName, String status, int batteryLevel, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (batteryLevel > 0) ...[
            Icon(
              Icons.battery_std,
              color: batteryLevel > 20 ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              '$batteryLevel%',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: batteryLevel > 20 ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            Icon(
              Icons.battery_alert,
              color: Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              'N/A',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }
} 