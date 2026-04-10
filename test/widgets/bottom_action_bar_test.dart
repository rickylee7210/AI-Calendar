import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/widgets/bottom_action_bar.dart';

void main() {
  group('BottomActionBar', () {
    testWidgets('should display three action buttons', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BottomActionBar(
            onKeyboardTap: () {},
            onVoiceTap: () {},
            onCalendarTap: () {},
          ),
        ),
      ));

      expect(find.byKey(const Key('btn-keyboard')), findsOneWidget);
      expect(find.byKey(const Key('btn-voice')), findsOneWidget);
      expect(find.byKey(const Key('btn-calendar')), findsOneWidget);
    });

    testWidgets('voice button should be wider than others', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BottomActionBar(
            onKeyboardTap: () {},
            onVoiceTap: () {},
            onCalendarTap: () {},
          ),
        ),
      ));

      final voiceBtn = tester.getSize(find.byKey(const Key('btn-voice')));
      final keyboardBtn = tester.getSize(find.byKey(const Key('btn-keyboard')));
      expect(voiceBtn.width, greaterThan(keyboardBtn.width));
    });

    testWidgets('should call onVoiceTap when voice button tapped',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BottomActionBar(
            onKeyboardTap: () {},
            onVoiceTap: () => tapped = true,
            onCalendarTap: () {},
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('btn-voice')));
      expect(tapped, true);
    });

    testWidgets('should call onKeyboardTap when keyboard button tapped',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BottomActionBar(
            onKeyboardTap: () => tapped = true,
            onVoiceTap: () {},
            onCalendarTap: () {},
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('btn-keyboard')));
      expect(tapped, true);
    });
  });
}
