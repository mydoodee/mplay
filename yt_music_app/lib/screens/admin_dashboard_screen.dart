import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String username;
  final String password;

  const AdminDashboardScreen({
    super.key,
    required this.username,
    required this.password,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _users = [];
  int _totalOnline = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    // Refresh every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchUsers());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/admin/users');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.username,
          'password': widget.password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _users = data['users'] ?? [];
            _totalOnline = data['totalOnline'] ?? 0;
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        throw Exception('Failed to load data (${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading users: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatUsageTime(int hours, int minutes) {
    if (hours > 0) return '$hours ชั่วโมง $minutes นาที';
    return '$minutes นาที';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ผู้ใช้งานระบบ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'ออนไลน์: $_totalOnline คน',
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchUsers();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _users.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF15A24)),
      );
    }
    if (_error != null && _users.isEmpty) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }
    if (_users.isEmpty) {
      return const Center(
        child: Text(
          'ไม่มีผู้ใช้งานในขณะนี้',
          style: TextStyle(color: Color(0xFF777777), fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFF15A24),
      backgroundColor: const Color(0xFF1E1E1E),
      onRefresh: _fetchUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final isOnline = user['isOnline'] == true;
          
          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOnline ? const Color(0xFF4CAF50).withOpacity(0.5) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    user['platform'] == 'android' ? Icons.android_rounded 
                    : user['platform'] == 'ios' ? Icons.phone_iphone_rounded
                    : Icons.devices_rounded,
                    color: isOnline ? const Color(0xFF4CAF50) : const Color(0xFF777777),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      user['deviceName'] ?? 'Unknown User',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF4CAF50).withOpacity(0.1) : const Color(0xFF777777).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? const Color(0xFF4CAF50) : const Color(0xFF777777),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFBBBBBB)),
                    const SizedBox(width: 4),
                    Text(
                      'ใช้งานแล้ว: ${_formatUsageTime(user['hoursUsed'] ?? 0, user['minutesUsed'] ?? 0)}',
                      style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
