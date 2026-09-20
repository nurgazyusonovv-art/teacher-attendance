import 'package:admin_core/admin_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/leave_repository.dart';
import 'leave_cubit.dart';

class LeaveScreen extends StatelessWidget {
  final bool admin;
  const LeaveScreen({super.key, this.admin = false});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LeaveCubit(LeaveRepository(), admin: admin)..load(),
    child: _LeaveView(admin: admin),
  );
}

class _LeaveView extends StatefulWidget {
  final bool admin;
  const _LeaveView({required this.admin});
  @override
  State<_LeaveView> createState() => _LeaveViewState();
}

class _LeaveViewState extends State<_LeaveView> {
  final _form = GlobalKey<FormState>();
  final _date = TextEditingController();
  final _reason = TextEditingController();
  Future<void> _pickDate() async {
    // This is only a calendar hint; the backend validates the school date.
    final now = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date.text) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Уруксат сурала турган күн',
      cancelText: 'Жокко чыгаруу',
      confirmText: 'Тандоо',
    );
    if (selected != null && mounted) {
      _date.text =
          '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide(core.LeaveRequest row, String status) async {
    var reason = '';
    final form = GlobalKey<FormState>();
    final answer = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          status == 'APPROVED' ? 'Уруксатты бекитүү' : 'Арызды четке кагуу',
        ),
        content: Form(
          key: form,
          child: TextFormField(
            onChanged: (value) => reason = value,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Чечимдин себеби'),
            validator: (v) =>
                (v?.trim().length ?? 0) < 5 ? 'Кеминде 5 белги жазыңыз' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Жокко чыгаруу'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, reason.trim());
              }
            },
            child: const Text('Ырастоо'),
          ),
        ],
      ),
    );
    if (answer != null && mounted) {
      await context.read<LeaveCubit>().decide(
        row.id,
        status,
        answer,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.admin ? 'Уруксат арыздары' : 'Уруксат суроо'),
    ),
    body: BlocBuilder<LeaveCubit, LeaveState>(
      builder: (context, state) => RefreshIndicator(
        onRefresh: () => context.read<LeaveCubit>().load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          children: [
            if (!widget.admin)
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Арыз жөнөтүү уруксат берилди дегенди билдирбейт. Админ бекиткенден кийин гана «Себептүү» болот. Бир күнгө бир арыз.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _date,
                      readOnly: true,
                      onTap: state.busy ? null : _pickDate,
                      enabled: !state.busy,
                      decoration: const InputDecoration(
                        labelText: 'Кайсы күнгө уруксат керек?',
                        hintText: 'Календардан тандаңыз',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        final parsed = DateTime.tryParse(value);
                        return !RegExp(
                                  r'^\d{4}-\d{2}-\d{2}$',
                                ).hasMatch(value) ||
                                parsed == null ||
                                parsed.toIso8601String().substring(0, 10) !=
                                    value
                            ? 'Календардан күндү тандаңыз'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reason,
                      enabled: !state.busy,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Себеби',
                        hintText: 'Мисалы: дарыгерге көрүнүүгө барам',
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 5
                          ? 'Кеминде 5 белги жазыңыз'
                          : null,
                    ),
                    FilledButton(
                      onPressed: state.busy
                          ? null
                          : () async {
                              if (!_form.currentState!.validate()) return;
                              final sent = await context
                                  .read<LeaveCubit>()
                                  .submit(_date.text.trim(), _reason.text);
                              if (sent && context.mounted) {
                                _reason.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Арыз жөнөтүлдү. Администратордун чечимин күтүңүз.',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: const Text('Арыз жөнөтүү'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            if (!widget.admin) ...[
              Text(
                'Менин арыздарым',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
            ],
            if (state.busy) const LinearProgressIndicator(),
            if (state.error != null) ...[
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: state.busy
                    ? null
                    : () => context.read<LeaveCubit>().load(),
                child: const Text('Кайра жүктөө'),
              ),
            ],
            if (!state.busy && state.error == null && state.rows.isEmpty)
              Text(
                widget.admin
                    ? 'Арыздар жок'
                    : 'Азырынча арыз жөнөтө элексиз. Жөнөтүлгөн арыздын чечими ушул жерде көрүнөт.',
              ),
            ...state.rows.map(
              (row) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.admin)
                        Text(row.teacherName ?? 'Мугалим'),
                      Text(row.targetDate),
                      // Wording comes from the shared model, so the phone and the browser
                      // describe a request the same way.
                      Text(row.status.label),
                      Text(row.reason),
                      if (row.decisionReason != null)
                        Text('Чечим: ${row.decisionReason}'),
                      if (widget.admin && row.isPending)
                        Wrap(
                          spacing: 12,
                          children: [
                            FilledButton(
                              onPressed: state.busy
                                  ? null
                                  : () => _decide(row, 'APPROVED'),
                              child: const Text('Бекитүү'),
                            ),
                            OutlinedButton(
                              onPressed: state.busy
                                  ? null
                                  : () => _decide(row, 'REJECTED'),
                              child: const Text('Четке кагуу'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.hasMore)
              OutlinedButton(
                onPressed: state.busy
                    ? null
                    : () => context.read<LeaveCubit>().load(more: true),
                child: const Text('Дагы көрсөтүү'),
              ),
          ],
        ),
      ),
    ),
  );
}
