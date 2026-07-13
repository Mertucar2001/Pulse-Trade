import 'package:flutter_test/flutter_test.dart';
import 'package:pulsetrade/main.dart';

void main() {
  testWidgets('PulseTrade app loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PulseTradeApp());
    await tester.pump();

    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('PulseTrade'), findsOneWidget);
  });
}
