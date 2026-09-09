import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';

class HistoryState {
  final List<DailyAttendanceModel> records;
  final bool loading;
  final String? error;
  const HistoryState({
    this.records = const [],
    this.loading = false,
    this.error,
  });
}

class HistoryCubit extends Cubit<HistoryState> {
  final AttendanceRepository repository;
  int _generation = 0;
  HistoryCubit(this.repository) : super(const HistoryState());
  Future<void> load(int year, int month) async {
    final generation = ++_generation;
    emit(const HistoryState(loading: true));
    try {
      final records = await repository.getMyHistory(year: year, month: month);
      if (!isClosed && generation == _generation) {
        emit(HistoryState(records: records));
      }
    } catch (_) {
      if (!isClosed && generation == _generation) {
        emit(
          const HistoryState(
            error:
                'Тарых жүктөлгөн жок. Байланышты текшерип, кайра аракет кылыңыз.',
          ),
        );
      }
    }
  }
}
