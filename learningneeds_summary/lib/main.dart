import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:learningneeds_summary/title_page.dart';
import 'package:learningneeds_summary/database/db_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized

  // Initialize SQLite for Windows
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Initialize database before launching the app
  try {
    await DBHelper.database; // Initialize the database (using static getter)
    print("Main: Database initialized successfully!");

    // Check if the Employee_LearningNeedsView exists after database is initialized
    await checkIfViewExists();
  } catch (e) {
    print("Error initializing database: $e");
    // Display error on UI
    showErrorMessage(e.toString());
  }

  runApp(MyApp());
}

// Function to check if the view exists in the database
Future<void> checkIfViewExists() async {
  final db = await DBHelper.database;
  var result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='view' AND name='Employee_LearningNeedsView';");

  if (result.isNotEmpty) {
    print("View 'Employee_LearningNeedsView' exists.");
  } else {
    print("View 'Employee_LearningNeedsView' does not exist.");
  }
}

void showErrorMessage(String errorMessage) {
  // You can handle showing error messages here globally (e.g. show dialog or Snackbar).
  print("Error: $errorMessage");
  // Or use a global key to show a Snackbar in the main app
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Learning Needs Summary',
      theme: ThemeData(
        primaryColor: const Color.fromARGB(255, 241, 246, 248),
      ),
      home: TitlePage(),
    );
  }
}
