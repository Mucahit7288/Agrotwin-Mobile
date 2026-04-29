// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

const Color kGreen = Color(0xFF11994B);
const Color kGreenLight = Color(0xFF2DBE6C);
const Color kGreenDark = Color(0xFF0D7A3A);
const Color kBg = Color(0xFFF5F6FA);
const Color kCard = Colors.white;
const Color kTextPrimary = Color(0xFF1A2340);
const Color kTextSecondary = Color(0xFF6B7280);
const Color kRed = Color(0xFFEF4444);
const Color kOrange = Color(0xFFF97316);
const Color kBlue = Color(0xFF3B82F6);
const Color kCyan = Color(0xFF06B6D4);
const Color kAmber = Color(0xFFF59E0B);
const double kRadius = 16.0;

const String kAssetLogoWord = 'assets/logo_word_clean.png';
const String kAssetLogoSymbol = 'assets/icon.png';

const double kLogoSymbolLogin = 160.0; // Giriş ekranı sembol (büyütüldü)
const double kLogoWordLogin = 72.0; // Giriş ekranı yazı logosu (büyütüldü)
const double kLogoSymbolAppBar = 56.0; // Dashboard AppBar sembol  (eski: 42)
const double kLogoWordAppBar = 40.0; // Dashboard AppBar yazı    (eski: 30)
const double kLogoWordAiBar = 44.0; // AI Asistan AppBar yazı   (eski: 34)

BoxDecoration get kCardDecoration => BoxDecoration(
  color: kCard,
  borderRadius: BorderRadius.circular(kRadius),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);

ThemeData buildAppTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: kGreen,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: kBg,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    },
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    foregroundColor: kTextPrimary,
    titleTextStyle: TextStyle(
      color: kTextPrimary,
      fontWeight: FontWeight.w700,
      fontSize: 20,
    ),
  ),
);
