import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_calendar/screens/calendar_home_screen.dart';
import 'package:ai_calendar/providers/voice_input_provider.dart';
import 'package:ai_calendar/services/audio_recorder_service.dart';
import 'package:ai_calendar/services/asr_service.dart';
import 'package:ai_calendar/services/nlu_service.dart';
import 'package:ai_calendar/services/calendar_db_service.dart';

void main() {
  late CalendarDbService db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = CalendarDbService();
    await db.init(inMemory: true);
  });

  tearDown(() async => await db.close());

  Widget buildApp() {
    return ChangeNotifierProvider(
      create: (_) => VoiceInputProvider(
        recorder: MockAudioRecorderService(),
        asr: MockAsrService(),
        nlu: MockNluService(),
        db: db,
      ),
      child: const MaterialApp(home: CalendarHomeScreen()),
    );
  }

  group('CalendarHomeScreen', () {
    testWidgets('displays month title', (tester) async {
      await tester.pumpWidget(buildApp());
      expect(find.textContaining('月'), findsOneWidget);
    });

    testWidgets('displays weekday headers', (tester) async {
      await tester.pumpWidget(buildApp());
      for (final d in ['一', '二', '三', '四', '五', '六', '日']) {
        expect(find.text(d), findsOneWidget);
      }
    });

    testWidgets('displays day cells', (tester) async {
      await tester.pumpWidget(buildApp());
      expect(find.byKey(const Key('day-cell-bg')), findsNWidgets(7));
    });

    testWidgets('starts with loading or empty state', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // Either loading or empty state should be visible
      final hasEmpty = find.text('暂无事项').evaluate().isNotEmpty;
      final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      expect(hasEmpty || hasLoading, true);
    });

    testWidgets('displays bottom action bar', (tester) async {
      await tester.pumpWidget(buildApp());
      expect(find.byKey(const Key('btn-keyboard')), findsOneWidget);
      expect(find.byKey(const Key('btn-voice')), findsOneWidget);
      expect(find.byKey(const Key('btn-calendar')), findsOneWidget);
    });

    testWidgets('has correct background color', (tester) async {
      await tester.pumpWidget(buildApp());
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFF8FBFF));
    });
  });
}
