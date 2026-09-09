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
  @override
  void dispose() {
    _date.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide(Map<String, dynamic> row, String status) async {
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
        row['id'] as String,
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
                      enabled: !state.busy,
                      decoration: const InputDecoration(
                        labelText: 'Күнү (ЖЖЖЖ-АА-КК)',
                        hintText: '2026-09-10',
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
                            ? 'Күндү туура жазыңыз'
                            : null;
                      },
                    ),
                    TextFormField(
                      controller: _reason,
                      enabled: !state.busy,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(labelText: 'Себеби'),
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
                                    content: Text('Арыз жөнөтүлдү'),
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
              const Text('Арыздар жок'),
            ...state.rows.map(
              (row) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.admin)
                        Text(row['teacher_name'] as String? ?? 'Мугалим'),
                      Text(row['target_date'] as String),
                      Text(switch (row['status']) {
                        'APPROVED' => 'Бекитилди',
                        'REJECTED' => 'Четке кагылды',
                        _ => 'Күтүүдө',
                      }),
                      Text(row['reason'] as String),
                      if (row['decision_reason'] != null)
                        Text('Чечим: ${row['decision_reason']}'),
                      if (widget.admin && row['status'] == 'PENDING')
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
