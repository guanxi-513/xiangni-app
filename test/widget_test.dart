import 'package:flutter_test/flutter_test.dart';
import 'package:miss_you_lover/main.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(const MissYouApp());
    expect(find.text('想你'), findsWidgets);
  });
}
