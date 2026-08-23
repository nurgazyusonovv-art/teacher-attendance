import 'package:equatable/equatable.dart';
import '../../data/repositories/attendance_repository.dart';

abstract class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoading extends AttendanceState {}

class AttendanceTodayLoaded extends AttendanceState {
  final TodayStatusModel status;

  const AttendanceTodayLoaded(this.status);

  @override
  List<Object?> get props => [status];
}

class AttendanceActionSuccess extends AttendanceState {
  final DailyAttendanceModel record;
  final String message;

  const AttendanceActionSuccess(this.record, this.message);

  @override
  List<Object?> get props => [record, message];
}

class AttendanceHistoryLoaded extends AttendanceState {
  final List<DailyAttendanceModel> history;

  const AttendanceHistoryLoaded(this.history);

  @override
  List<Object?> get props => [history];
}

class AttendanceError extends AttendanceState {
  final String message;

  const AttendanceError(this.message);

  @override
  List<Object?> get props => [message];
}
