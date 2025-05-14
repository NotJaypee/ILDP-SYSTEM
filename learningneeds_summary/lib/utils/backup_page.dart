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
          title: const Row(
            children: [
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

  static Future<void> updateFromCSV(
      BuildContext context, Function(bool) setLoading) async {
    Set<String> employeesAdded = {};
    Set<String> employeesSkipped = {};
    int learningNeedsAdded = 0; // Declare it here

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

      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];

        if (row.length < 10) {
          print("Skipping row $i due to insufficient data");
          continue;
        }

        String targetSchedule = row[9]?.toString().trim() ?? '';
        if (targetSchedule.isEmpty) {
          targetSchedule = '';
        } else if (targetSchedule.length == 3) {
          targetSchedule = '20$targetSchedule';
        } else if (targetSchedule.length != 4) {
          targetSchedule = targetSchedule.padLeft(4, '0');
        }

        String firstName = row[1].toString();
        String middleInitial = row[2].toString();
        String lastName = row[3].toString();
        String fullName = '$firstName $middleInitial $lastName';

        // Check if employee exists
        int? existingEmployeeId = await DBHelper.getEmployeeIdByName(
          firstName,
          lastName,
        );

        int employeeId;

        if (existingEmployeeId != null) {
          employeeId = existingEmployeeId;
          employeesSkipped.add(fullName);
          print("Found existing employee: $fullName (ID: $employeeId)");
        } else {
          employeeId = await DBHelper.insertEmployee({
            'First_Name': firstName,
            'Middle_Initial': middleInitial,
            'Last_Name': lastName,
            'Office': row[4],
            'Position': row[5],
          });

          if (employeeId > 0) {
            employeesAdded.add(fullName);
            print("Inserted new employee: $fullName (ID: $employeeId)");
          } else {
            print("Failed to insert employee: $fullName");
            continue;
          }
        }

        // Check if learning need exists
        bool exists = await DBHelper.learningNeedExists(
          employeeId,
          row[6],
          row[7],
          row[8],
          targetSchedule,
        );
        // Add this before the for loop

        if (!exists) {
          await DBHelper.insertLearningNeed({
            'Employee_ID': employeeId,
            'Learning_Needs': row[6],
            'Basis_Learning': row[7],
            'Proposed_Action': row[8],
            'Target_Schedule': targetSchedule,
          });

          learningNeedsAdded++; // ✅ Increment counter
          print("Inserted new learning need for employee $employeeId");
        } else {
          print("Skipped existing learning need for employee $employeeId");
        }
      }

      // End loading
      setLoading(false);

      // Show summary in dialog after a small delay to ensure the loading finishes
      Future.delayed(const Duration(milliseconds: 200), () {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 30),
                  SizedBox(width: 12),
                  Text(
                    'Update Complete',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: 430, // Wider dialog
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '👥 Employees Added: ${employeesAdded.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '📄 Already Existing Employees: ${employeesSkipped.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '📝 Learning Needs Added: $learningNeedsAdded',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.all(0),
            );
          },
        );
      });
    } else {
      // End loading if no file selected
      setLoading(false);
    }
  }
}
