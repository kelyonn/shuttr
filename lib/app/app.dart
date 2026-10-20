import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shuttr/app/router.dart';
import 'package:shuttr/app/theme.dart';

class ShuttrApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Shuttr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'IBMPlexMono',
        scaffoldBackgroundColor: Palette.paper,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: Palette.ink,
              surface: Palette.paper,
            ).copyWith(
              primary: Palette.ink,
              onPrimary: Palette.paper,
              onSurface: Palette.ink,
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Palette.paper,
          foregroundColor: Palette.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.ink,
          contentTextStyle: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: 12,
            letterSpacing: 0.6,
            color: Palette.cream,
          ),
          shape: RoundedRectangleBorder(),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Palette.paper,
          shape: RoundedRectangleBorder(side: BorderSide(color: Palette.ink)),
          titleTextStyle: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.3,
            color: Palette.ink,
          ),
          contentTextStyle: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: 12,
            height: 1.35,
            color: Palette.ink,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Palette.ink,
            minimumSize: const Size(48, 48),
            shape: const RoundedRectangleBorder(),
            textStyle: const TextStyle(
              fontFamily: 'IBMPlexMono',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Palette.ink,
            foregroundColor: Palette.paper,
            minimumSize: const Size(48, 48),
            shape: const RoundedRectangleBorder(),
            textStyle: const TextStyle(
              fontFamily: 'IBMPlexMono',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Palette.paper,
          shape: RoundedRectangleBorder(),
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
