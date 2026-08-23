import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/repositories/admin_mobile_repository.dart';

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  final AdminMobileRepository _repository = AdminMobileRepository();
  Map<String, dynamic>? _qrData;
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final qr = await _repository.getSchoolQr();
    final dash = await _repository.getTodayDashboard();
    if (mounted) {
      setState(() {
        _qrData = qr;
        _dashboardData = dash;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = (_dashboardData?['total_teachers'] as int?) ?? 0;
    final checkedIn = (_dashboardData?['checked_in_count'] as int?) ?? 0;
    final onTime = (_dashboardData?['on_time_count'] as int?) ?? 0;
    final lateCount = (_dashboardData?['late_count'] as int?) ?? 0;

    final attendanceRate = total > 0 ? ((checkedIn / total) * 100).toStringAsFixed(1) : '0';
    final onTimeRate = checkedIn > 0 ? ((onTime / checkedIn) * 100).toStringAsFixed(1) : '0';

    final qrToken = _qrData?['token'] ?? 'school-qr-demo-token-12345';
    final schoolId = _qrData?['school_id'] ?? '';

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Analytics Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.insights, color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Text(
                        'Катышуу Аналитикасы',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric('Катышуу пайызы', '$attendanceRate%', AppTheme.primaryColor),
                      _buildMetric('Өз убагында', '$onTimeRate%', AppTheme.successColor),
                      _buildMetric('Кечиккендер', '$lateCount', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // School QR Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_2, color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Text(
                        'Мектептин активдүү QR-коду',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Мугалимдер мектепке келгенде жана кеткенде ушул QR-кодду сканерлешет:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Токен: $qrToken', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('Мектеп ID: $schoolId', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // System Info Card
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Система жөнүндө', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 8),
                  Text('Убакыт алкагы: Asia/Bishkek (Сервердик так убакыт)', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 4),
                  Text('GPS Текшерүү: Haversine Geofencing (Радиус: 150 метр)', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Купуялуулук: Координаталар базага сакталбайт', style: TextStyle(fontSize: 13, color: AppTheme.successColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }
}
