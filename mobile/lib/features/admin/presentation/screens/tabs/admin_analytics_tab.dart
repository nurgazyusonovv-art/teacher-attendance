import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
  Map<String, dynamic>? _schoolData;
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
    final school = await _repository.getSchoolSettings();
    if (mounted) {
      setState(() {
        _qrData = qr;
        _dashboardData = dash;
        _schoolData = school;
        _isLoading = false;
      });
    }
  }

  void _showEditSchoolDialog() {
    final schoolId = _schoolData?['id'] as String? ?? _qrData?['school_id'] as String?;
    if (schoolId == null) return;

    final currentName = _schoolData?['name'] as String? ?? _qrData?['school_name'] as String? ?? '№1 Орто Мектеп';
    final nameController = TextEditingController(text: currentName);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.edit_location_alt_rounded, color: AppTheme.primaryColor, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Мектептин аталышы',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Мектептин расмий аталышын жазыңыз:',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Мис: №70 Мектеп-лицейи',
                    prefixIcon: Icon(Icons.school_rounded, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Жокко чыгаруу'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final newName = nameController.text.trim();
                      if (newName.isEmpty) return;

                      setModalState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final (success, errorMsg) = await _repository.updateSchoolSettings(
                        schoolId: schoolId,
                        name: newName,
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (success) {
                        _loadData();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Мектептин аталышы ийгиликтүү өзгөртүлдү!'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(errorMsg ?? 'Аталышын өзгөртүүдө ката кетти'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size(100, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Сактоо', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
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

    final qrToken = _qrData?['token'] ?? _qrData?['qr_token'] ?? 'school-qr-demo-token-12345';
    final schoolId = _qrData?['school_id'] ?? '';
    final schoolName = _schoolData?['name'] as String? ?? _qrData?['school_name'] as String? ?? '№1 Орто Мектеп';

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        children: [
          // School Settings Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school_rounded, size: 20, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Мектеп Жөндөөлөрү',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 17, color: AppTheme.primaryColor),
                      ),
                      tooltip: 'Аталышын өзгөртүү',
                      onPressed: _showEditSchoolDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  schoolName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Мектептин расмий каттоо профили жана параметрлери',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Analytics Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.insights_rounded, size: 20, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Катышуу Аналитикасы',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildMetric('Катышуу', '$attendanceRate%', AppTheme.primaryColor)),
                    Container(height: 32, width: 1, color: AppTheme.borderColor),
                    Expanded(child: _buildMetric('Өз уб.', '$onTimeRate%', AppTheme.successColor)),
                    Container(height: 32, width: 1, color: AppTheme.borderColor),
                    Expanded(child: _buildMetric('Кечиккен', '$lateCount', Colors.orange)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // School QR Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, size: 20, color: AppTheme.secondaryColor),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Мектептин QR-коду',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Мугалимдер келгенде/кеткенде ушул QR-кодду сканерлешет:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Токен: $qrToken',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primaryColor),
                            tooltip: 'Көчүрүү',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: qrToken));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Токен көчүрүлдү!'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ],
                      ),
                      Text('Мектеп ID: $schoolId', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => context.push('/admin/qr-code'),
                  icon: const Icon(Icons.qr_code_rounded, size: 18),
                  label: const Text('QR-кодду ачуу жана көрсөтүү', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // System Info Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: AppTheme.successColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Коопсуздук жана Эрежелер',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSystemTile('Убакыт алкагы', 'Asia/Bishkek (Сервердик так убакыт)'),
                const Divider(height: 14),
                _buildSystemTile('GPS Текшерүү', 'Haversine Geofencing (Радиус: 150м)'),
                const Divider(height: 14),
                _buildSystemTile('Купуялуулук', 'Координаталар базага сакталбайт'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildSystemTile(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
