import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../database/db_helper.dart';

class ExcelExporter {
  static Future<String> exportLearningNeeds(String? selectedLearningNeed,
      {String? selectedYear,
      String? selectedQuarter,
      String? selectedOffice}) async {
    final Workbook workbook = Workbook();
    String fileName = "Learning_Need_Summary";

    // Remove default sheet
    workbook.worksheets.clear();

    // Build file name based on selected filters
    if (selectedOffice != null && selectedLearningNeed == "All") {
      fileName = "${selectedOffice}_Learning_Need_Summary";
      if (selectedYear != null) {
        fileName += " $selectedYear";
      }
      if (selectedQuarter != null) {
        fileName += " $selectedQuarter"; // ✅ FIXED
      }
    } else if (selectedLearningNeed != "All") {
      fileName = "${selectedLearningNeed}_Summary";
      if (selectedYear != null) {
        fileName += " $selectedYear";
      }
      if (selectedQuarter != null) {
        fileName += " $selectedQuarter"; // ✅ FIXED
      }
    }

    if (selectedLearningNeed == "All") {
      List<String> allLearningNeeds = await DBHelper.getUniqueLearningNeeds();

      for (int i = 0; i < allLearningNeeds.length; i++) {
        String currentNeed = allLearningNeeds[i];

        // Fetch filtered data per learning need, year, quarter, and office
        List<Map<String, dynamic>> needData =
            await DBHelper.getEmployeesByLearningNeed(
          currentNeed,
          year: selectedYear,
          quarter: selectedQuarter,
          office: selectedOffice, // Added filtering by office
        );

        // Only create a sheet if there's data for this need
        if (needData.isNotEmpty) {
          String sheetName =
              currentNeed.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '_');
          if (sheetName.isEmpty) sheetName = 'Sheet${i + 1}';
          final Worksheet ws = workbook.worksheets.addWithName(sheetName);
          _fillSheet(ws, needData, currentNeed);
        }
      }
    } else {
      // Filter for one learning need with year, quarter, and office
      List<Map<String, dynamic>> data =
          await DBHelper.getEmployeesByLearningNeed(
        selectedLearningNeed!,
        year: selectedYear,
        quarter: selectedQuarter,
        office: selectedOffice, // Added filtering by office
      );

      String sheetName =
          selectedLearningNeed.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '_');
      if (sheetName.isEmpty) sheetName = 'Sheet1';
      final Worksheet sheet = workbook.worksheets.addWithName(sheetName);
      _fillSheet(sheet, data, selectedLearningNeed);
      fileName = "${sheetName}_Summary";
    }

    final List<int> bytes = workbook.saveAsStream();
    final directory = await getApplicationDocumentsDirectory();

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    String path = '${directory.path}/$fileName.xlsx';
    int fileIndex = 1;
    while (await File(path).exists()) {
      path = '${directory.path}/$fileName' + '_$fileIndex.xlsx';
      fileIndex++;
    }

    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    workbook.dispose();

    return path; // Return the file path
  }

  static String formatMiddleInitial(dynamic mi) {
    if (mi == null) return '';
    String trimmed = mi.toString().trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('.') ? trimmed : '$trimmed.';
  }

  static void _fillSheet(
      Worksheet sheet, List<Map<String, dynamic>> data, String learningNeed) {
    // Convert read-only list to a modifiable one
    List<Map<String, dynamic>> modifiableData =
        List<Map<String, dynamic>>.from(data);

    // Sort data first by Target Schedule, then by Basis Learning, then Proposed Action
    modifiableData.sort((a, b) {
      int scheduleCompare = _parseTargetSchedule(a['Target_Schedule'])
          .compareTo(_parseTargetSchedule(b['Target_Schedule']));
      if (scheduleCompare != 0) return scheduleCompare;

      String basisA = a['Basis_Learning']?.toString() ?? '';
      String basisB = b['Basis_Learning']?.toString() ?? '';
      int basisCompare = basisA.compareTo(basisB);
      if (basisCompare != 0) return basisCompare;

      String actionA = a['Proposed_Action']?.toString() ?? '';
      String actionB = b['Proposed_Action']?.toString() ?? '';
      return actionA.compareTo(actionB);
    });

    sheet.getRangeByName('A1').setText('Learning Need: $learningNeed');
    sheet.getRangeByName('A1').cellStyle.bold = true;
    sheet.getRangeByName('A1').cellStyle.fontSize = 14;

    sheet.getRangeByName('A2').setText('No.');
    sheet.getRangeByName('A2').cellStyle.bold = true;
    sheet.getRangeByName('B2').setText('Full Name');
    sheet.getRangeByName('B2').cellStyle.bold = true;
    sheet.getRangeByName('C2').setText('Office');
    sheet.getRangeByName('C2').cellStyle.bold = true;
    sheet.getRangeByName('D2').setText('Position');
    sheet.getRangeByName('D2').cellStyle.bold = true;
    sheet.getRangeByName('E2').setText('Learning Need');
    sheet.getRangeByName('E2').cellStyle.bold = true;
    sheet.getRangeByName('F2').setText('Basis Learning');
    sheet.getRangeByName('F2').cellStyle.bold = true;
    sheet.getRangeByName('G2').setText('Proposed Action');
    sheet.getRangeByName('G2').cellStyle.bold = true;
    sheet.getRangeByName('H2').setText('Target Schedule');
    sheet.getRangeByName('H2').cellStyle.bold = true;

    for (int i = 0; i < modifiableData.length; i++) {
      final row = modifiableData[i];
      sheet.getRangeByIndex(i + 3, 1).setNumber(i + 1); // No. column

      final firstName = row['First_Name'] ?? '';
      final middleInitial = row['Middle_Initial'];
      final lastName = row['Last_Name'] ?? '';
      final fullName =
          '${firstName} ${formatMiddleInitial(middleInitial)} ${lastName}'
              .trim();
      sheet.getRangeByIndex(i + 3, 2).setText(fullName);

      sheet.getRangeByIndex(i + 3, 3).setText(row['Office'] ?? '');
      sheet.getRangeByIndex(i + 3, 4).setText(row['Position'] ?? '');
      sheet.getRangeByIndex(i + 3, 5).setText(row['Learning_Needs'] ?? '');
      sheet.getRangeByIndex(i + 3, 6).setText(row['Basis_Learning'] ?? '');
      sheet.getRangeByIndex(i + 3, 7).setText(row['Proposed_Action'] ?? '');
      sheet.getRangeByIndex(i + 3, 8).setText(row['Target_Schedule'] ?? '');
    }

    sheet.getRangeByIndex(1, 1).columnWidth = 8; // No.
    sheet.getRangeByIndex(1, 2).columnWidth = 25; // Full Name
    sheet.getRangeByIndex(1, 3).columnWidth = 30; // Office
    sheet.getRangeByIndex(1, 4).columnWidth = 30; // Position
    sheet.getRangeByIndex(1, 5).columnWidth = 40; // Learning Need
    sheet.getRangeByIndex(1, 6).columnWidth = 30; // Basis Learning
    sheet.getRangeByIndex(1, 7).columnWidth = 25; // Proposed Action
    sheet.getRangeByIndex(1, 8).columnWidth = 20; // Target Schedule
  }

  static int _parseTargetSchedule(String? schedule) {
    if (schedule == null || schedule.isEmpty)
      return 9999999; // Last in order if empty

    final match =
        RegExp(r'(\d+)(?:st|nd|rd|th) Quarter of (\d{4})').firstMatch(schedule);
    if (match != null) {
      int quarter = int.tryParse(match.group(1) ?? '0') ?? 0;
      int year = int.tryParse(match.group(2) ?? '0') ?? 0;
      return (year * 10) + quarter; // Ensure proper sorting order
    }

    return 9999999; // Unrecognized format goes to the bottom
  }
}
