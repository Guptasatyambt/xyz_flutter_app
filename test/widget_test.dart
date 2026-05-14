import 'package:flutter_test/flutter_test.dart';
import 'package:xyz/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CabApp());
  });
}
