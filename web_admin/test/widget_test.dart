import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_admin/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Admin app renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TeacherAdminApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Административдик Панель'), findsOneWidget);
    expect(find.text('Кирүү'), findsOneWidget);
  });
}
