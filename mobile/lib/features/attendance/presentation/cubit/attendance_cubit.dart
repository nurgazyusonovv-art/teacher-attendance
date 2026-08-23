import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/attendance_repository.dart';
import 'attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository _repository;

  AttendanceCubit({AttendanceRepository? repository})
      : _repository = repository ?? AttendanceRepository(),
        super(AttendanceInitial());

  Future<void> loadTodayStatus() async {
    emit(AttendanceLoading());
    try {
      final status = await _repository.getTodayStatus();
      if (status != null) {
        emit(AttendanceTodayLoaded(status));
      } else {
        emit(const AttendanceError('Бүгүнкү абалды жүктөө мүмкүн болгон жок'));
      }
    } catch (e) {
      emit(AttendanceError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> checkIn({
    required String schoolId,
    required String qrToken,
    required double latitude,
    required double longitude,
    required double accuracy,
    String? deviceInfo,
  }) async {
    emit(AttendanceLoading());
    try {
      final record = await _repository.checkIn(
        schoolId: schoolId,
        qrToken: qrToken,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        deviceInfo: deviceInfo,
      );
      emit(AttendanceActionSuccess(
        record,
        record.status == 'ON_TIME'
            ? 'Келүү ийгиликтүү катталды! (Өз убагында)'
            : 'Келүү катталды (Кечиккен: ${record.lateMinutes} мүнөт)',
      ));
    } catch (e) {
      emit(AttendanceError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> checkOut({
    required String schoolId,
    required String qrToken,
    required double latitude,
    required double longitude,
    required double accuracy,
    String? deviceInfo,
  }) async {
    emit(AttendanceLoading());
    try {
      final record = await _repository.checkOut(
        schoolId: schoolId,
        qrToken: qrToken,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        deviceInfo: deviceInfo,
      );
      emit(AttendanceActionSuccess(
        record,
        'Кетүү ийгиликтүү катталды! Иштеген убактыңыз: ${record.workedMinutes} мүнөт.',
      ));
    } catch (e) {
      emit(AttendanceError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> loadHistory({int? year, int? month}) async {
    emit(AttendanceLoading());
    try {
      final history = await _repository.getMyHistory(year: year, month: month);
      emit(AttendanceHistoryLoaded(history));
    } catch (e) {
      emit(AttendanceError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
