// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:learningneeds_summary/utils/excel_exporter.dart';
import 'package:learningneeds_summary/title_page.dart';
import 'input_page.dart';
import 'package:learningneeds_summary/table_page.dart';
import '../database/db_helper.dart';

class GeneratePage extends StatefulWidget {
  @override
  _GeneratePageState createState() => _GeneratePageState();
}

class _GeneratePageState extends State<GeneratePage> {
  bool isSearchIconPressed = false; // Flag to prevent autocomplete
  String? selectedLearningNeed;
  String? selectedOffice;
  String? selectedYear;
  String? selectedQuarter;
  bool isLoading = false;
  bool isTableVisible = false;
  List<Map<String, dynamic>> _data = [];
  List<String> learningNeeds = ['All', 'None'];
  List<String> offices = ['All', 'None'];
  List<String> years = ['All'];
  List<String> quarters = ['All'];
  TextEditingController searchController = TextEditingController();
  FocusNode fcuosNode = FocusNode();
  String selectedPage = 'Generate Report';

  void _onPageSelected(String page) {
    setState(() {
      selectedPage = page;
    });
  }

  Future<void> _fetchYearsAndQuarters() async {
    List<String> fetchedYears = await DBHelper.getDistinctYears();
    List<String> fetchedQuarters = await DBHelper.getDistinctQuarters();

    setState(() {
      // Add the dynamic data to the existing lists
      years.addAll(fetchedYears);
      quarters.addAll(fetchedQuarters);
      print("Fetched Years: $years"); // Debugging
      print("Fetched Quarters: $quarters"); // Debugging
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchYearsAndQuarters();
    _fetchLearningNeeds();
    _fetchOffices();
  }

  Future<void> _fetchLearningNeeds() async {
    List<String> fetchedNeeds = await DBHelper.getUniqueLearningNeeds();
    fetchedNeeds.sort();
    setState(() {
      learningNeeds = ['All', ...fetchedNeeds];
    });
  }

  Future<void> _fetchOffices() async {
    List<String> fetchedOffices = await DBHelper.getUniqueOffices();
    fetchedOffices.sort();
    setState(() {
      offices = ['All', ...fetchedOffices];
    });
  }

  Future<void> _fetchAllData() async {
    if (selectedLearningNeed == null || selectedLearningNeed!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a learning need!')),
      );
      return;
    }

    setState(() => isLoading = true);

    List<Map<String, dynamic>> fetchedData;

    // Fetch data based on filters
    if (selectedLearningNeed == 'All' && selectedOffice == 'All') {
      // Fetch all learning needs and all offices
      fetchedData = await DBHelper.getAllEmployeesWithLearningNeeds();
    } else if (selectedLearningNeed == 'All' &&
        selectedOffice != 'None' &&
        selectedOffice != null) {
      // Fetch all learning needs, but filter by selected office
      fetchedData =
          await DBHelper.getEmployeesByOfficeWithLearningNeeds(selectedOffice!);
    } else if (selectedLearningNeed != 'None' && selectedOffice == 'All') {
      // Fetch data based on learning need only
      fetchedData =
          await DBHelper.getEmployeesByLearningNeedOnly(selectedLearningNeed!);
    } else if (selectedLearningNeed != 'None' &&
        selectedOffice != 'None' &&
        selectedOffice != null) {
      // Fetch data based on both learning need and selected office
      fetchedData = await DBHelper.getEmployeesByLearningNeedAndOffice(
          selectedLearningNeed!, selectedOffice!);
    } else {
      fetchedData = [];
    }

    // Processing data to extract year and quarter from 'Target_Schedule'
    fetchedData = fetchedData.map((item) {
      String targetSchedule = item['Target_Schedule'] ?? '';

      // Extract year (last 4 characters)
      String extractedYear = targetSchedule.length >= 4
          ? targetSchedule.substring(targetSchedule.length - 4)
          : 'Unknown';

      // Extract quarter (supports both "Q1 YYYY" and "1st Quarter of YYYY")
      RegExp quarterRegExp =
          RegExp(r'([1-4])(st|nd|rd|th)? Quarter|Q([1-4]) (\d{4})');
      Match? match = quarterRegExp.firstMatch(targetSchedule);

      String extractedQuarter = 'Unknown';
      if (match != null) {
        String quarterNumber = match.group(1) ?? match.group(3) ?? 'Unknown';

        // Convert "1" to "1st", "2" to "2nd", etc.
        Map<String, String> suffixes = {
          '1': 'st',
          '2': 'nd',
          '3': 'rd',
          '4': 'th'
        };
        extractedQuarter = '$quarterNumber${suffixes[quarterNumber]} Quarter';
      }

      return {
        ...item,
        'Year': extractedYear,
        'Quarter': extractedQuarter, // Matches your dropdown format
      };
    }).toList();

    // Apply year filter if selected
    if (selectedYear != null && selectedYear != 'All') {
      fetchedData =
          fetchedData.where((item) => item['Year'] == selectedYear).toList();
    }

    // Apply quarter filter if selected
    if (selectedQuarter != null && selectedQuarter != 'All') {
      fetchedData = fetchedData
          .where((item) => item['Quarter'] == selectedQuarter)
          .toList();
    }

    setState(() {
      _data = fetchedData;
      isTableVisible = _data.isNotEmpty;
      isLoading = false;
    });

    // Display message if no data is found
    if (_data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No records found for the selected filters.')),
      );
    }
  }

