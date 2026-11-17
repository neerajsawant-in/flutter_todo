import 'package:flutter_test/flutter_test.dart';
import 'package:to_do/main.dart';

void main() {
  testWidgets('Dayflow dashboard opens', (WidgetTester tester) async {
    await tester.pumpWidget(const DayflowApp());
    await tester.pumpAndSettle();

    expect(find.text('dayflow'), findsOneWidget);
    expect(find.text('Today’s tasks'), findsOneWidget);
    expect(find.text('New task'), findsOneWidget);
  });
}
