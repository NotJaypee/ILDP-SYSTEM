import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'package:learningneeds_summary/title_page.dart';
import 'generate_page.dart';
import 'package:learningneeds_summary/table_page.dart';

class InputPage extends StatefulWidget {
  final Map<String, dynamic>? editData;

  InputPage({this.editData});

  @override
  _InputPageState createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleInitialController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController officeController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  String selectedPage = 'Input Data';

  void _onPageSelected(String page) {
    setState(() {
      selectedPage = page;
    });
  }

  // To store all the learning needs input fields
  List<Map<String, TextEditingController>> learningNeedsFields = [];

  @override
  void initState() {
    super.initState();
    // Initially add one learning need box
    _addLearningNeed();

    if (widget.editData != null) {
      firstNameController.text = widget.editData!['First_Name'] ?? '';
      middleInitialController.text = widget.editData!['Middle_Initial'] ?? '';
      lastNameController.text = widget.editData!['Last_Name'] ?? '';
      officeController.text = widget.editData!['Office'] ?? '';
      positionController.text = widget.editData!['Position'] ?? '';

      // Load existing learning needs if available
      _loadLearningNeeds();
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleInitialController.dispose();
    lastNameController.dispose();
    officeController.dispose();
    positionController.dispose();
    super.dispose();
  }

  Future<List<String>> _fetchOfficeSuggestions() async {
    var offices = await DBHelper.getOffices();

    if (offices.isEmpty) {
      print("Warning: No office data found!");
      return []; // Return an empty list instead of null
    }

    // Sort the offices alphabetically
    offices.sort((a, b) => a.compareTo(b));

    return offices.cast<String>(); // Ensure it's a List<String>
  }

  Future<List<String>> _fetchPositionSuggestions() async {
    var positions = await DBHelper.getPositions();
    if (positions.isEmpty) {
      print("Warning: No position data found!");
      return []; // Return an empty list instead of null
    }
    positions.sort((a, b) => a.compareTo(b));
    return positions.cast<String>(); // Ensure it's a List<String>
  }

  Future<List<String>> _fetchLearningNeedsSuggestions() async {
    var learningNeeds = await DBHelper.getLearning_Needs();

    learningNeeds.sort((a, b) => a.compareTo(b));
    return learningNeeds.isNotEmpty ? learningNeeds.cast<String>() : [];
  }

  Future<List<String>> _fetchBasisLearningSuggestions() async {
    var basisLearning = await DBHelper.getBasisLearning();

    basisLearning.sort((a, b) => a.compareTo(b));
    return basisLearning.isNotEmpty ? basisLearning.cast<String>() : [];
  }

  Future<List<String>> _fetchProposedActionSuggestions() async {
    var proposedAction = await DBHelper.getProposedAction();

    proposedAction.sort((a, b) => a.compareTo(b));
    return proposedAction.isNotEmpty ? proposedAction.cast<String>() : [];
  }

  Future<List<String>> _fetchTargetScheduleSuggestions() async {
    var targetSchedule = await DBHelper.getTargetSchedule();
    if (targetSchedule.isEmpty) return [];

    targetSchedule.sort((a, b) {
      int quarterA = int.tryParse(a.substring(0, 1)) ?? 0;
      int quarterB = int.tryParse(b.substring(0, 1)) ?? 0;
      int yearA = int.tryParse(a.split('of').last.trim()) ?? 0;
      int yearB = int.tryParse(b.split('of').last.trim()) ?? 0;

      // First sort by year, then by quarter
      if (yearA != yearB) {
        return yearA.compareTo(yearB);
      } else {
        return quarterA.compareTo(quarterB);
      }
    });

    return targetSchedule;
  }

// Build an autocomplete text field
  Widget _buildAutoCompleteField(
    String label,
    TextEditingController controller,
    Future<List<String>> Function() fetchSuggestions,
  ) {
    return FutureBuilder<List<String>>(
      future: fetchSuggestions(),
      builder: (context, snapshot) {
        List<String> suggestions = snapshot.data ?? [];

        return Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return suggestions;
          }
          return suggestions.where((option) => option
              .toLowerCase()
              .contains(textEditingValue.text.toLowerCase()));
        }, onSelected: (String selection) {
          controller.text = selection;
          FocusScope.of(context).unfocus(); // Hide keyboard
        }, fieldViewBuilder: (BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted) {
          textEditingController.text = controller.text;

          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey[200],
            ),
            onChanged: (value) {
              controller.text = value;
            },
            onFieldSubmitted: (value) {
              controller.text = value;
            },
          );
        }, optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<String> onSelected,
          Iterable<String> options,
        ) {
          // Determine the longest option to adjust the width
          final longestOption = options.isEmpty
              ? ''
              : options.reduce((a, b) => a.length > b.length ? a : b);

          // Increase the width for the dropdown (make it wider)
          final estimatedWidth = (longestOption.length * 15.0)
              .clamp(200.0, 800.0); // Adjusted the scale factor

          // Calculate the height based on the number of options
          final estimatedHeight = (options.length * 48.0)
              .clamp(48.0, 200.0); // Each option ~48px tall (adjust if needed)

          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: estimatedWidth, // Much wider width for the dropdown
                height:
                    estimatedHeight, // Dynamic height based on number of options
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return ListTile(
                      title: SingleChildScrollView(
                        scrollDirection:
                            Axis.horizontal, // Allow horizontal scrolling
                        child: Text(
                          option,
                          overflow: TextOverflow
                              .ellipsis, // Prevent text from wrapping
                        ),
                      ),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // Method to load existing learning needs
  Future<void> _loadLearningNeeds() async {
    if (widget.editData != null) {
      var employeeId = widget.editData!['Employee_ID'];
      List<Map<String, dynamic>> learningNeeds =
          await DBHelper.getLearningNeeds(employeeId);

      setState(() {
        // Populate the learning needs fields with data
        learningNeedsFields = learningNeeds.map((ln) {
          return {
            'Learning_Needs': TextEditingController(text: ln['Learning_Needs']),
            'Basis_Learning': TextEditingController(text: ln['Basis_Learning']),
            'Proposed_Action':
                TextEditingController(text: ln['Proposed_Action']),
            'Target_Schedule':
                TextEditingController(text: ln['Target_Schedule']),
          };
        }).toList();
      });
    }
  }

  // Method to add a new learning need input box
  void _addLearningNeed() {
    setState(() {
      learningNeedsFields.add({
        'Learning_Needs': TextEditingController(),
        'Basis_Learning': TextEditingController(),
        'Proposed_Action': TextEditingController(),
        'Target_Schedule': TextEditingController(),
      });
    });
  }

  // Method to save the data and reset the form
  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      try {
        int employeeId;
        if (widget.editData == null) {
          // Insert new employee
          employeeId = await DBHelper.insertEmployee({
            'First_Name': firstNameController.text,
            'Middle_Initial': middleInitialController.text,
            'Last_Name': lastNameController.text,
            'Office': officeController.text,
            'Position': positionController.text,
          });
        } else {
          // Update existing employee
          employeeId = widget.editData!['Employee_ID'];
          await DBHelper.updateEmployee(employeeId, {
            'First_Name': firstNameController.text,
            'Middle_Initial': middleInitialController.text,
            'Last_Name': lastNameController.text,
            'Office': officeController.text,
            'Position': positionController.text,
          });
        }

        // Save all learning needs
        for (var learningNeed in learningNeedsFields) {
          await DBHelper.insertLearningNeed({
            'Employee_ID': employeeId,
            'Learning_Needs': learningNeed['Learning_Needs']!.text,
            'Basis_Learning': learningNeed['Basis_Learning']!.text,
            'Proposed_Action': learningNeed['Proposed_Action']!.text,
            'Target_Schedule': learningNeed['Target_Schedule']!.text,
          });
        }

        _showMessageDialog('Success', 'Data saved successfully!', true);
      } catch (e) {
        _showMessageDialog(
            'Error', 'Failed to save data. Please try again.', false);
      }
    }
  }

  void _showMessageDialog(String title, String message, bool isSuccess) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title,
              style: TextStyle(color: isSuccess ? Colors.green : Colors.red)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (isSuccess) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => InputPage()),
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
              alignment: Alignment.topCenter,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // Section Title
                      const Padding(
                        padding: EdgeInsets.only(left: 0.0, top: 1.0),
                        child: Text(
                          "📝Input Employee's Data",
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 10),
                        child: ExpansionTile(
                          title: const Text(
                            "Employee Information",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          initiallyExpanded: true, // Keep expanded by default
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                          child: _buildTextBox('First Name',
                                              firstNameController, true)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: _buildTextBox('Middle Initial',
                                              middleInitialController, false)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: _buildTextBox('Last Name',
                                              lastNameController, true)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildAutoCompleteField(
                                            'Office',
                                            officeController,
                                            _fetchOfficeSuggestions),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildAutoCompleteField(
                                            'Position',
                                            positionController,
                                            _fetchPositionSuggestions),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Learning Needs Section in an Expandable Card (Default: Expanded)
                      Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ExpansionTile(
                          title: const Text(
                            "Learning Needs Details",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          initiallyExpanded: true, // Keep expanded by default
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: List.generate(
                                    learningNeedsFields.length, (index) {
                                  return Card(
                                    elevation: 2,
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 5),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Learning Need ${index + 1}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              if (index > 0)
                                                IconButton(
                                                  icon: const Icon(Icons.close,
                                                      color: Colors.black),
                                                  onPressed: () {
                                                    setState(() {
                                                      learningNeedsFields
                                                          .removeAt(index);
                                                    });
                                                  },
                                                ),
                                            ],
                                          ),
                                          _buildAutoCompleteField(
                                            'Learning Needs',
                                            learningNeedsFields[index]
                                                ['Learning_Needs']!,
                                            _fetchLearningNeedsSuggestions,
                                          ),
                                          const SizedBox(height: 7),
                                          _buildAutoCompleteField(
                                            'Basis of Learning and Development Needs',
                                            learningNeedsFields[index]
                                                ['Basis_Learning']!,
                                            _fetchBasisLearningSuggestions,
                                          ),
                                          const SizedBox(
                                              height: 7), // Added space
                                          _buildAutoCompleteField(
                                            'Proposed Action/ Methodology',
                                            learningNeedsFields[index]
                                                ['Proposed_Action']!,
                                            _fetchProposedActionSuggestions,
                                          ),
                                          const SizedBox(
                                              height: 7), // Added space
                                          _buildAutoCompleteField(
                                            'Target Implementation/ Schedule',
                                            learningNeedsFields[index]
                                                ['Target_Schedule']!,
                                            _fetchTargetScheduleSuggestions,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                SizedBox(
                                  width: 250, // Set your desired width
                                  child: ElevatedButton(
                                    onPressed: _addLearningNeed,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(255,
                                          40, 91, 167), // A nice green tone
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
                                    child:
                                        const Text('Add Another Learning Need'),
                                  ),
                                ),
                                SizedBox(
                                  width: 250, // Set your desired width
                                  child: ElevatedButton(
                                    onPressed: _saveData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(
                                          255, 40, 91, 167), // Nice blue tone
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
                                    child: const Text('Save All'),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ]));
  }

  Widget _buildTextBox(
      String label, TextEditingController controller, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0)),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        ),
        style: const TextStyle(fontSize: 14),
        validator:
            required ? (value) => value!.isEmpty ? 'Required' : null : null,
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