  // Generate Report as Excel File
  Future<void> _generateReport() async {
    if (selectedLearningNeed == null || selectedLearningNeed!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No learning need selected!')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Call exportLearningNeeds and get the file path
      String filePath = await ExcelExporter.exportLearningNeeds(
        selectedLearningNeed,
        selectedYear: selectedYear,
        selectedQuarter: selectedQuarter,
        selectedOffice: selectedOffice, // Ensure selectedOffice is passed here
      );

      if (mounted) {
        // Show the file path in a dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor:
                  Colors.white, // Set background color of the dialog
              title: const Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.green), // Success icon
                  SizedBox(width: 8),
                  Text(
                    'File Generated',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Excel file generated successfully!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'File path:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      filePath, // Display file path here
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blueAccent,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print("Error during export: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate Excel file.')),
        );
      }
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Row(children: [
          // Sidebar
          Container(
            width: 135,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 241, 246, 248),
              border: Border(right: BorderSide(color: Colors.white, width: 3)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 30),
                Image.asset(
                  'assets/pgp_logo.png',
                  height: 85,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 30),
                _buildSidebarItem(
                  icon: Icons.home,
                  label: 'Home',
                  page: TitlePage(),
                  pageKey: 'Home',
                ),
                _buildSidebarItem(
                  icon: Icons.input,
                  label: 'Input Data',
                  page: InputPage(),
                  pageKey: 'Input Data',
                ),
                _buildSidebarItem(
                  icon: Icons.description,
                  label: 'Generate Report',
                  page: GeneratePage(),
                  pageKey: 'Generate Report',
                ),
                _buildSidebarItem(
                  icon: Icons.table_chart,
                  label: 'View Table',
                  page: TablePage(),
                  pageKey: 'View Table',
                ),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment
                  .topCenter, // <-- This pins the scroll content to top
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    // Section Title
                    const Padding(
                      padding: EdgeInsets.only(left: 1.0, top: 1.0),
                      child: Text(
                        "📄Generate Learning Needs Summary",
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment
                              .start, // Align content to start
                          children: [
                            const Text(
                              'Select Filters for Exporting Learning Needs',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Autocomplete<String>(
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                // If search icon is pressed, don't show autocomplete
                                if (isSearchIconPressed) {
                                  return const Iterable<String>.empty();
                                }

                                // If nothing is typed, return the full list of learning needs
                                if (textEditingValue.text.isEmpty) {
                                  return learningNeeds;
                                }

                                // Otherwise, filter based on the text entered
                                return learningNeeds.where((option) => option
                                    .toLowerCase()
                                    .contains(
                                        textEditingValue.text.toLowerCase()));
                              },
                              onSelected: (String selection) {
                                setState(() {
                                  selectedLearningNeed = selection;
                                  searchController.text = selection;
                                });
                              },
                              fieldViewBuilder: (BuildContext context,
                                  TextEditingController
                                      fieldTextEditingController,
                                  FocusNode fieldFocusNode,
                                  VoidCallback onFieldSubmitted) {
                                // Save the controller to update its text later
                                searchController = fieldTextEditingController;
                                return TextField(
                                  controller: fieldTextEditingController,
                                  focusNode: fieldFocusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Search Learning Need',
                                    border: const OutlineInputBorder(),
                                    // Suffix icon that shows a dropdown of all options when tapped
                                    suffixIcon: Tooltip(
                                      message: 'Search for Learning Need',
                                      child: IconButton(
                                        icon: const Icon(Icons.search),
                                        onPressed: () async {
                                          setState(() {
                                            isSearchIconPressed = true;
                                          });

                                          // Hide the keyboard
                                          FocusScope.of(context).unfocus();

                                          // Get the current position of the field
                                          final RenderBox renderBox = context
                                              .findRenderObject() as RenderBox;
                                          final Offset offset = renderBox
                                              .localToGlobal(Offset.zero);

                                          // Show a popup menu with a customized width and height
                                          final String? selection =
                                              await showMenu<String>(
                                            context: context,
                                            position: RelativeRect.fromLTRB(
                                              offset.dx +
                                                  renderBox.size.width -
                                                  50, // Adjust to position it on the right
                                              offset.dy + renderBox.size.height,
                                              offset.dx,
                                              offset.dy,
                                            ),
                                            items: learningNeeds
                                                .map((String option) {
                                              return PopupMenuItem<String>(
                                                value: option,
                                                child: Container(
                                                  width:
                                                      250, // Custom width for the dropdown
                                                  height:
                                                      60, // Custom height for the menu items
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 8.0,
                                                        horizontal: 10.0),
                                                    child: Text(option),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          );

                                          if (selection != null) {
                                            setState(() {
                                              selectedLearningNeed = selection;
                                              fieldTextEditingController.text =
                                                  selection;
                                            });
                                          }

                                          // Reset the flag after the search is complete
                                          setState(() {
                                            isSearchIconPressed = false;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Office Dropdown
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedOffice == null ||
                                            selectedOffice == 'Select an Office'
                                        ? 'Select an Office'
                                        : selectedOffice,
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        selectedOffice = newValue;
                                      });
                                    },
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: 'Select an Office',
                                        child: Text(
                                          'Select an Office',
                                          style: TextStyle(
                                              fontWeight: FontWeight.normal),
                                        ),
                                      ),
                                      ...offices.map<DropdownMenuItem<String>>(
                                          (String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(
                                            value,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.normal),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Office',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                    width: 10), // Spacing between dropdowns

                                // Year Dropdown
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedYear,
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        selectedYear = newValue;
                                      });
                                    },
                                    items: years.map<DropdownMenuItem<String>>(
                                        (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    decoration: const InputDecoration(
                                      labelText: 'Year',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Quarter Dropdown
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedQuarter,
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        selectedQuarter = newValue;
                                      });
                                    },
                                    items: quarters
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    decoration: const InputDecoration(
                                      labelText: 'Quarter',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                SizedBox(
                                  width: 200,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _fetchAllData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(
                                          255, 40, 91, 167),
                                      foregroundColor: Colors.white,
                                      elevation: 6,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Show Data'),
                                  ),
                                ),
                                SizedBox(
                                  width: 200,
                                  child: ElevatedButton(
                                    onPressed:
                                        isLoading ? null : _generateReport,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(
                                          255, 40, 91, 167), // Consistent blue
                                      foregroundColor:
                                          Colors.white, // Text color
                                      elevation: 6,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Generate Excel File'),
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isTableVisible)
                      SizedBox(
                        height: 400,
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.black),
                                onPressed: () {
                                  setState(() {
                                    isTableVisible = false;
                                  });
                                },
                              ),
                            ),
                            Flexible(
                              child: _buildScrollableDataTable(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
        ]));
  }

  Widget _buildScrollableDataTable() {
    return Card(
      elevation: 4, // Add shadow to the card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // Rounded corners for the card
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Padding inside the card
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columnSpacing: 15,
              border: TableBorder.all(color: Colors.grey.shade300),
              columns: [
                const DataColumn(label: Text('First Name')),
                const DataColumn(label: Text('Last Name')),
                const DataColumn(label: Text('Office')),
                const DataColumn(label: Text('Learning Need')),
                const DataColumn(label: Text('Basis Learning')),
                const DataColumn(label: Text('Proposed Action')),
                const DataColumn(label: Text('Target Schedule')),
              ],
              rows: _data.map((item) {
                return DataRow(cells: [
                  DataCell(Text(item['First_Name'] ?? '-')),
                  DataCell(Text(item['Last_Name'] ?? '-')),
                  DataCell(Text(item['Office'] ?? '-')),
                  DataCell(
                    SizedBox(
                      width: 200, // Adjust width as needed
                      child: Text(
                        item['Learning_Needs'] ?? '-',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 150, // Adjust width as needed
                      child: Text(
                        item['Basis_Learning'] ?? '-',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 150, // Adjust width as needed
                      child: Text(
                        item['Proposed_Action'] ?? '-',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                  DataCell(Text(item['Target_Schedule'] ?? '-')),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required Widget page,
    required String pageKey,
  }) {
    final bool isSelected = selectedPage == pageKey;
    return GestureDetector(
      onTap: () {
        _onPageSelected(pageKey);
        if (!isSelected) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        }
      },
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color.fromARGB(255, 193, 211, 228)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 17),
            child: Icon(
              icon,
              color: isSelected ? Colors.black : Colors.black54,
              size: 25,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black : Colors.black54,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
