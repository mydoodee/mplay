import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'dart:io';
import 'services/audio_handler.dart';
import 'services/song_provider.dart';
import 'services/equalizer_provider.dart';
import 'services/heartbeat_service.dart';
import 'screens/splash_screen.dart';

// Global audio handler (nullable to prevent LateInitializationError)
MyAudioHandler? audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      // Ignore if not on desktop
    }
  }

  try {
    // Initialize audio handler
    audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ytmusic.channel.audio',
        androidNotificationChannelName: 'YouTube Music Playback',
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/launcher_icon',
      ),
    );
    debugPrint('✅ AudioService initialized successfully');
  } catch (e) {
    debugPrint('⚠️ AudioService init failed: $e');
    // App continues without audio service
  }

  // Initialize HeartbeatService
  HeartbeatService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SongProvider()),
        if (audioHandler != null)
          ChangeNotifierProvider(
            create: (_) => EqualizerProvider(audioHandler!),
            lazy: false, // บังคับให้สร้างและโหลดการตั้งค่าทันทีตอนเริ่มแอป
          ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M-PLAY',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5722), // Deep Orange
          brightness: Brightness.dark,
          surface: Colors.black,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
          fontFamily: 'sans-serif',
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
