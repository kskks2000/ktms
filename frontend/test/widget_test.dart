import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktms_frontend/src/app.dart';
import 'package:ktms_frontend/src/auth/auth_service.dart';
import 'package:ktms_frontend/src/design/app_theme.dart';
import 'package:ktms_frontend/src/features/carrier/carrier_home_page.dart';
import 'package:ktms_frontend/src/features/driver/driver_home_page.dart';
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
    expect(find.text('기사 앱으로 시작'), findsOneWidget);
    expect(find.text('운송사 포털로 시작'), findsOneWidget);
  });

  testWidgets('opens driver app from login screen', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      KtmsApp(authService: AuthService.disabled('Test mode.')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('기사 앱으로 시작'));
    await tester.tap(find.text('기사 앱으로 시작'));
    await tester.pumpAndSettle();

    expect(find.text('KTMS Driver'), findsOneWidget);
    expect(find.text('김도윤 기사님'), findsOneWidget);
    expect(find.text('서울82바1724 · LP-20260616-001'), findsOneWidget);
    expect(find.text('알림'), findsWidgets);
  });

  testWidgets('renders driver vehicle and notification screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DriverHomePage(
          displayName: '김도윤',
          email: 'driver@kcastle.net',
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KTMS Driver'), findsOneWidget);
    expect(find.text('LP-20260616-001'), findsWidgets);

    await tester.tap(find.text('차량'));
    await tester.pumpAndSettle();

    expect(find.text('내 차량'), findsOneWidget);
    expect(find.text('서울82바1724'), findsWidgets);
    expect(find.text('GPS 추적'), findsOneWidget);

    await tester.tap(find.text('알림'));
    await tester.pumpAndSettle();

    expect(find.text('운행, 도착, 차량 상태 알림'), findsOneWidget);
    expect(find.text('POD 등록 필요'), findsOneWidget);
  });

  testWidgets('opens carrier portal from login screen', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      KtmsApp(authService: AuthService.disabled('Test mode.')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('운송사 포털로 시작'));
    await tester.tap(find.text('운송사 포털로 시작'));
    await tester.pumpAndSettle();

    expect(find.text('KTMS Carrier'), findsOneWidget);
    expect(find.text('CJ대한통운 담당자'), findsOneWidget);
    expect(find.text('운송사 배차'), findsWidgets);
    expect(find.text('배차 확정'), findsWidgets);
  });

  testWidgets('renders carrier dispatch fleet alerts and settlement screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CarrierHomePage(
          displayName: '박지훈',
          email: 'carrier@cjlogistics.example',
          carrierName: 'CJ대한통운',
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KTMS Carrier'), findsOneWidget);
    expect(find.text('LP-20260616-004'), findsWidgets);

    await tester.tap(find.text('배차'));
    await tester.pumpAndSettle();

    expect(find.text('배정 목록'), findsOneWidget);
    expect(find.text('자사 차량 선택'), findsOneWidget);
    expect(find.text('경기91사4402'), findsWidgets);

    await tester.tap(find.text('차량'));
    await tester.pumpAndSettle();

    expect(find.text('자사 차량'), findsWidgets);
    expect(find.text('CJ대한통운 차량/기사'), findsOneWidget);

    await tester.tap(find.text('알림'));
    await tester.pumpAndSettle();

    expect(find.text('위탁 배정, 배차, 정산'), findsOneWidget);
    expect(find.text('LP-20260616-004 배차 확정 필요'), findsOneWidget);

    await tester.tap(find.text('정산'));
    await tester.pumpAndSettle();

    expect(find.text('CJ대한통운 매입 정산'), findsOneWidget);
    expect(find.text('지급 예정'), findsOneWidget);
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

    await tester.ensureVisible(find.text('실행 트래킹').last);
    await tester.tap(find.text('실행 트래킹').last);
    await tester.pumpAndSettle();

    expect(find.text('차량 이동 및 경로 관제'), findsOneWidget);
    expect(find.text('키 연결 완료'), findsOneWidget);
  });

  testWidgets('opens order registration screen', (tester) async {
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

    await tester.tap(find.text('오더 등록').first);
    await tester.pumpAndSettle();

    expect(find.text('오더 등록'), findsWidgets);
    expect(find.text('transport_orders / lines / stops'), findsOneWidget);
    expect(find.text('고객사'), findsWidgets);
    expect(find.text('상차지'), findsWidgets);
    expect(find.text('하차지'), findsWidgets);
    expect(find.text('청구 운임'), findsWidgets);

    await tester.tap(find.text('신규 오더'));
    await tester.pumpAndSettle();

    final orderNoField = find.widgetWithText(TextField, '오더번호');
    final orderNoTextField = tester.widget<TextField>(orderNoField);
    expect(orderNoTextField.readOnly, isTrue);
    expect(
      orderNoTextField.controller?.text,
      matches(RegExp(r'^KT-\d{8}-\d{4}$')),
    );
    expect(find.byTooltip('새 번호 발급'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '고객사'), '테스트고객사');
    await tester.enterText(find.widgetWithText(TextField, '상차지'), '테스트상차지');
    await tester.enterText(find.widgetWithText(TextField, '하차지'), '테스트하차지');
    await tester.enterText(find.widgetWithText(TextField, '품목'), '테스트품목');

    final weightField = find.widgetWithText(TextField, '중량(kg)');
    await tester.enterText(weightField, '1197');
    await tester.enterText(weightField, '1197ㄴㅇㄹ');
    expect(tester.widget<TextField>(weightField).controller?.text, '1197');
    await tester.enterText(weightField, '1197.5');
    expect(tester.widget<TextField>(weightField).controller?.text, '1197.5');

    final chargeField = find.widgetWithText(TextField, '청구 운임');
    await tester.enterText(chargeField, '1280000');
    await tester.enterText(chargeField, '1280000abc');
    expect(tester.widget<TextField>(chargeField).controller?.text, '1280000');
    await tester.enterText(chargeField, '1280000.5');
    expect(tester.widget<TextField>(chargeField).controller?.text, '1280000');

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '오더 저장'));
    await tester.tap(find.widgetWithText(ElevatedButton, '오더 저장'));
    await tester.pumpAndSettle();

    expect(find.textContaining('운송오더가 등록되었습니다.'), findsOneWidget);
  });

  testWidgets('opens load planning composition screen', (tester) async {
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

    await tester.tap(find.text('편성/상차조합').first);
    await tester.pumpAndSettle();

    expect(find.text('편성/상차조합'), findsWidgets);
    expect(find.text('미편성 오더 풀'), findsOneWidget);
    expect(find.text('상차조합 작업대'), findsOneWidget);
    expect(find.text('조합 후보'), findsOneWidget);

    await tester.tap(find.text('상차조합 생성').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('상차조합 후보를 생성했습니다.'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '조합 확정'));
    await tester.tap(find.widgetWithText(ElevatedButton, '조합 확정'));
    await tester.pumpAndSettle();

    expect(find.textContaining('확정 완료'), findsWidgets);
    expect(find.text('배정/배차 대기'), findsWidgets);
    expect(find.text('KT-20260615-0002'), findsNothing);
  });

  testWidgets('opens dispatch planning screen and issues dispatch', (
    tester,
  ) async {
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

    await tester.tap(find.text('배정/배차').first);
    await tester.pumpAndSettle();

    expect(find.text('배정/배차'), findsWidgets);
    expect(find.text('확정 상차조합 대기열'), findsOneWidget);
    expect(find.text('배정/배차 후보 선택'), findsOneWidget);
    expect(find.text('통합 후보 리스트'), findsOneWidget);
    expect(find.text('운송사 배정 상세'), findsOneWidget);
    expect(find.text('CJ대한통운'), findsWidgets);
    expect(find.textContaining('서울 82바 1724'), findsWidgets);

    await tester.ensureVisible(find.textContaining('서울 82바 1724').first);
    await tester.tap(find.textContaining('서울 82바 1724').first);
    await tester.pumpAndSettle();

    expect(find.text('직접 배차 상세'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '직접 배차 발행'), findsOneWidget);

    await tester.ensureVisible(find.text('CJ대한통운').first);
    await tester.tap(find.text('CJ대한통운').first);
    await tester.pumpAndSettle();

    expect(find.text('운송사 배정 상세'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, '운송사 배정 발행'),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, '운송사 배정 발행'));
    await tester.pumpAndSettle();

    expect(find.textContaining('운송사 배정 완료'), findsWidgets);
    expect(find.text('운송사 배정'), findsWidgets);
  });

  testWidgets(
    'opens execution tracking screen and refreshes vehicle location',
    (tester) async {
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

      await tester.tap(find.text('실행 트래킹').first);
      await tester.pumpAndSettle();

      expect(find.text('실행 트래킹'), findsWidgets);
      expect(find.text('차량 이동 및 경로 관제'), findsOneWidget);
      expect(find.text('Naver Map'), findsOneWidget);
      expect(find.text('키 연결 완료'), findsOneWidget);
      expect(find.text('운송 실행 목록'), findsOneWidget);
      expect(find.text('운송실행 상세'), findsOneWidget);
      expect(find.text('LP-20260616-001'), findsWidgets);
      expect(find.text('서울 82바 1724'), findsWidgets);

      await tester.tap(find.widgetWithText(OutlinedButton, '위치 갱신'));
      await tester.pumpAndSettle();

      expect(find.textContaining('위치를 갱신했습니다.'), findsOneWidget);

      await tester.ensureVisible(find.text('지연위험'));
      await tester.tap(find.text('지연위험'));
      await tester.pumpAndSettle();

      expect(find.text('LP-20260616-004'), findsWidgets);
      await tester.tap(find.text('LP-20260616-004').first);
      await tester.pumpAndSettle();

      expect(find.text('출발 예정 시간이 초과되었습니다. 배차 담당자 확인이 필요합니다.'), findsOneWidget);
    },
  );

  testWidgets('opens performance confirmation and settlement screens', (
    tester,
  ) async {
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

    await tester.ensureVisible(find.text('실적 확정').first);
    await tester.tap(find.text('실적 확정').first);
    await tester.pumpAndSettle();

    expect(find.text('실적 확정 및 정산'), findsOneWidget);
    expect(find.text('운송 실적 확정'), findsOneWidget);
    expect(find.text('POD/온도/도착 실적'), findsOneWidget);
    expect(find.text('매출정산'), findsWidgets);
    expect(find.text('매입정산'), findsWidgets);
    expect(find.text('KT-20260615-0001'), findsOneWidget);
    expect(find.text('KT-20260615-0003'), findsNothing);

    final confirmPerformanceButton = find
        .widgetWithText(ElevatedButton, '선택 실적 확정')
        .first;
    await tester.ensureVisible(confirmPerformanceButton);
    await tester.tap(confirmPerformanceButton);
    await tester.pumpAndSettle();

    expect(find.text('실적 확정 완료'), findsOneWidget);
    expect(find.text('확정 대기 실적이 없습니다'), findsOneWidget);
    expect(find.text('KT-20260615-0001'), findsNothing);
    expect(find.text('KT-20260615-0002'), findsNothing);
    expect(find.text('KT-20260615-0004'), findsNothing);

    await tester.ensureVisible(find.text('정산 관리').first);
    await tester.tap(find.text('정산 관리').first);
    await tester.pumpAndSettle();

    expect(find.text('정산 관리'), findsWidgets);
    expect(find.text('매출정산'), findsWidgets);
    expect(find.text('매출 거래명세서'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '매출 거래명세서 생성'), findsWidgets);

    await tester.tap(find.text('매입정산').first);
    await tester.pumpAndSettle();

    expect(find.text('매입 지급 정산'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '매입 정산 확정'), findsWidgets);
  });

  testWidgets('opens customer shipper carrier master screen', (tester) async {
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

    await tester.tap(find.text('마스터 등록').first);
    await tester.pumpAndSettle();

    expect(find.text('거래처 마스터'), findsOneWidget);
    expect(find.text('고객사'), findsWidgets);
    expect(find.text('화주'), findsWidgets);
    expect(find.text('운송사'), findsWidgets);
    expect(find.text('partner_short_name'), findsNothing);
    expect(find.text('약칭'), findsWidgets);
  });

  testWidgets('opens delivery destination master screen', (tester) async {
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

    await tester.tap(find.text('배송처 마스터').first);
    await tester.pumpAndSettle();

    expect(find.text('배송처 마스터'), findsWidgets);
    expect(find.text('delivery_destinations'), findsOneWidget);
    expect(find.text('배송처 코드'), findsOneWidget);
    expect(find.text('예약 필수'), findsWidgets);
    expect(find.text('POD 필수'), findsOneWidget);
  });

  testWidgets('opens route zone master screen', (tester) async {
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

    await tester.tap(find.text('권역/노선 마스터').first);
    await tester.pumpAndSettle();

    expect(find.text('권역/노선 마스터'), findsWidgets);
    expect(find.text('transport_zones'), findsOneWidget);
    expect(find.text('권역 코드'), findsOneWidget);
    expect(find.text('노선 네트워크'), findsOneWidget);

    await tester.tap(find.text('노선').first);
    await tester.pumpAndSettle();

    expect(find.text('transport_routes'), findsOneWidget);
    expect(find.text('노선 코드'), findsOneWidget);
    expect(find.text('통행료 포함'), findsOneWidget);
  });

  testWidgets('opens vehicle master screen', (tester) async {
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

    await tester.tap(find.text('차량 마스터').first);
    await tester.pumpAndSettle();

    expect(find.text('차량 마스터'), findsWidgets);
    expect(find.text('vehicles'), findsOneWidget);
    expect(find.text('차량 코드'), findsOneWidget);
    expect(find.text('차량번호'), findsWidgets);
    expect(find.text('GPS 추적'), findsOneWidget);
    expect(find.text('보험 만료일'), findsOneWidget);

    await tester.tap(find.text('차량 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '차량번호'),
      '서울 88바 1234',
    );
    await tester.enterText(find.widgetWithText(TextField, '기본 기사'), '테스트기사');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '저장'));
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('서울 88바 1234 차량 마스터가 반영되었습니다.'), findsOneWidget);
  });

  testWidgets('opens driver master screen', (tester) async {
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

    await tester.ensureVisible(find.text('기사 마스터').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('기사 마스터').first);
    await tester.pumpAndSettle();

    expect(find.text('기사 마스터'), findsWidgets);
    expect(find.text('drivers'), findsWidgets);
    expect(find.text('기사 코드'), findsWidgets);
    expect(find.text('면허 만료일'), findsOneWidget);
    expect(find.text('모바일 앱 설치'), findsOneWidget);

    await tester.tap(find.text('기사 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '기사명'), '테스트기사');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '저장'));
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('테스트기사 기사 마스터가 반영되었습니다.'), findsOneWidget);
  });

  testWidgets('opens warehouse hub master screen', (tester) async {
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

    await tester.ensureVisible(find.text('창고/거점 마스터').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('창고/거점 마스터').first);
    await tester.pumpAndSettle();

    expect(find.text('창고/거점 마스터'), findsWidgets);
    expect(find.text('locations'), findsWidgets);
    expect(find.text('거점 코드'), findsWidgets);
    expect(find.text('도크 수'), findsWidgets);
    expect(find.text('온도관리'), findsWidgets);
    expect(find.text('야드 관리'), findsOneWidget);

    await tester.tap(find.text('창고/거점 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '거점명'), '테스트거점');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '저장'));
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('테스트거점 창고/거점이 반영되었습니다.'), findsOneWidget);
  });

  testWidgets('opens item master screen', (tester) async {
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

    await tester.ensureVisible(find.text('품목 마스터').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('품목 마스터').first);
    await tester.pumpAndSettle();

    expect(find.text('품목 마스터'), findsWidgets);
    expect(find.text('items'), findsWidgets);
    expect(find.text('품목 코드'), findsWidgets);
    expect(find.text('HS Code'), findsOneWidget);
    expect(find.text('온도관리'), findsWidgets);
    expect(find.text('LOT 관리'), findsOneWidget);

    await tester.tap(find.text('품목 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '품목명'), '테스트품목');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '저장'));
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('테스트품목 품목 마스터가 반영되었습니다.'), findsOneWidget);
  });

  testWidgets('opens freight contract master screen', (tester) async {
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

    await tester.ensureVisible(find.text('운임/계약 마스터').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('운임/계약 마스터').first);
    await tester.pumpAndSettle();

    expect(find.text('운임/계약 마스터'), findsWidgets);
    expect(find.text('rate_agreements / rate_agreement_lanes'), findsWidgets);
    expect(find.text('계약번호'), findsWidgets);
    expect(find.text('구간 운임'), findsOneWidget);
    expect(find.text('요율 규칙'), findsOneWidget);
    expect(find.text('유류할증 적용'), findsOneWidget);

    await tester.tap(find.text('계약 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '계약명'), '테스트운임계약');
    await tester.enterText(find.widgetWithText(TextField, '거래처'), '테스트거래처');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '저장'));
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('테스트운임계약 운임/계약 마스터가 반영되었습니다.'), findsOneWidget);
  });

  testWidgets('opens user access master screen', (tester) async {
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

    await tester.ensureVisible(find.text('사용자/권한').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('사용자/권한').first);
    await tester.pumpAndSettle();

    expect(find.text('사용자/권한 마스터'), findsWidgets);
    expect(find.text('app_users / roles / permissions'), findsWidgets);
    expect(find.text('로그인 ID'), findsWidgets);
    expect(find.text('권한 매트릭스'), findsOneWidget);
    expect(find.text('MFA 필수'), findsOneWidget);

    await tester.tap(find.text('사용자 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '사용자명'), '테스트사용자');
    await tester.enterText(
      find.widgetWithText(TextField, '로그인 ID'),
      'test.user@kcastle.net',
    );
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '저장'));
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('테스트사용자 사용자/권한 마스터가 반영되었습니다.'), findsOneWidget);
  });

  testWidgets('opens common code master screen', (tester) async {
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

    await tester.ensureVisible(find.text('공통코드 마스터').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('공통코드 마스터').first);
    await tester.pumpAndSettle();

    expect(find.text('공통코드 마스터'), findsWidgets);
    expect(find.text('code_groups / codes'), findsWidgets);
    expect(find.text('그룹 코드'), findsWidgets);
    expect(find.text('코드값'), findsWidgets);
    expect(find.text('기본 코드'), findsWidgets);

    await tester.tap(find.text('코드 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '코드명'), '테스트코드');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '저장'));
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('테스트코드 공통코드 마스터가 반영되었습니다.'), findsOneWidget);
  });
}
