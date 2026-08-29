import 'package:flutter_test/flutter_test.dart';
import 'package:sparklearn/main.dart';
import 'test_overrides.dart';

void main() {
  testWidgets(
    'SparkLearn app boots',
        (tester) async {
      await tester.pumpWidget(
        buildAppForTest(overrides: overridesForTests()),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('TEST HOME'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );
}