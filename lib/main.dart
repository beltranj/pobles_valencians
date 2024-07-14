import 'package:flutter/cupertino.dart';
import 'mapscreen.dart'; // Import the mapScreen class

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
      const CupertinoThemeData customTheme = CupertinoThemeData(
      primaryColor: CupertinoColors.activeGreen, // Color principal
      barBackgroundColor: CupertinoColors.systemGreen, // Fondo de la barra
      scaffoldBackgroundColor: CupertinoColors.systemGrey6, // Fondo del scaffold
      textTheme: CupertinoTextThemeData(
        primaryColor: CupertinoColors.activeGreen, // Color del texto principal
        textStyle: TextStyle(
          color: CupertinoColors.activeGreen,
        ),
        navActionTextStyle: TextStyle(
          color: CupertinoColors.activeGreen,
        ),
        tabLabelTextStyle: TextStyle(
          color: CupertinoColors.systemGreen,
        ),
        actionTextStyle: TextStyle(
          color: CupertinoColors.systemGreen,
        ),
      ),
    );
    return const CupertinoApp(
      theme: customTheme,
      home: MapScreen(), // Use the mapScreen class as the home screen
      );
  }
}