import 'package:admin_core/admin_core.dart' as core;
import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Approving teachers' devices from the phone.
///
/// Device binding (PROJECT.md §10) was only administrable from the desktop
/// browser, which school staff rarely open — so the feature could not actually
/// be switched on. The list and the calls come from `admin_core`, the same
/// code the browser uses.
class AdminDevicesScreen extends StatefulWidget {
  const AdminDevicesScreen({super.key, this.repository});

  /// Injectable for tests; defaults to the app's authenticated client.
  final core.DevicesRepository? repository;

  @override
  State<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends State<AdminDevicesScreen> {
  late final core.DevicesRepository _repository =
      widget.repository ??
      core.DevicesRepository(
        dio: ApiClient(storageService: SecureStorageService()).dio,
      );

  List<core.TeacherDevice> _devices = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await _repository.list();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } on core.AdminApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _change(core.TeacherDevice device, {required bool approve}) async {
    if (_busyId != null) return;

    if (!approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Түзмөктү жокко чыгаруу'),
          content: Text(
            '${device.teacherName} бул түзмөктөн каттай албай калат. '
            'Улантасызбы?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Жок'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Ооба'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busyId = device.id);
    try {
      if (approve) {
        await _repository.approve(device.id);
      } else {
        await _repository.revoke(device.id);
      }
      if (!mounted) return;
      setState(() => _busyId = null);
      _snack(
        approve
            ? '${device.teacherName}: түзмөк ырасталды'
            : '${device.teacherName}: түзмөк жокко чыгарылды',
      );
      await _load();
    } on core.AdminApiException catch (error) {
      if (!mounted) return;
      setState(() => _busyId = null);
      _snack(error.message, isError: true);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _devices.where((d) => d.isPending).toList();
    final others = _devices.where((d) => !d.isPending).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Катталган түзмөктөр'),
        actions: [
          IconButton(
            tooltip: 'Жаңылоо',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(pending, others),
      ),
    );
  }

  Widget _buildBody(
    List<core.TeacherDevice> pending,
    List<core.TeacherDevice> others,
  ) {
    if (_loading && _devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _devices.isEmpty) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        text: _error!,
        actionLabel: 'Кайра аракет',
        onAction: _load,
      );
    }
    if (_devices.isEmpty) {
      return const _Message(
        icon: Icons.devices_other_rounded,
        text:
            'Азырынча катталган түзмөк жок. Мугалим тиркемеге киргенде түзмөгү '
            'ушул жерде көрүнөт.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'Ар бир мугалимге бир гана ырасталган түзмөк. Жаңы түзмөк сиз '
          'ырастаганга чейин каттай албайт.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        if (pending.isNotEmpty) ...[
          _SectionTitle('Ырастоону күтүүдө (${pending.length})'),
          ...pending.map(_buildCard),
          const SizedBox(height: 20),
        ],
        if (others.isNotEmpty) ...[
          const _SectionTitle('Башка түзмөктөр'),
          ...others.map(_buildCard),
        ],
      ],
    );
  }

  Widget _buildCard(core.TeacherDevice device) {
    final busy = _busyId == device.id;
    final color = switch (device.status) {
      core.DeviceStatus.approved => Colors.green,
      core.DeviceStatus.pending => Colors.amber.shade800,
      core.DeviceStatus.revoked => Colors.red,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    device.teacherName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    device.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${device.platform} · ${device.shortDeviceId}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  if (!device.isApproved)
                    FilledButton.tonalIcon(
                      onPressed: () => _change(device, approve: true),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Ырастоо'),
                    ),
                  if (device.isApproved)
                    TextButton.icon(
                      onPressed: () => _change(device, approve: false),
                      icon: const Icon(
                        Icons.block_rounded,
                        size: 18,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Жокко чыгаруу',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(icon, size: 48, color: AppTheme.primaryColor.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
