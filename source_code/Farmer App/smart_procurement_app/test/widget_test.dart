import 'package:flutter_test/flutter_test.dart';
import 'package:smart_procurement/main.dart';

void main() {
  testWidgets('Smart Procurement app starts', (tester) async {
    await tester.pumpWidget(const SmartProcurementApp());
    expect(find.text('SMART PROCUREMENT'), findsNothing);
    expect(find.textContaining('NAMASTE'), findsOneWidget);
  });
}
