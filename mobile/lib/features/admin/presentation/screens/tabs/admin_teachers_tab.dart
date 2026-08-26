import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/repositories/admin_mobile_repository.dart';

class AdminTeachersTab extends StatefulWidget {
  const AdminTeachersTab({super.key});

  @override
  State<AdminTeachersTab> createState() => _AdminTeachersTabState();
}

class _AdminTeachersTabState extends State<AdminTeachersTab> {
  final AdminMobileRepository _repository = AdminMobileRepository();
  List<TeacherItemModel> _teachers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    final list = await _repository.getTeachers();
    if (mounted) {
      setState(() {
        _teachers = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _teachers.where((t) {
      if (_statusFilter == 'ACTIVE' && !t.isActive) return false;
      if (_statusFilter == 'INACTIVE' && t.isActive) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.fullName.toLowerCase().contains(q) ||
          t.employeeCode.toLowerCase().contains(q) ||
          t.username.toLowerCase().contains(q);
    }).toList();

    final activeCount = _teachers.where((t) => t.isActive).length;
    final inactiveCount = _teachers.where((t) => !t.isActive).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeachers,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                children: [
                  // Modern Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: const [
                        BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Мугалимдин аты же коду боюнча издөө...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setState(() => _searchQuery = ''),
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterBadge('Бардыгы (${_teachers.length})', 'ALL'),
                        const SizedBox(width: 8),
                        _buildFilterBadge('Активдүү ($activeCount)', 'ACTIVE'),
                        const SizedBox(width: 8),
                        _buildFilterBadge('Өчүрүлгөн ($inactiveCount)', 'INACTIVE'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (filtered.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.borderColor)),
                      child: Column(
                        children: [
                          Icon(Icons.person_search_rounded, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 10),
                          const Text('Мугалим табылган жок', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  else
                    ...filtered.map((t) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.borderColor),
                          boxShadow: const [
                            BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                          ],
                        ),
                        child: InkWell(
                          onTap: () async {
                            await context.push('/admin/teacher-detail', extra: t);
                            _loadTeachers();
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: t.isActive ? AppTheme.primaryColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                                  child: Text(
                                    t.fullName.isNotEmpty ? t.fullName[0] : 'М',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: t.isActive ? AppTheme.primaryColor : AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              t.employeeCode,
                                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                                            ),
                                          ),
                                          Text(
                                            'Логин: ${t.username}',
                                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      if (t.subject != null && t.subject!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.menu_book_rounded, size: 12, color: AppTheme.primaryColor),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  t.subject!,
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (t.phone != null && t.phone!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Тел: ${t.phone}',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: t.isActive,
                                      activeTrackColor: AppTheme.successColor.withValues(alpha: 0.5),
                                      activeThumbColor: AppTheme.successColor,
                                      onChanged: (val) async {
                                        final success = await _repository.toggleTeacherActive(t.id, val);
                                        if (success) _loadTeachers();
                                      },
                                    ),
                                    const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 18),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 80), // Spacing for FAB
                ],
              ),
            ),
    );
  }

  Widget _buildFilterBadge(String label, String filter) {
    final isSelected = _statusFilter == filter;
    return InkWell(
      onTap: () => setState(() => _statusFilter = filter),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
