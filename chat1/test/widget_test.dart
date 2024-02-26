
import 'package:chat1/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MyApp(prefs: prefs));

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
