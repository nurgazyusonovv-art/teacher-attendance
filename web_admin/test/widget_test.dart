import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_admin/app/app.dart';

void main() {
  testWidgets('Admin app renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TeacherAdminApp());
    expect(find.text('Административдик Панель'), findsOneWidget);
    expect(find.text('Кирүү'), findsOneWidget);
  });
}
