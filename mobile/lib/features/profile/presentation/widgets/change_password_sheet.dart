import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/repositories/auth_repository.dart';

/// Lets a teacher replace the password their administrator chose for them.
///
/// The administrator knows that password, and it cannot be changed from the
/// admin panel either — this is the only way to rotate it.
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key, this.repository});

  /// Injectable for tests; defaults to the app's authenticated client.
  final AuthRepository? repository;

  /// Opens the sheet. Resolves to true when the password was changed.
  static Future<bool?> show(BuildContext context, {AuthRepository? repository}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ChangePasswordSheet(repository: repository),
      ),
    );
  }

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  static const int _minLength = 8;

  late final AuthRepository _repository =
      widget.repository ??
      AuthRepository(
        apiClient: ApiClient(storageService: SecureStorageService()),
        storageService: SecureStorageService(),
      );

  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final failure = await _repository.changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _busy = false;
        _error = failure;
      });
      return;
    }

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Сырсөз өзгөртүлдү. Башка түзмөктөрдөн чыгарылдыңыз.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Сырсөздү өзгөртүү',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Жаңы сырсөздү орноткондон кийин башка түзмөктөрдөн чыгасыз.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              _field(
                controller: _current,
                label: 'Учурдагы сырсөз',
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Учурдагы сырсөздү жазыңыз'
                    : null,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _next,
                label: 'Жаңы сырсөз',
                validator: (value) {
                  if (value == null || value.length < _minLength) {
                    return 'Кеминде $_minLength белги болушу керек';
                  }
                  if (value == _current.text) {
                    return 'Жаңы сырсөз эскисинен айырмаланышы керек';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _field(
                controller: _confirm,
                label: 'Жаңы сырсөздү кайталаңыз',
                validator: (value) =>
                    value != _next.text ? 'Сырсөздөр дал келбейт' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сактоо'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: _obscure,
      enabled: !_busy,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Көрсөтүү' : 'Жашыруу',
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: validator,
    );
  }
}
