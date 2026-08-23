import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_mobile/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('App renders login screen initially', (WidgetTester tester) async {
    await tester.pumpWidget(const TeacherApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Мугалим Каттоо'), findsOneWidget);
    expect(find.text('Кирүү'), findsOneWidget);
  });
}
