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

  void _showAddTeacherDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final codeController = TextEditingController(text: 'TCH-00${_teachers.length + 1}');
    final passwordController = TextEditingController(text: 'teacher123');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Жаңы мугалим кошуу'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Аты-жөнү (Ф.И.О.) *', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Аты-жөнүн жазыңыз' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Логин *', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Логинди жазыңыз' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Электрондук дарек (Email) *', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Email жазыңыз' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Телефон номери (+996...)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Табель коду *', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Табель кодун жазыңыз' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Сырсөз *', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.length < 6 ? 'Сырсөз кеминде 6 белги болушу керек' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Жокко чыгаруу')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final success = await _repository.createTeacher(
                fullName: nameController.text.trim(),
                username: usernameController.text.trim(),
                email: emailController.text.trim(),
                phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                employeeCode: codeController.text.trim(),
                password: passwordController.text.trim(),
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (success) {
                _loadTeachers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Мугалим ийгиликтүү кошулду!'), backgroundColor: AppTheme.successColor),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ката кетти. Логин же Email кайталанбашы керек.'), backgroundColor: AppTheme.errorColor),
                  );
                }
              }
            },
            child: const Text('Кошуу'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _teachers.where((t) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.fullName.toLowerCase().contains(q) ||
          t.employeeCode.toLowerCase().contains(q) ||
          t.username.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTeacherDialog,
        icon: const Icon(Icons.add),
        label: const Text('Мугалим кошуу'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeachers,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Search Bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Мугалимдин аты же коду боюнча издөө...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Жалпы мугалимдер: ${_teachers.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      Text('Активдүү: ${_teachers.where((t) => t.isActive).length}', style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (filtered.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('Мугалим табылган жок')),
                      ),
                    )
                  else
                    ...filtered.map((t) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () => context.push('/admin/teacher-detail', extra: t),
                          leading: CircleAvatar(
                            backgroundColor: t.isActive ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
                            child: Text(
                              t.fullName.isNotEmpty ? t.fullName[0] : 'М',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: t.isActive ? AppTheme.primaryColor : Colors.grey,
                              ),
                            ),
                          ),
                          title: Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Код: ${t.employeeCode}  •  Логин: ${t.username}'),
                              if (t.phone != null && t.phone!.isNotEmpty) Text('Тел: ${t.phone}'),
                            ],
                          ),
                          trailing: Switch(
                            value: t.isActive,
                            activeTrackColor: AppTheme.successColor.withValues(alpha: 0.5),
                            activeThumbColor: AppTheme.successColor,
                            onChanged: (val) async {
                              final success = await _repository.toggleTeacherActive(t.id, val);
                              if (success) _loadTeachers();
                            },
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 60), // Spacing for FAB
                ],
              ),
            ),
    );
  }
}
