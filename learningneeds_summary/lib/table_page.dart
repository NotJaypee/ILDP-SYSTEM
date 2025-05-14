import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import 'package:learningneeds_summary/screens/input_page.dart';
import 'package:learningneeds_summary/screens/generate_page.dart';
import 'package:learningneeds_summary/screens/edit_employee_page.dart';
import 'title_page.dart';
import 'package:learningneeds_summary/utils/backup_page.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class TablePage extends StatefulWidget {
  @override
  _TablePageState createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  List<Map<String, dynamic>> _filteredData = [];
  List<Map<String, dynamic>> _originalData =
      []; // Initialize _originalData here
  TextEditingController _searchController = TextEditingController();

  String selectedPage = 'View Table';
  String _selectedOffice = 'All';
  String _selectedTargetSchedule = 'All'; // Initial value is 'All'
  String _selectedLearningNeed = 'All';

  void _onPageSelected(String page) {
    setState(() {
      selectedPage = page;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final List<Map<String, dynamic>> data =
        await DBHelper.getAllEmployeesWithLearningNeeds();
    setState(() {
      _filteredData = data;
      _originalData = List.from(data); // Store a copy of the original data
    });
  }

  // Updated search function to search differently for employees and learning needs

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          // ✅ Added this
          child: Container(
            padding: const EdgeInsets.all(20),
            width: 250,
            // ✅ Remove fixed height
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // ✅ Makes dialog height flexible
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Importing Data...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Please wait while the data is being imported.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show edit popup and refresh the data when the update is confirmed
  void _showEditPopup(Map<String, dynamic> employee) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          insetPadding: const EdgeInsets.all(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: EditEmployeePage(
              employee: employee,
              onUpdate: () async {
                await _fetchData();
                setState(() {}); // Update UI immediately
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style to prevent blue tint
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:
          Colors.transparent, // Ensures the status bar is transparent
      statusBarIconBrightness:
          Brightness.dark, // Use dark icons on the status bar
    ));
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Row(
        children: [
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

          // Main Content Area
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
                    const Text(
                      '📊Employee Learning Needs Table',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search Employee or Learning Needs',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (query) {
                        _applyFilters(
                            query); // Apply filters and search together
                      },
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: _filteredData.isEmpty
                          ? const Text('No Data Available')
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildDataTable(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Floating Buttons for Import/Export
      floatingActionButton: SpeedDial(
        icon: Icons.more_vert, // three-dot icon
        activeIcon: Icons.close,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        tooltip: 'Options',
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        spacing: 12,
        spaceBetweenChildren: 8,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.download),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            label: 'Export Database to CSV',
            onTap: () async {
              await BackupService.exportToCSV(context);
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.system_update),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            label: 'Update Database from CSV',
            onTap: () async {
              _showLoadingDialog();

              await BackupService.updateFromCSV(context, (isLoading) {});
              await _fetchData();

              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
        ],
      ),
    );
  }

  int _currentPage = 0;
  final int _rowsPerPage = 20;

  Widget _buildDataTable() {
    // Sort the filtered data by Employee_ID in descending order
    List<Map<String, dynamic>> sortedData = List.from(_filteredData);
    sortedData.sort(
        (a, b) => (b['Employee_ID'] ?? 0).compareTo(a['Employee_ID'] ?? 0));

    // Group data by Employee Name
    Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (var item in sortedData) {
      String key =
          "${item['First_Name']} ${item['Middle_Initial']} ${item['Last_Name']}";
      groupedData.putIfAbsent(key, () => []).add(item);
    }

    // Convert groupedData to list of entries for pagination
    List<MapEntry<String, List<Map<String, dynamic>>>> groupedEntries =
        groupedData.entries.toList();

    // Pagination: calculate total pages
    int totalPages = (groupedEntries.length / _rowsPerPage).ceil();
    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = (_currentPage + 1) * _rowsPerPage;
    endIndex =
        endIndex > groupedEntries.length ? groupedEntries.length : endIndex;

    // Slice the grouped entries for the current page
    List<MapEntry<String, List<Map<String, dynamic>>>> pagedEntries =
        groupedEntries.sublist(startIndex, endIndex);

    // Generate rows
    List<DataRow> rows = [];
    for (var entry in pagedEntries) {
      String employeeName = entry.key;
      List<Map<String, dynamic>> learningNeedsList = entry.value;

      for (int i = 0; i < learningNeedsList.length; i++) {
        Map<String, dynamic> item = learningNeedsList[i];
        rows.add(DataRow(cells: [
          DataCell(i == 0
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(employeeName, overflow: TextOverflow.ellipsis),
                )
              : const Text('')),
          DataCell(i == 0
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(item['Office'] ?? '-',
                      overflow: TextOverflow.ellipsis),
                )
              : const Text('')),
          DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: GestureDetector(
                child: Text(
                  item['Learning_Needs'] ?? '-',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black),
                ),
                onTap: () => _showEditPopup(item),
              ),
            ),
          ),
          DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                item['Target_Schedule'] ?? '-',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ),
        ]));
      }
    }

    // Generate unique Target Schedules for filtering
    List<String> targetSchedules = (_originalData
        .map((item) => item['Target_Schedule']?.toString() ?? '-')
        .toSet()
        .toList());

    targetSchedules.sort((a, b) {
      if (a == '-' || b == '-') return a.compareTo(b);
      int yearA = _extractYear(a);
      int yearB = _extractYear(b);
      int quarterA = _parseQuarter(a);
      int quarterB = _parseQuarter(b);
      return yearA != yearB
          ? yearA.compareTo(yearB)
          : quarterA.compareTo(quarterB);
    });

    return Column(
      children: [
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                border: TableBorder.all(color: Colors.grey.shade300),
                columns: [
                  const DataColumn(label: Text('Name')),
                  DataColumn(
                    label: Row(
                      children: [
                        const Text('Office'),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.filter_list, size: 18),
                          onSelected: (value) {
                            if (value != 'ScrollableItems') {
                              setState(() {
                                _selectedOffice = value;
                                _currentPage = 0; // Reset page
                                _applyFilters(_searchController.text);
                              });
                            }
                          },
                          itemBuilder: (context) {
                            final offices = _getUniqueOffices();
                            offices.sort((a, b) =>
                                a.toLowerCase().compareTo(b.toLowerCase()));

                            return [
                              const PopupMenuItem(
                                  value: 'All', child: Text('All')),
                              PopupMenuItem(
                                enabled: false, // Disable direct selection
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxHeight: 200), // Adjust height
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: offices.map((office) {
                                        return PopupMenuItem<String>(
                                          value: office,
                                          child: Text(office),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ];
                          },
                        ),
                      ],
                    ),
                  ),
                  DataColumn(
                    label: Row(
                      children: [
                        const Text('Learning Needs'), // Column label
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.filter_list, size: 18),
                          onSelected: (value) {
                            if (value != 'ScrollableItems') {
                              setState(() {
                                _selectedLearningNeed =
                                    value; // Update the selected learning need filter
                                _currentPage = 0; // Reset page
                                _applyFilters(
                                    _searchController.text); // Apply filters
                              });
                            }
                          },
                          itemBuilder: (context) {
                            final learningNeeds = _getUniqueLearningNeeds();
                            learningNeeds.sort((a, b) => a
                                .toLowerCase()
                                .compareTo(
                                    b.toLowerCase())); // Sort alphabetically

                            return [
                              const PopupMenuItem(
                                value: 'All',
                                child: Text('All'),
                              ),
                              ...learningNeeds.map((learningNeed) {
                                return PopupMenuItem<String>(
                                  value: learningNeed,
                                  child: Text(learningNeed),
                                );
                              }).toList(),
                            ];
                          },
                        ),
                      ],
                    ),
                  ),
                  DataColumn(
                    label: Row(
                      children: [
                        const Text('Target'),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.filter_list, size: 18),
                          onSelected: (value) {
                            if (value != 'ScrollableItems') {
                              setState(() {
                                _selectedTargetSchedule = value;
                                _currentPage = 0; // Reset page
                                _applyFilters(_searchController.text);
                              });
                            }
                          },
                          itemBuilder: (context) {
                            return [
                              const PopupMenuItem(
                                  value: 'All', child: Text('All')),
                              PopupMenuItem(
                                value: 'ScrollableItems',
                                child: SizedBox(
                                  height: 200,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: targetSchedules.map((schedule) {
                                        return ListTile(
                                          title: Text(schedule),
                                          onTap: () {
                                            Navigator.pop(context);
                                            setState(() {
                                              _selectedTargetSchedule =
                                                  schedule;
                                              _currentPage = 0; // Reset page
                                              _applyFilters(
                                                  _searchController.text);
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ];
                          },
                        ),
                      ],
                    ),
                  )
                ],
                rows: rows,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Pagination controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ⏮ First Page
            IconButton(
              icon: const Icon(Icons.first_page),
              tooltip: 'First Page',
              onPressed: _currentPage > 0
                  ? () {
                      setState(() {
                        _currentPage = 0;
                      });
                    }
                  : null,
            ),
            // ◀ Back Page
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous Page',
              onPressed: _currentPage > 0
                  ? () {
                      setState(() {
                        _currentPage--;
                      });
                    }
                  : null,
            ),

            // Page indicator
            Text("Page ${_currentPage + 1} of $totalPages"),

            const SizedBox(width: 10),

            // Manual input
            SizedBox(
              width: 50,
              height: 30,
              child: TextField(
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Go',
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
                onSubmitted: (value) {
                  final page = int.tryParse(value);
                  if (page != null && page > 0 && page <= totalPages) {
                    setState(() {
                      _currentPage = page - 1;
                    });
                  }
                },
              ),
            ),

            const SizedBox(width: 10),

            // ▶ Next Page
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next Page',
              onPressed: _currentPage < totalPages - 1
                  ? () {
                      setState(() {
                        _currentPage++;
                      });
                    }
                  : null,
            ),

            // ⏭ Last Page
            IconButton(
              icon: const Icon(Icons.last_page),
              tooltip: 'Last Page',
              onPressed: _currentPage < totalPages - 1
                  ? () {
                      setState(() {
                        _currentPage = totalPages - 1;
                      });
                    }
                  : null,
            ),

            const SizedBox(width: 20),

            // Range display
            Text(
              'Showing ${startIndex + 1}-${endIndex} of ${groupedEntries.length} employees',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  List<String> _getUniqueLearningNeeds() {
    // Assuming your data is in a list of maps (_originalData)
    // Extracting all unique learning needs
    Set<String> uniqueLearningNeeds = {};

    for (var item in _originalData) {
      if (item['Learning_Needs'] != null) {
        uniqueLearningNeeds.add(item['Learning_Needs']);
      }
    }

    return uniqueLearningNeeds.toList();
  }

  List<String> _getUniqueOffices() {
    return _originalData
        .map((item) => item['Office']?.toString() ?? '-')
        .toSet()
        .toList()
      ..sort();
  }

  void _applyFilters(String query) {
    setState(() {
      // Start with the original data
      _filteredData = List.from(_originalData);

      // Apply office filter if not 'All'
      if (_selectedOffice != 'All') {
        _filteredData = _filteredData
            .where((item) => item['Office'] == _selectedOffice)
            .toList();
      }

      // Apply target schedule filter if not 'All'
      if (_selectedTargetSchedule != 'All') {
        _filteredData = _filteredData
            .where((item) =>
                item['Target_Schedule']?.toString() == _selectedTargetSchedule)
            .toList();
      }

      // Apply learning needs filter if not 'All'
      if (_selectedLearningNeed != 'All') {
        _filteredData = _filteredData
            .where((item) => item['Learning_Needs'] == _selectedLearningNeed)
            .toList();
      }

      // Apply search filter for employee and learning needs
      if (query.isNotEmpty) {
        _filteredData = _filteredData.where((item) {
          bool matchesEmployee =
              item['First_Name'].toLowerCase().contains(query.toLowerCase()) ||
                  item['Last_Name'].toLowerCase().contains(query.toLowerCase());

          bool matchesLearningNeed = item['Learning_Needs']
              .toLowerCase()
              .contains(query.toLowerCase());

          return matchesEmployee || matchesLearningNeed;
        }).toList();
      }
    });
  }

// Helper to extract year from "1st Quarter of 2025"
  int _extractYear(String schedule) {
    final match = RegExp(r'of (\d{4})').firstMatch(schedule);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

// Helper to parse quarter from "1st Quarter of 2025"
  int _parseQuarter(String schedule) {
    if (schedule.contains('1st')) return 1;
    if (schedule.contains('2nd')) return 2;
    if (schedule.contains('3rd')) return 3;
    if (schedule.contains('4th')) return 4;
    return 0;
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
