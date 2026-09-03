import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/presentation/state/chat_state.dart';
import 'package:snape_ui/presentation/widgets/connection_status_banner.dart';

Widget createBannerTestApp({
  required ConnectionStatus status,
  String? errorMessage,
  VoidCallback? onRetry,
  Duration gracePeriod = const Duration(milliseconds: 1500),
}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, child) => MaterialApp(
      home: Scaffold(
        body: ConnectionStatusBanner(
          status: status,
          errorMessage: errorMessage,
          onRetry: onRetry ?? () {},
          gracePeriod: gracePeriod,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectionStatusBanner Grace Period & Display', () {
    testWidgets('Suppresses connecting status during 1.5-second grace period',
        (tester) async {
      await tester.pumpWidget(createBannerTestApp(
        status: ConnectionStatus.connecting,
        gracePeriod: const Duration(milliseconds: 1500),
      ));

      // Initially within grace period, banner is empty
      expect(find.text('Establishing live connection...'), findsNothing);

      // Advance by 1 second (still in grace period)
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Establishing live connection...'), findsNothing);

      // Advance past 1.5 seconds (grace period expired)
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Establishing live connection...'), findsOneWidget);
    });

    testWidgets('Connected status suppresses banner completely and immediately',
        (tester) async {
      await tester.pumpWidget(createBannerTestApp(
        status: ConnectionStatus.connected,
      ));

      expect(find.byType(ConnectionStatusBanner), findsOneWidget);
      expect(find.text('Establishing live connection...'), findsNothing);
      expect(find.text('Connecting to companion...'), findsNothing);

      // Advance time beyond grace period
      await tester.pump(const Duration(milliseconds: 2000));
      expect(find.text('Establishing live connection...'), findsNothing);
    });

    testWidgets(
        'Transitions to connected within grace period without showing banner',
        (tester) async {
      var currentStatus = ConnectionStatus.connecting;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (context, child) => MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      ConnectionStatusBanner(
                        status: currentStatus,
                        onRetry: () {},
                        gracePeriod: const Duration(milliseconds: 1500),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentStatus = ConnectionStatus.connected;
                          });
                        },
                        child: const Text('Connect'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

      // Initially in connecting state during grace period -> no banner text
      expect(find.text('Establishing live connection...'), findsNothing);

      // Simulate connection succeeding at 300ms
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      // Ensure banner remains hidden after grace period expires
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('Establishing live connection...'), findsNothing);
    });

    testWidgets('Shows error message and triggers retry callback',
        (tester) async {
      bool retried = false;
      await tester.pumpWidget(createBannerTestApp(
        status: ConnectionStatus.disconnected,
        errorMessage: 'Custom connection error',
        onRetry: () {
          retried = true;
        },
      ));

      expect(find.text('Custom connection error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('Shows reconnecting status after grace period', (tester) async {
      await tester.pumpWidget(createBannerTestApp(
        status: ConnectionStatus.reconnecting,
        gracePeriod: const Duration(milliseconds: 500),
      ));

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Reconnecting to stream...'), findsOneWidget);
    });
  });
}
