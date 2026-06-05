import 'package:flutter_test/flutter_test.dart';
import 'package:ktms_frontend/main.dart' as app;

void main() {
  testWidgets('renders KTMS login screen', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.text('KTMS'), findsWidgets);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
