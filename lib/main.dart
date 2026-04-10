import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/voice_input_provider.dart';
import 'services/real_audio_recorder_service.dart';
import 'services/zhipu_asr_service.dart';
import 'services/zhipu_nlu_service.dart';
import 'services/calendar_db_service.dart';
import 'screens/calendar_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  final db = CalendarDbService();
  await db.init();

  // ASR: 智谱（支持音频输入）
  const zhipuKey = '84a93fd3afdd48fb8cc6780c16374ff1.KUHRgnNuXAH9v6ej';
  final asr = ZhipuAsrService(apiKey: zhipuKey);

  // NLU: 智谱 GLM-4-flash（快速，免费）
  final nlu = ZhipuNluService(apiKey: zhipuKey);

  runApp(
    ChangeNotifierProvider(
      create: (_) => VoiceInputProvider(
        recorder: RealAudioRecorderService(),
        asr: asr,
        nlu: nlu,
        db: db,
      ),
      child: const CalendarApp(),
    ),
  );
}

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI日历',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        fontFamily: 'MiSans',
      ),
      home: const CalendarHomeScreen(),
    );
  }
}
