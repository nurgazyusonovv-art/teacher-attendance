import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/admin_mobile_repository.dart';

class AddTeacherScreen extends StatefulWidget {
  const AddTeacherScreen({super.key});

  @override
  State<AddTeacherScreen> createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends State<AddTeacherScreen> {
  final AdminMobileRepository _repository = AdminMobileRepository();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController(text: 'teacher123');

  bool _obscurePassword = true;
  bool _isLoading = false;

  static const List<String> _commonSubjects = [
    'Башталгыч класс',
    'Кыргыз тили',
    'Математика',
    'Орус тили',
    'Англис тили',
    'Информатика',
    'Тарых',
    'Физика',
    'Химия',
    'Биология',
    'География',
    'Дене тарбия',
  ];

  @override
  void initState() {
    super.initState();
    _generateDefaultCode();
  }

  Future<void> _generateDefaultCode() async {
    final teachers = await _repository.getTeachers();
    if (mounted) {
      setState(() {
        _codeController.text = 'TCH-00${teachers.length + 1}';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _subjectController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    if (_usernameController.text.isEmpty || _usernameController.text.startsWith('tch_')) {
      final translit = _transliterate(val.trim().toLowerCase());
      if (translit.isNotEmpty) {
        _usernameController.text = translit;
      }
    }
  }

  String _transliterate(String text) {
    const map = {
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
      'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
      'н': 'n', 'ң': 'ng', 'о': 'o', 'ө': 'oe', 'п': 'p', 'р': 'r', 'с': 's',
      'т': 't', 'у': 'u', 'ү': 'ue', 'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch',
      'ш': 'sh', 'щ': 'shch', 'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu',
      'я': 'ya', ' ': '_',
    };
    final buffer = StringBuffer();
    for (final char in text.split('')) {
      buffer.write(map[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    final (success, errorMsg) = await _repository.createTeacher(
      fullName: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      subject: _subjectController.text.trim(),
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      employeeCode: _codeController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Жаңы мугалим ийгиликтүү кошулду!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop(true);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(errorMsg ?? 'Ката кетти. Кайра аракет кылыңыз.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Жаңы мугалим кошуу'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryColor, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Мугалимдин каттоо карточкасы',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Системага жаңы мугалимди кошуу үчүн толтуруңуз',
                              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Card 1: Personal & Subject Information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 17, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Жеке маалыматтар жана Предмети',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text('Аты-жөнү (Ф.И.О.) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        onChanged: _onNameChanged,
                        decoration: const InputDecoration(
                          hintText: 'Мис: Асанов Үсөн',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Мугалимдин аты-жөнүн жазыңыз' : null,
                      ),
                      const SizedBox(height: 12),
                      const Text('Окуткан предмети (Сабагы) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _subjectController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Мис: Математика, Кыргыз тили',
                          prefixIcon: Icon(Icons.menu_book_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Окуткан предметин жазыңыз' : null,
                      ),
                      const SizedBox(height: 8),
                      // Quick Subject Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _commonSubjects.map((sub) {
                          final isSelected = _subjectController.text == sub;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _subjectController.text = sub;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                                ),
                              ),
                              child: Text(
                                sub,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      const Text('Табель коду *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _codeController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'TCH-001',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Табель кодун жазыңыз' : null,
                      ),
                      const SizedBox(height: 12),
                      const Text('Телефон номери', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: '+996 700 123 456',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Card 2: Account & Authentication
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 17, color: AppTheme.secondaryColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Аккаунт жана Кирүү',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text('Логин *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'teacher_uson',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Логинди жазыңыз' : null,
                      ),
                      const SizedBox(height: 12),
                      const Text('Сырсөз *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Кеминде 6 белги',
                          prefixIcon: const Icon(Icons.password_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 6 ? 'Сырсөз кеминде 6 белги болушу керек' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Info Tip Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryLight),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Мугалим кошулгандан кийин өзүнүн логини жана сырсөзү менен тиркемеге кирип, дароо QR-кодду сканерлей алат.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_alt_1_rounded, size: 18),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Мугалимди кошуу',
                                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
