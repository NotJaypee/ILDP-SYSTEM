import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../database/db_helper.dart';

class BackupService {
  /// **Export Data to CSV**
  static Future<void> exportToCSV(BuildContext context) async {
    List<Map<String, dynamic>> data =
        await DBHelper.getAllEmployeesWithLearningNeeds();
    List<List<String>> csvData = [
      [
        'Employee_ID',
        'First_Name',
        'Middle_Initial',
        'Last_Name',
        'Office',
        'Position',
        'Learning_Needs',
        'Basis_Learning',
        'Proposed_Action',
        'Target_Schedule'
      ],
      ...data.map((item) => [
            item['Employee_ID'].toString(),
            item['First_Name'] ?? '',
            item['Middle_Initial'] ?? '',
            item['Last_Name'] ?? '',
            item['Office'] ?? '',
            item['Position'] ?? '',
            item['Learning_Needs'] ?? '',
            item['Basis_Learning'] ?? '',
            item['Proposed_Action'] ?? '',
            item['Target_Schedule'] != null &&
                    item['Target_Schedule'].toString().isNotEmpty
                ? item['Target_Schedule']
                    .toString()
                    .padLeft(4, '0') // Ensure 4-digit year
                : '', // Leave empty if null or empty
          ])
    ];

    String csv = const ListToCsvConverter().convert(csvData);
    final dir = await getApplicationDocumentsDirectory();
    String basePath = "${dir.path}/employee_database";
    String filePath = "$basePath.csv";
    int counter = 1;

    // Check if the file already exists, and increment the counter if necessary
    while (await File(filePath).exists()) {
      filePath = "$basePath$counter.csv";
      counter++;
    }

    final file = File(filePath);
    await file.writeAsString(csv);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Export Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your file has been exported to:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  filePath,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('OK'),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> importFromCSV(
      BuildContext context, Function(bool) setLoading) async {
    // Start loading
    setLoading(true);

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      final csvString = await file.readAsString();
      List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(csvString, eol: '\n');

      // Clear all existing records (employees and their learning needs)
      await DBHelper.clearAllEmployeesAndLearningNeeds();

      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];

        // Skip rows with insufficient data
        if (row.length < 10) {
          print("Skipping row $i due to insufficient data");
          continue;
        }

        String targetSchedule =
            row[9]?.toString().trim() ?? ''; // Handle null or empty
        if (targetSchedule.isEmpty) {
          targetSchedule = ''; // If there's no data, keep it empty
        } else if (targetSchedule.length == 3) {
          targetSchedule =
              '20' + targetSchedule; // Adding the century (e.g., 024 -> 2024)
        } else if (targetSchedule.length != 4) {
          targetSchedule =
              targetSchedule.padLeft(4, '0'); // Ensure proper padding
        }

        // Check if the employee already exists
        int? existingEmployeeId = await DBHelper.getEmployeeIdByName(
          row[1], // First Name
          row[3], // Last Name
        );

        int employeeId;

        if (existingEmployeeId != null) {
          // Use the existing Employee_ID
          employeeId = existingEmployeeId;
          print(
              "Found existing employee: ${row[1]} ${row[3]} (ID: $employeeId)");
        } else {
          // Insert the employee (only if not already present)
          employeeId = await DBHelper.insertEmployee({
            'First_Name': row[1],
            'Middle_Initial': row[2],
            'Last_Name': row[3],
            'Office': row[4],
            'Position': row[5],
          });

          if (employeeId > 0) {
            print(
                "Inserted new employee: ${row[1]} ${row[3]} (ID: $employeeId)");
          } else {
            print("Failed to insert employee: ${row[1]} ${row[3]}");
            continue;
          }
        }

        // Insert learning needs for the employee
        await DBHelper.insertLearningNeed({
          'Employee_ID': employeeId,
          'Learning_Needs': row[6],
          'Basis_Learning': row[7],
          'Proposed_Action': row[8],
          'Target_Schedule': targetSchedule,
        });
        print("Inserted learning need for employee $employeeId: ${row[6]}");
      }

      // End loading
      setLoading(false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import successful!')),
      );
    } else {
      // End loading if no file is selected
      setLoading(false);
    }
  }
}
