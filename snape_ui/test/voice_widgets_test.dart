import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/presentation/state/voice_call_state.dart';
import 'package:snape_ui/presentation/widgets/voice_orb_visualizer.dart';
import 'package:snape_ui/presentation/widgets/voice_subtitle_card.dart';
import 'package:snape_ui/presentation/widgets/voice_control_bar.dart';

Widget createTestWrapper(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('VoiceOrbVisualizer Widget', () {
    testWidgets('renders properly in idle phase', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceOrbVisualizer(phase: VoiceCallPhase.idle),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VoiceOrbVisualizer), findsOneWidget);
      expect(find.byKey(const Key('voice_orb_visualizer')), findsOneWidget);
    });

    testWidgets('renders and animates in greeting phase', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceOrbVisualizer(phase: VoiceCallPhase.greeting),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(VoiceOrbVisualizer), findsOneWidget);
    });

    testWidgets('renders in listening phase and responds to animation ticks', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceOrbVisualizer(phase: VoiceCallPhase.listening),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(VoiceOrbVisualizer), findsOneWidget);
    });

    testWidgets('renders in thinking phase', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceOrbVisualizer(phase: VoiceCallPhase.thinking),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(VoiceOrbVisualizer), findsOneWidget);
    });

    testWidgets('renders in speaking phase', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceOrbVisualizer(phase: VoiceCallPhase.speaking),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(VoiceOrbVisualizer), findsOneWidget);
    });

    testWidgets('handles phase transitions cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceOrbVisualizer(phase: VoiceCallPhase.listening),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        createTestWrapper(
          const VoiceOrbVisualizer(phase: VoiceCallPhase.thinking),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        createTestWrapper(
          const VoiceOrbVisualizer(phase: VoiceCallPhase.speaking),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VoiceOrbVisualizer), findsOneWidget);
    });

    testWidgets('renders when isMuted is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceOrbVisualizer(
            phase: VoiceCallPhase.listening,
            isMuted: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VoiceOrbVisualizer), findsOneWidget);
    });
  });

  group('VoiceSubtitleCard Widget', () {
    testWidgets('renders user transcript and assistant speech when visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceSubtitleCard(
            userSpeech: 'Hello Snape, how are you?',
            assistantSpeech: 'I am doing great! Ready to practice?',
            phase: VoiceCallPhase.speaking,
            isVisible: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello Snape, how are you?'), findsOneWidget);
      expect(find.text('I am doing great! Ready to practice?'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Snape'), findsOneWidget);
    });

    testWidgets('displays placeholder hint when speech is empty during listening', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceSubtitleCard(
            userSpeech: '',
            assistantSpeech: '',
            phase: VoiceCallPhase.listening,
            isVisible: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Listening...'), findsOneWidget);
    });

    testWidgets('displays placeholder hint when speech is empty during thinking', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceSubtitleCard(
            userSpeech: '',
            assistantSpeech: '',
            phase: VoiceCallPhase.thinking,
            isVisible: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thinking...'), findsOneWidget);
    });

    testWidgets('hides card when isVisible is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceSubtitleCard(
            userSpeech: 'Hidden transcript',
            assistantSpeech: 'Hidden response',
            phase: VoiceCallPhase.speaking,
            isVisible: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final opacityWidget = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('voice_subtitle_animated_opacity')),
      );
      expect(opacityWidget.opacity, 0.0);
    });

    testWidgets('toggles visibility animatedly when isVisible changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          const VoiceSubtitleCard(
            userSpeech: 'Some transcript',
            assistantSpeech: 'Some response',
            phase: VoiceCallPhase.speaking,
            isVisible: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      var opacityWidget = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('voice_subtitle_animated_opacity')),
      );
      expect(opacityWidget.opacity, 1.0);

      await tester.pumpWidget(
        createTestWrapper(
          const VoiceSubtitleCard(
            userSpeech: 'Some transcript',
            assistantSpeech: 'Some response',
            phase: VoiceCallPhase.speaking,
            isVisible: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      opacityWidget = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('voice_subtitle_animated_opacity')),
      );
      expect(opacityWidget.opacity, 0.0);
    });
  });

  group('VoiceControlBar Widget', () {
    testWidgets('renders all 4 action buttons with default states', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          VoiceControlBar(
            isMuted: false,
            localeId: 'en_US',
            showSubtitles: true,
            onToggleMute: () {},
            onToggleLanguage: () {},
            onToggleSubtitles: () {},
            onEndCall: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voice_control_mute_button')), findsOneWidget);
      expect(find.byKey(const Key('voice_control_language_button')), findsOneWidget);
      expect(find.byKey(const Key('voice_control_subtitles_button')), findsOneWidget);
      expect(find.byKey(const Key('voice_control_end_call_button')), findsOneWidget);

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
      expect(find.byIcon(Icons.subtitles_rounded), findsOneWidget);
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
    });

    testWidgets('displays correct icons and text for muted, Indonesian, and subtitles-off states', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          VoiceControlBar(
            isMuted: true,
            localeId: 'id_ID',
            showSubtitles: false,
            onToggleMute: () {},
            onToggleLanguage: () {},
            onToggleSubtitles: () {},
            onEndCall: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
      expect(find.text('ID'), findsOneWidget);
      expect(find.byIcon(Icons.subtitles_off_rounded), findsOneWidget);
    });

    testWidgets('triggers callbacks when buttons are tapped', (WidgetTester tester) async {
      bool mutedTapped = false;
      bool langTapped = false;
      bool subtitlesTapped = false;
      bool endCallTapped = false;

      await tester.pumpWidget(
        createTestWrapper(
          VoiceControlBar(
            isMuted: false,
            localeId: 'en_US',
            showSubtitles: true,
            onToggleMute: () => mutedTapped = true,
            onToggleLanguage: () => langTapped = true,
            onToggleSubtitles: () => subtitlesTapped = true,
            onEndCall: () => endCallTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('voice_control_mute_button')));
      await tester.pumpAndSettle();
      expect(mutedTapped, isTrue);

      await tester.tap(find.byKey(const Key('voice_control_language_button')));
      await tester.pumpAndSettle();
      expect(langTapped, isTrue);

      await tester.tap(find.byKey(const Key('voice_control_subtitles_button')));
      await tester.pumpAndSettle();
      expect(subtitlesTapped, isTrue);

      await tester.tap(find.byKey(const Key('voice_control_end_call_button')));
      await tester.pumpAndSettle();
      expect(endCallTapped, isTrue);
    });
  });
}
