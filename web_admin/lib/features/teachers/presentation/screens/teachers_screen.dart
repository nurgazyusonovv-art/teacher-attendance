import 'package:flutter/material.dart';
import 'package:teacher_admin/core/theme/admin_theme.dart';
import 'package:teacher_admin/features/teachers/data/repositories/teachers_repository.dart';

class TeachersScreen extends StatefulWidget {
  const TeachersScreen({super.key});

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  final TeachersRepository _repository = TeachersRepository();
  final TextEditingController _searchController = TextEditingController();

  List<TeacherItem> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    final list = await _repository.getTeachers(
      search: _searchController.text.trim(),
    );
    if (mounted) {
      setState(() {
        _teachers = list;
        _isLoading = false;
      });
    }
  }

  void _showAddTeacherDialog() {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    final phoneController = TextEditingController();
    final subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Жаңы мугалим кошуу'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Аты-жөнү *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Логин *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Сырсөз *'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Табель номери *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Предмети'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Телефон номери'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Жокко чыгаруу'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  usernameController.text.trim().isEmpty ||
                  passwordController.text.trim().isEmpty ||
                  codeController.text.trim().isEmpty) {
                return;
              }
              final success = await _repository.createTeacher(
                fullName: nameController.text.trim(),
                username: usernameController.text.trim(),
                password: passwordController.text.trim(),
                employeeCode: codeController.text.trim(),
                phoneNumber: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                subject: subjectController.text.trim().isEmpty ? null : subjectController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (success) {
                _loadTeachers();
              }
            },
            child: const Text('Кошуу'),
          ),
        ],
      ),
    );
  }

  void _showEditTeacherDialog(TeacherItem teacher) {
    final nameController = TextEditingController(text: teacher.fullName);
    final codeController = TextEditingController(text: teacher.employeeCode);
    final phoneController = TextEditingController(text: teacher.phoneNumber ?? '');
    final subjectController = TextEditingController(text: teacher.subject ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Мугалимдин маалыматын оңдоо'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Аты-жөнү'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Табель номери'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Предмети'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Телефон номери'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Жокко чыгаруу'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await _repository.updateTeacher(
                teacherId: teacher.id,
                fullName: nameController.text.trim(),
                employeeCode: codeController.text.trim(),
                phoneNumber: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                subject: subjectController.text.trim().isEmpty ? null : subjectController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (success) {
                _loadTeachers();
              }
            },
            child: const Text('Сактоо'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Мугалимдерди башкаруу',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Мугалимдердин тизмеси, аккаунттары жана статустары',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddTeacherDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Мугалим кошуу'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search and Filters Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Аты-жөнү, логини же табель коду боюнча издөө...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (_) => _loadTeachers(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _loadTeachers,
                    child: const Text('Издөө'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Data Table
          Expanded(
            child: Card(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _teachers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_outline, size: 48, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 12),
                              const Text(
                                'Мугалимдер табылган жок',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _showAddTeacherDialog,
                                child: const Text('Биринчи мугалимди кошуу'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Аты-жөнү')),
                              DataColumn(label: Text('Логин')),
                              DataColumn(label: Text('Табель номери')),
                              DataColumn(label: Text('Предмети')),
                              DataColumn(label: Text('Телефон')),
                              DataColumn(label: Text('Статусу')),
                              DataColumn(label: Text('Аракеттер')),
                            ],
                            rows: _teachers.map((teacher) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AdminTheme.accentColor.withValues(alpha: 0.1),
                                          child: Text(
                                            teacher.fullName.isNotEmpty ? teacher.fullName[0] : 'Т',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AdminTheme.accentColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          teacher.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        if (teacher.isDemo)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('DEMO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(teacher.username)),
                                  DataCell(Text(teacher.employeeCode)),
                                  DataCell(Text(teacher.subject ?? '-')),
                                  DataCell(Text(teacher.phoneNumber ?? '-')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: teacher.isActive
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        teacher.isActive ? 'Активдүү' : 'Өчүрүлгөн',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: teacher.isActive ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          tooltip: 'Оңдоо',
                                          onPressed: () => _showEditTeacherDialog(teacher),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            teacher.isActive ? Icons.block : Icons.check_circle_outline,
                                            size: 20,
                                            color: teacher.isActive ? Colors.red : Colors.green,
                                          ),
                                          tooltip: teacher.isActive ? 'Өчүрүү (Деактивация)' : 'Активдештирүү',
                                          onPressed: () async {
                                            await _repository.toggleActive(teacher.id, teacher.isActive);
                                            _loadTeachers();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
