// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:aptos_infinite_jukebox/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: "myapp",
        packageName: "mypackage",
        version: "1.1.1",
        buildNumber: "555",
        buildSignature: "whatever");
    await setup();
    await tester.pumpWidget(const MyApp());
  });
}
