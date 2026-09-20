import 'package:admin_core/admin_core.dart' as core;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../data/leave_repository.dart';

class LeaveState {
  final List<core.LeaveRequest> rows;
  final bool busy;
  final bool hasMore;
  final String? error;
  const LeaveState({
    this.rows = const [],
    this.busy = false,
    this.hasMore = false,
    this.error,
  });
}

class LeaveCubit extends Cubit<LeaveState> {
  final LeaveRepository repository;
  final bool admin;
  LeaveCubit(this.repository, {required this.admin})
    : super(const LeaveState());
  String _message(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'Сессия бүттү. Кайра кириңиз.';
      }
      final data = error.response?.data;
      if (error.response?.statusCode == 409 &&
          data is Map &&
          data['message'] is String) {
        return data['message'] as String;
      }
    }
    return 'Аракет аткарылган жок. Байланышты текшерип, кайра аракет кылыңыз.';
  }

  Future<void> load({bool more = false}) async {
    if (state.busy) return;
    final old = state.rows;
    emit(LeaveState(rows: old, busy: true));
    try {
      final rows = await repository.list(admin, more ? old.length : 0);
      if (!isClosed) {
        emit(
          LeaveState(
            rows: more ? [...old, ...rows] : rows,
            hasMore: rows.length == 50,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) emit(LeaveState(rows: old, error: _message(e)));
    }
  }

  Future<bool> submit(String date, String reason) =>
      _write(() => repository.submit(date, reason));
  Future<bool> decide(String id, String status, String reason) =>
      _write(() => repository.decide(id, status, reason));
  Future<bool> _write(Future<void> Function() action) async {
    if (state.busy) return false;
    final old = state.rows;
    emit(LeaveState(rows: old, busy: true));
    try {
      await action();
      if (isClosed) return true;
      emit(LeaveState(rows: old));
      await load();
      return true;
    } catch (e) {
      if (!isClosed) emit(LeaveState(rows: old, error: _message(e)));
      return false;
    }
  }
}
