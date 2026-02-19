import 'package:flutter_test/flutter_test.dart';
import 'package:airbridge/app/airbridge_app.dart';

void main() {
  testWidgets('AirBridge shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AirBridgeApp());
    expect(find.text('AirBridge'), findsOneWidget);
  });
}
