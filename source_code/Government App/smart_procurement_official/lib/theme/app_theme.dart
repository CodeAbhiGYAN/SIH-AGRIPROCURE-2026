
import 'package:flutter/material.dart';
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3:true,
    colorSchemeSeed:Colors.green,
    scaffoldBackgroundColor:const Color(0xFFF7FAF7),
    cardTheme:const CardThemeData(
      elevation:0, margin:EdgeInsets.zero,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(18))),
    ),
    inputDecorationTheme:const InputDecorationTheme(
      border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(14))),
    ),
  );
}
