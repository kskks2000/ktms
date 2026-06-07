import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktms_frontend/src/app.dart';
import 'package:ktms_frontend/src/auth/auth_service.dart';
import 'package:ktms_frontend/src/design/app_theme.dart';
import 'package:ktms_frontend/src/features/tms/tms_home_page.dart';

void main() {
  testWidgets('renders KTMS login screen', (tester) async {
    await tester.pumpWidget(
      KtmsApp(authService: AuthService.disabled('Test mode.')),
    );
    await tester.pumpAndSettle();

    expect(find.text('KTMS'), findsWidgets);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('switches to account creation screen', (tester) async {
    await tester.pumpWidget(
      KtmsApp(authService: AuthService.disabled('Test mode.')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Sign up with Google'), findsOneWidget);
  });

  testWidgets('renders TMS control dashboard', (tester) async {
    tester.view.physicalSize = const Size(1440, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TmsHomePage(
          displayName: 'KTMS Operator',
          email: 'operator@ktms.local',
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TMS 운영 관제'), findsOneWidget);
    expect(find.text('운송 업무 흐름'), findsOneWidget);
    expect(find.text('마스터 등록'), findsWidgets);
    expect(find.text('실행 트래킹'), findsWidgets);
  });
}
