import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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
    final currentLat = (_schoolData?['latitude'] as num?)?.toDouble() ?? 42.8746;
    final currentLng = (_schoolData?['longitude'] as num?)?.toDouble() ?? 74.5698;
    final currentRadius = (_schoolData?['allowed_radius_meters'] as num?)?.toDouble() ?? 150.0;
    final currentMaxAccuracy = (_schoolData?['max_accuracy_meters'] as num?)?.toDouble() ?? 50.0;

    final nameController = TextEditingController(text: currentName);
    final latController = TextEditingController(text: currentLat.toStringAsFixed(6));
    final lngController = TextEditingController(text: currentLng.toStringAsFixed(6));

    double selectedRadius = currentRadius;
    double selectedAccuracy = currentMaxAccuracy;
    bool isDetectingGps = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit_location_alt_rounded, color: AppTheme.primaryColor, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Мектептин Жайгашуусу жана Геозона',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // School Name Input
                const Text(
                  'Мектептин аталышы:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'Мис: №70 Мектеп-лицейи',
                    prefixIcon: Icon(Icons.school_rounded, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 16),

                // GPS Permanent Location Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Туруктуу жайы (GPS Координаталар):',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    InkWell(
                      onTap: isDetectingGps
                          ? null
                          : () async {
                              setModalState(() => isDetectingGps = true);
                              try {
                                LocationPermission perm = await Geolocator.checkPermission();
                                if (perm == LocationPermission.denied) {
                                  perm = await Geolocator.requestPermission();
                                }
                                if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
                                  final pos = await Geolocator.getCurrentPosition(
                                    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                                  );
                                  latController.text = pos.latitude.toStringAsFixed(6);
                                  lngController.text = pos.longitude.toStringAsFixed(6);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Учурдагы GPS координаталар ийгиликтүү аныкталды!'),
                                      backgroundColor: AppTheme.successColor,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('GPS аныктоодо ката: $e'),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                              } finally {
                                setModalState(() => isDetectingGps = false);
                              }
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDetectingGps)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                              )
                            else
                              const Icon(Icons.my_location_rounded, size: 14, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            const Text(
                              'Азыркы GPSти алуу',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Lat & Lng Input Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Кеңдик (Lat)',
                          hintText: '42.8746',
                          prefixIcon: Icon(Icons.north_east_rounded, size: 18, color: AppTheme.secondaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Узундук (Lng)',
                          hintText: '74.5698',
                          prefixIcon: Icon(Icons.south_west_rounded, size: 18, color: AppTheme.secondaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Geofence Radius Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Текшерүү радиусу (Геозона):',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${selectedRadius.toInt()} метр',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: selectedRadius.clamp(20.0, 1000.0),
                  min: 20.0,
                  max: 1000.0,
                  divisions: 98,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (val) => setModalState(() => selectedRadius = val),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [50, 80, 100, 150, 200, 300, 500].map((r) {
                    final isSel = (selectedRadius - r).abs() < 1;
                    return InkWell(
                      onTap: () => setModalState(() => selectedRadius = r.toDouble()),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? AppTheme.primaryColor : AppTheme.borderColor),
                        ),
                        child: Text(
                          '$r м',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                // Explanation Info Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.successColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Мугалим мектептин борборунан ${selectedRadius.toInt()}м ичинде болгондо гана QR-кодду сканерлей алат.',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Max GPS Accuracy Limit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Максималдуу GPS тактыгы (Accuracy):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    Text(
                      '${selectedAccuracy.toInt()}м',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.secondaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [20, 30, 50, 80, 100].map((acc) {
                    final isSel = (selectedAccuracy - acc).abs() < 1;
                    return InkWell(
                      onTap: () => setModalState(() => selectedAccuracy = acc.toDouble()),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.secondaryColor : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? AppTheme.secondaryColor : AppTheme.borderColor),
                        ),
                        child: Text(
                          '$acc м',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // Save Button
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = nameController.text.trim();
                          final newLat = double.tryParse(latController.text.trim());
                          final newLng = double.tryParse(lngController.text.trim());

                          if (newName.isEmpty) return;

                          setModalState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final (success, errorMsg) = await _repository.updateSchoolSettings(
                            schoolId: schoolId,
                            name: newName,
                            latitude: newLat,
                            longitude: newLng,
                            radius: selectedRadius,
                            maxAccuracy: selectedAccuracy,
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (success) {
                            _loadData();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Мектептин жайгашуусу жана радиусу ийгиликтүү сакталды!'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(errorMsg ?? 'Жөндөөлөрдү сактоодо ката кетти'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Жөндөөлөрдү сактоо', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
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
    final radius = (_schoolData?['allowed_radius_meters'] as num?)?.toDouble() ?? 150.0;
    final lat = (_schoolData?['latitude'] as num?)?.toDouble() ?? 42.8746;
    final lng = (_schoolData?['longitude'] as num?)?.toDouble() ?? 74.5698;

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
                        'Мектеп жана Геозона',
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
                        child: const Icon(Icons.edit_location_alt_rounded, size: 18, color: AppTheme.primaryColor),
                      ),
                      tooltip: 'Жайгашуу жана радиусту өзгөртүү',
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar_rounded, size: 14, color: AppTheme.successColor),
                          const SizedBox(width: 4),
                          Text('Радиус: ${radius.toInt()}м', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place_rounded, size: 14, color: AppTheme.secondaryColor),
                          const SizedBox(width: 4),
                          Text('${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
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
                _buildSystemTile('GPS Текшерүү', 'Haversine Geofencing (Радиус: ${radius.toInt()}м)'),
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
