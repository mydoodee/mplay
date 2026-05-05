import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../l10n/app_localizations.dart';

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
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchUsers(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/admin/users');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': widget.username,
              'password': widget.password,
            }),
          )
          .timeout(const Duration(seconds: 10));

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
          _error = AppLocalizations.of(context)!.adminErrorLoading(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  String _formatUsageTime(BuildContext context, int hours, int minutes) {
    final l10n = AppLocalizations.of(context)!;
    if (hours > 0) return l10n.adminHoursMinutes(hours, minutes);
    return l10n.adminMinutes(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.adminDashboardTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                l10n.adminOnlineCount(_totalOnline),
                style: const TextStyle(
                  color: Color(0xFFF15A24),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading && _users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFF15A24)),
            const SizedBox(height: 16),
            Text(
              l10n.adminLoadingUsers,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error != null && _users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFF15A24),
      onRefresh: _fetchUsers,
      child: _users.isEmpty
          ? const Center(
              child: Text(
                'No users online',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                return _buildUserCard(_users[index]);
              },
            ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final isOnline = user['isOnline'] == true;
    final platform = user['platform']?.toString().toLowerCase() ?? 'unknown';

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
              color: isOnline
                  ? const Color(0xFF4CAF50).withOpacity(0.5)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Icon(
              platform == 'android'
                  ? Icons.android_rounded
                  : platform == 'ios'
                      ? Icons.phone_iphone_rounded
                      : Icons.devices_rounded,
              color: isOnline ? const Color(0xFF4CAF50) : const Color(0xFF777777),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user['deviceName'] ?? 'Unknown Device',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                    : const Color(0xFF777777).withOpacity(0.1),
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
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 14,
                color: Color(0xFFBBBBBB),
              ),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.adminUsedTimePrefix(
                  _formatUsageTime(
                    context,
                    user['hoursUsed'] ?? 0,
                    user['minutesUsed'] ?? 0,
                  ),
                ),
                style: const TextStyle(
                  color: Color(0xFFBBBBBB),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
