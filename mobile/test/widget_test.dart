import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_mobile/app/app.dart';

void main() {
  testWidgets('App renders login screen initially', (WidgetTester tester) async {
    await tester.pumpWidget(const TeacherApp());
    expect(find.text('Мугалим Каттоо'), findsOneWidget);
    expect(find.text('Кирүү'), findsOneWidget);
  });
}
