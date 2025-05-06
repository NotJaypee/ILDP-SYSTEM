import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class EditEmployeePage extends StatefulWidget {
  final Map<String, dynamic> employee;
  final Function onUpdate; // Callback function to update parent widget

  EditEmployeePage({required this.employee, required this.onUpdate});

  @override
  _EditEmployeePageState createState() => _EditEmployeePageState();
}

class _EditEmployeePageState extends State<EditEmployeePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleInitialController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController officeController = TextEditingController();
  final TextEditingController positionController = TextEditingController();

  List<Map<String, dynamic>> learningNeedsFields = [];

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
    _loadLearningNeeds();
  }

  void _loadEmployeeData() {
    firstNameController.text = widget.employee['First_Name'] ?? '';
    middleInitialController.text = widget.employee['Middle_Initial'] ?? '';
    lastNameController.text = widget.employee['Last_Name'] ?? '';
    officeController.text = widget.employee['Office'] ?? '';
    positionController.text = widget.employee['Position'] ?? '';
  }

  Future<void> _loadLearningNeeds() async {
    List<Map<String, dynamic>> learningNeeds =
        await DBHelper.getLearningNeeds(widget.employee['Employee_ID']);

    setState(() {
      learningNeedsFields = learningNeeds.map((ln) {
        return {
          'LN_ID': ln['LN_ID'],
          'Learning_Needs': TextEditingController(text: ln['Learning_Needs']),
          'Basis_Learning': TextEditingController(text: ln['Basis_Learning']),
          'Proposed_Action': TextEditingController(text: ln['Proposed_Action']),
          'Target_Schedule': TextEditingController(text: ln['Target_Schedule']),
        };
      }).toList();
      _sortLearningNeeds(); // Sort after adding
    });
  }

  void _addLearningNeed() {
    setState(() {
      // Add a new learning need (without sorting)
      learningNeedsFields.add({
        'Learning_Needs': TextEditingController(),
        'Basis_Learning': TextEditingController(),
        'Proposed_Action': TextEditingController(),
        'Target_Schedule': TextEditingController(),
      });
    });
    // Optionally, reload learning needs from DB if necessary
    //_loadLearningNeeds();
  }

  Future<void> _deleteLearningNeed(int index) async {
    if (learningNeedsFields[index].containsKey('LN_ID')) {
      // Delete from the database
      await DBHelper.deleteLearningNeed(learningNeedsFields[index]['LN_ID']);
    }

    setState(() {
      // Remove the learning need from the list
      learningNeedsFields.removeAt(index);
    });

    // Refresh the data dynamically in parent widget
    widget.onUpdate();
  }

  Future<void> _confirmDeleteEmployee() async {
    bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Employee'),
          content: Text('Are you sure you want to delete this employee?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Don't delete
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context, true); // Proceed with deletion
                try {
                  await DBHelper.confirmDeleteEmployee(
                      widget.employee['Employee_ID']);
                  print("Employee deleted successfully.");

                  // Show confirmation message using SnackBar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Employee deleted successfully.'),
                      duration: Duration(seconds: 2), // Show for 2 seconds
                    ),
                  );

                  widget
                      .onUpdate(); // Refresh list in parent widget after deletion
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context, true); // Close dialog
                  }
                } catch (e) {
                  print("Error deleting employee: $e");
                }
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete != null && confirmDelete) {
      // Employee is deleted and handled inside dialog
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      try {
        print("Updating employee...");

        await DBHelper.updateEmployee(widget.employee['Employee_ID'], {
          'First_Name': firstNameController.text,
          'Middle_Initial': middleInitialController.text,
          'Last_Name': lastNameController.text,
          'Office': officeController.text,
          'Position': positionController.text,
        });

        for (var learningNeed in learningNeedsFields) {
          if (learningNeed.containsKey('LN_ID')) {
            await DBHelper.updateLearningNeed(learningNeed['LN_ID'], {
              'Learning_Needs': learningNeed['Learning_Needs']!.text,
              'Basis_Learning': learningNeed['Basis_Learning']!.text,
              'Proposed_Action': learningNeed['Proposed_Action']!.text,
              'Target_Schedule': learningNeed['Target_Schedule']!.text,
            });
          } else {
            await DBHelper.insertLearningNeed({
              'Employee_ID': widget.employee['Employee_ID'],
              'Learning_Needs': learningNeed['Learning_Needs']!.text,
              'Basis_Learning': learningNeed['Basis_Learning']!.text,
              'Proposed_Action': learningNeed['Proposed_Action']!.text,
              'Target_Schedule': learningNeed['Target_Schedule']!.text,
            });
          }
        }

        print("All updates completed.");

        // Refresh the parent table dynamically
        widget.onUpdate();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Changes saved successfully!')),
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context, true); // Close dialog
        }
      } catch (e) {
        print("Error updating employee: $e");
      }
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    officeController.dispose();
    positionController.dispose();
    for (var learningNeed in learningNeedsFields) {
      learningNeed['Learning_Needs']?.dispose();
      learningNeed['Basis_Learning']?.dispose();
      learningNeed['Proposed_Action']?.dispose();
      learningNeed['Target_Schedule']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: EdgeInsets.all(10),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 700, maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Employee Learning Needs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextBox('First Name', firstNameController, true),
                        _buildTextBox(
                            'Middle Initial', middleInitialController, true),
                        _buildTextBox('Last Name', lastNameController, true),
                        _buildTextBox('Office', officeController, true),
                        _buildTextBox('Position', positionController, true),
                        Divider(),
                        Text("Learning Needs",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Column(
                          children: List.generate(learningNeedsFields.length,
                              (index) {
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 6),
                              elevation: 3,
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    _buildTextBox(
                                        'Learning Needs',
                                        learningNeedsFields[index]
                                            ['Learning_Needs']!,
                                        true),
                                    _buildTextBox(
                                        'Basis Learning',
                                        learningNeedsFields[index]
                                            ['Basis_Learning']!,
                                        false),
                                    _buildTextBox(
                                        'Proposed Action',
                                        learningNeedsFields[index]
                                            ['Proposed_Action']!,
                                        false),
                                    _buildTextBox(
                                        'Target Schedule',
                                        learningNeedsFields[index]
                                            ['Target_Schedule']!,
                                        false),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        icon: Icon(Icons.delete,
                                            color: Colors.red),
                                        label: Text("Remove",
                                            style:
                                                TextStyle(color: Colors.red)),
                                        onPressed: () =>
                                            _deleteLearningNeed(index),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton.icon(
                          icon: Icon(Icons.add),
                          label: Text('Add Another Learning Need'),
                          onPressed: _addLearningNeed,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _confirmDeleteEmployee(),
                    child: Text('Delete Employee',
                        style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: _saveChanges,
                    child: Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextBox(
      String label, TextEditingController controller, bool required) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator:
            required ? (value) => value!.isEmpty ? 'Required' : null : null,
      ),
    );
  }

  // Helper function to sort learning needs alphabetically
  void _sortLearningNeeds() {
    learningNeedsFields.sort((a, b) {
      return (a['Learning_Needs']!.text.toLowerCase())
          .compareTo((b['Learning_Needs']!.text.toLowerCase()));
    });
  }
}
