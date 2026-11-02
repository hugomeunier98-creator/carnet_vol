import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'screens/home_screen.dart';
import 'services/safe_area.dart';
import 'theme/app_theme.dart';

void main() {
  // No browser history entries for in-app screens: otherwise iOS Safari
  // takes the left-edge swipe as its own "back" (showing a blank snapshot
  // of the page while it reloads the previous state). Without history it
  // leaves the swipe to the app, which slides back to the previous screen
  // live, already built underneath.
  setUrlStrategy(null);
  runApp(const CarnetVolApp());
}

class CarnetVolApp extends StatelessWidget {
  const CarnetVolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carnet de vol',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) => _withSafeArea(context, child!),
      home: const HomeScreen(),
    );
  }

  /// The app is drawn under the iPhone status bar and home indicator (see
  /// web/index.html); feeds their heights to Flutter so app bars, sheets
  /// and bottom buttons keep clear of them.
  static Widget _withSafeArea(BuildContext context, Widget child) {
    final (top, bottom) = safeAreaInsets();
    if (top == 0 && bottom == 0) return child;
    final mq = MediaQuery.of(context);
    final viewPadding = mq.viewPadding.copyWith(
      top: max(mq.viewPadding.top, top),
      bottom: max(mq.viewPadding.bottom, bottom),
    );
    return MediaQuery(
      data: mq.copyWith(
        viewPadding: viewPadding,
        padding: mq.padding.copyWith(
          top: viewPadding.top,
          // The keyboard covers the home indicator.
          bottom: max(0, viewPadding.bottom - mq.viewInsets.bottom),
        ),
      ),
      child: child,
    );
  }
}
