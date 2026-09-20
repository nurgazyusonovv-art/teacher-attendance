import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_admin/features/teachers/data/repositories/teachers_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final status in [200, 201, 400, 422, 500]) {
    test(
      'Teacher creation reports HTTP $status without hiding failures',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              // A success carries the created teacher, the way the API does;
              // a failure carries the error body.
              final response = Response(
                requestOptions: request,
                statusCode: status,
                data: status < 300
                    ? {
                        'id': 't-1',
                        'user_id': 'u-1',
                        'school_id': 's-1',
                        'employee_code': 'T1',
                        'full_name': 'Test Teacher',
                        'username': 'teacher',
                        'is_active': true,
                        'is_demo': false,
                      }
                    : {'message': 'Логин бош эмес: teacher'},
              );
              if (status < 300) {
                handler.resolve(response);
              } else {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    response: response,
                    type: DioExceptionType.badResponse,
                  ),
                );
              }
            },
          ),
        );
        final result = TeachersRepository(dio: dio).createTeacher(
          fullName: 'Test Teacher',
          username: 'teacher',
          password: 'test-pass-123',
          employeeCode: 'T1',
        );
        if (status < 300) {
          expect(await result, isTrue);
        } else {
          await expectLater(
            result,
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains(
                  status == 400
                      ? 'Логин бош эмес'
                      : status == 422
                      ? '8'
                      : 'ырасталган жок',
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
