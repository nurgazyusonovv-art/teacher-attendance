import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_mobile/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('App renders splash screen initially and navigates to login', (WidgetTester tester) async {
    await tester.pumpWidget(const TeacherApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Мугалим Каттоо'), findsOneWidget);

    // Advance 3 seconds for splash timer
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Кирүү'), findsOneWidget);
  });
}
