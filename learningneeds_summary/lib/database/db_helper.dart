import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Use FFI for Windows
import 'package:path/path.dart'; // For working with database paths

class DBHelper {
  static Database? _database;

  /// **Get database instance**
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    sqfliteFfiInit(); // Initialize FFI
    databaseFactory = databaseFactoryFfi; // Required for Windows

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'learningneeds.db');

    print("Database path: $path"); // Debugging

    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3, // Set the version number
        onCreate: (db, version) async {
          print("Creating tables...");
          await db.execute('PRAGMA foreign_keys = ON;'); // Enable foreign keys

          // Create Employee table
          await db.execute('''CREATE TABLE Employee (
            Employee_ID INTEGER PRIMARY KEY AUTOINCREMENT,
            First_Name TEXT NOT NULL,
            Middle_Initial TEXT,
            Last_Name TEXT NOT NULL,
            Office TEXT,
            Position TEXT
          )''');

          // Create Employee_LearningNeeds table
          await db.execute('''CREATE TABLE Employee_LearningNeeds (
            LN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
            Employee_ID INTEGER NOT NULL,
            Learning_Needs TEXT NOT NULL,
            Basis_Learning TEXT DEFAULT 'N/A',
            Proposed_Action TEXT DEFAULT 'N/A',
            Target_Schedule TEXT DEFAULT 'N/A',
            FOREIGN KEY (Employee_ID) REFERENCES Employee(Employee_ID) ON DELETE CASCADE
          )''');

          // Create the view (moved from onUpgrade)
          await db.execute(
              '''CREATE VIEW IF NOT EXISTS Employee_LearningNeedsView AS
            SELECT 
              e.Employee_ID,
              e.First_Name,
              e.Middle_Initial,
              e.Last_Name,
              e.Office,
              e.Position,
              el.Learning_Needs,
              el.Basis_Learning,
              el.Proposed_Action,
              el.Target_Schedule
            FROM Employee e
            JOIN Employee_LearningNeeds el ON e.Employee_ID = el.Employee_ID;
          ''');

          print("Database and view created successfully.");
        },
        onOpen: (db) {
          db.execute('PRAGMA foreign_keys = ON;'); // Enable foreign keys
          print("Database opened.");
        },
      ),
    );
  }

  Future<void> checkViewExistence() async {
    final db = await DBHelper.database;
    var result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='view' AND name='Employee_LearningNeedsView';");
    if (result.isNotEmpty) {
      print("View exists!");
    } else {
      print("View does not exist.");
    }
  }

  // Method to check if the employee exists and get their ID
  static Future<int?> getEmployeeIdByName(
      String firstName, String lastName) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'Employee',
      where: 'First_Name = ? AND Last_Name = ?',
      whereArgs: [firstName, lastName],
    );

    if (result.isNotEmpty) {
      return result.first['Employee_ID']; // Return the existing Employee_ID
    } else {
      return null; // Employee does not exist
    }
  }

  /// **Insert Employee**
  static Future<int> insertEmployee(Map<String, dynamic> employeeData) async {
    final db = await database;
    try {
      int id = await db.insert('Employee', employeeData);
      print("Employee inserted: ID = $id");
      return id;
    } catch (e) {
      print("Error inserting Employee: $e");
      return 0;
    }
  }

  /// **Insert Learning Need**
  static Future<int> insertLearningNeed(
      Map<String, dynamic> learningData) async {
    final db = await database;
    try {
      int id = await db.insert('Employee_LearningNeeds', learningData);
      print("Learning Need inserted: ID = $id");
      return id;
    } catch (e) {
      print("Error inserting Learning Need: $e");
      return 0;
    }
  }

  /// **Update Learning Need**
  static Future<int> updateLearningNeed(
      int lnId, Map<String, dynamic> data) async {
    final db = await database;
    try {
      int result = await db.update(
        'Employee_LearningNeeds',
        data,
        where: 'LN_ID = ?',
        whereArgs: [lnId],
      );
      print("Update Learning Need result: $result");
      return result;
    } catch (e) {
      print("Error updating Learning Need: $e");
      return 0;
    }
  }

  /// **Get Learning Needs by Employee ID**
  static Future<List<Map<String, dynamic>>> getLearningNeeds(
      int employeeId) async {
    final db = await database;
    try {
      return await db.query('Employee_LearningNeeds',
          where: 'Employee_ID = ?', whereArgs: [employeeId]);
    } catch (e) {
      print("Error fetching Learning Needs: $e");
      return [];
    }
  }

  /// **Get Unique Offices**
  static Future<List<String>> getUniqueOffices() async {
    final db = await database;
    try {
      List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT DISTINCT Office FROM Employee
      WHERE Office IS NOT NULL AND TRIM(Office) <> ''
    ''');
      return result.map((e) => e['Office'].toString()).toList();
    } catch (e) {
      print("Error fetching unique offices: $e");
      return [];
    }
  }

  /// **Get Employees by Learning Need and Office**
  static Future<List<Map<String, dynamic>>> getEmployeesByLearningNeedAndOffice(
      String learningNeed, String office) async {
    final db = await database;
    try {
      List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT e.First_Name,e.Last_Name, e.Office, e.Position, 
             el.Learning_Needs, el.Basis_Learning, el.Proposed_Action, el.Target_Schedule
      FROM Employee e
      JOIN Employee_LearningNeeds el ON e.Employee_ID = el.Employee_ID
      WHERE el.Learning_Needs = ? AND e.Office = ?
      ORDER BY e.First_Name ASC, el.Target_Schedule ASC
    ''', [learningNeed, office]);

      if (result.isEmpty) {
        print(
            "No employees found for learning need: $learningNeed and office: $office");
      }

      return result;
    } catch (e) {
      print("Error fetching employees for learning need and office: $e");
      return [];
    }
  }

  /// **Get Unique Learning Needs**
  static Future<List<String>> getUniqueLearningNeeds() async {
    final db = await database;
    try {
      List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT DISTINCT Learning_Needs FROM Employee_LearningNeeds
      WHERE Learning_Needs IS NOT NULL AND TRIM(Learning_Needs) <> ''
    ''');
      return result.map((e) => e['Learning_Needs'].toString()).toList();
    } catch (e) {
      print("Error fetching unique learning needs: $e");
      return [];
    }
  }

  /// **Get Employees for a Specific Learning Need**
  static Future<List<Map<String, dynamic>>> getEmployeesForLearningNeed(
      String learningNeed) async {
    final db = await database;
    try {
      List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        SELECT 
  Employee.First_Name || ' ' || IFNULL(Employee.Middle_Initial || ' ', '') || Employee.Last_Name AS Employee,
        Employee_LearningNeeds.Learning_Needs,
        Employee_LearningNeeds.Basis_Learning,
        Employee_LearningNeeds.Proposed_Action,
        Employee_LearningNeeds.Target_Schedule
      FROM Employee
      INNER JOIN Employee_LearningNeeds 
      ON Employee.Employee_ID = Employee_LearningNeeds.Employee_ID
      WHERE Employee_LearningNeeds.Learning_Needs = ?
      ORDER BY Target_Schedule ASC, Employee.First_Name ASC
    ''', [learningNeed]);

      if (result.isEmpty) {
        print("No employees found for learning need: $learningNeed");
      }

      return result;
    } catch (e) {
      print("Error fetching employees for learning need: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>>
      getAllEmployeesWithLearningNeeds() async {
    final db = await database;
    try {
      List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT e.Employee_ID, e.First_Name, e.Middle_Initial, e.Last_Name, 
       e.Office, e.Position,
       l.Learning_Needs, l.Basis_Learning, l.Proposed_Action, l.Target_Schedule
FROM Employee e
LEFT JOIN Employee_LearningNeeds l ON e.Employee_ID = l.Employee_ID

    ''');
      print(result); // Add this to check the fetched data
      return result;
    } catch (e) {
      print("Error fetching employees: $e");
      return [];
    }
  }

  /// **Get Learning Needs Details**
  static Future<List<Map<String, dynamic>>> getLearningNeedsDetails(
      int lnId) async {
    final db = await database;
    try {
      return await db.rawQuery('''
      SELECT e.First_Name, e.Last_Name, e.Office, e.Position, 
             l.Learning_Needs, l.Basis_Learning, l.Proposed_Action, l.Target_Schedule
      FROM Employee_LearningNeeds l
      INNER JOIN Employee e ON l.Employee_ID = e.Employee_ID
      WHERE l.LN_ID = ?
    ''', [lnId]);
    } catch (e) {
      print("Error fetching Learning Needs Details: $e");
      return [];
    }
  }

  /// **Get Employees by Learning Need Only**
  static Future<List<Map<String, dynamic>>> getEmployeesByLearningNeedOnly(
      String learningNeed) async {
    final db = await database;
    try {
      List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT e.First_Name, e.Last_Name, e.Office, e.Position, 
             el.Learning_Needs, el.Basis_Learning, el.Proposed_Action, el.Target_Schedule
      FROM Employee e
      JOIN Employee_LearningNeeds el ON e.Employee_ID = el.Employee_ID
      WHERE el.Learning_Needs = ?
      ORDER BY e.First_Name ASC, el.Target_Schedule ASC
    ''', [learningNeed]);

      if (result.isEmpty) {
        print("No employees found for learning need: $learningNeed");
      }

      return result;
    } catch (e) {
      print("Error fetching employees by learning need only: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getEmployeesByLearningNeed(
    String learningNeed, {
    String? year,
    String? quarter,
    String? office, // Add office parameter here
  }) async {
    final db = await database;
    try {
      String query = '''
      SELECT e.First_Name, e.Last_Name, e.Office, e.Position,
             el.Learning_Needs, el.Basis_Learning, el.Proposed_Action, el.Target_Schedule
      FROM Employee e
      JOIN Employee_LearningNeeds el ON e.Employee_ID = el.Employee_ID
      WHERE el.Learning_Needs = ?
    ''';

      List<dynamic> parameters = [learningNeed];

      if (office != null && office != 'All' && office != 'None') {
        query += ' AND e.Office = ?';
        parameters.add(office);
      }

      if (year != null && year != 'All') {
        query += ' AND el.Target_Schedule LIKE ?';
        parameters.add('%$year%');
      }

      if (quarter != null && quarter != 'All') {
        query += ' AND el.Target_Schedule LIKE ?';
        parameters.add('%$quarter%');
      }

      query += ' ORDER BY e.First_Name ASC, el.Target_Schedule ASC';

      List<Map<String, dynamic>> result = await db.rawQuery(query, parameters);

      if (result.isEmpty) {
        print(
            "No employees found for learning need: $learningNeed and office: $office");
      }

      return result;
    } catch (e) {
      print("Error fetching employees for learning need: $learningNeed: $e");
      return [];
    }
  }

  /// **Search Learning Needs by query**
  static Future<List<Map<String, dynamic>>> searchLearningNeeds(
      String query) async {
    final db = await database;
    try {
      List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT * FROM Employee_LearningNeeds
      WHERE Learning_Needs LIKE ? 
    ''', ['%$query%']);

      return result;
    } catch (e) {
      print("Error searching Learning Needs: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>>
      getEmployeesByOfficeWithLearningNeeds(String office) async {
    final db = await database;
    return await db.rawQuery('''
  SELECT 
    e.First_Name, 
    e.Last_Name, 
    e.Office, 
    COALESCE(ln.Learning_Needs, 'No Learning Need') AS Learning_Needs, 
    COALESCE(ln.Basis_Learning, 'N/A') AS Basis_Learning, 
    COALESCE(ln.Proposed_Action, 'N/A') AS Proposed_Action, 
    COALESCE(ln.Target_Schedule, 'N/A') AS Target_Schedule
  FROM Employee e
  LEFT JOIN Employee_LearningNeeds ln ON e.Employee_ID = ln.Employee_ID
  WHERE e.Office = ?
  ORDER BY e.First_Name ASC, ln.Target_Schedule ASC
  ''', [office]);
  }

  /// **Get Employees by Office Only**
  static Future<List<Map<String, dynamic>>> getEmployeesByOfficeOnly(
      String office) async {
    final db = await database;
    try {
      List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT e.First_Name, e.Last_Name, e.Office, e.Position
      FROM Employee e
      WHERE e.Office = ?
      ORDER BY e.First_Name ASC
    ''', [office]);

      if (result.isEmpty) {
        print("No employees found for office: $office");
      }

      return result;
    } catch (e) {
      print("Error fetching employees by office only: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getEmployeesByOffice(
      String office) async {
    final db = await database;
    return await db.query(
      'Employee', // Ensure consistency with table name
      where: 'Office = ?',
      whereArgs: [office],
    );
  }

  // Fetch positions from the Employee table
  static Future<List<String>> getPositions() async {
    final db = await database;
    try {
      // Query unique positions from the Employee table
      List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT DISTINCT Position FROM Employee
      WHERE Position IS NOT NULL AND TRIM(Position) <> ''
    ''');
      // Extract positions as a list of strings
      return result.map((e) => e['Position'].toString()).toList();
    } catch (e) {
      print("Error fetching unique positions: $e");
      return [];
    }
  }

  static Future<List<String>> getOffices() async {
    final db = await database;
    try {
      // Query unique office names from the Employee table
      List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT DISTINCT Office FROM Employee
      WHERE Office IS NOT NULL AND TRIM(Office) <> ''
    ''');

      // Extract offices as a list of strings
      return result.map((e) => e['Office'].toString()).toList();
    } catch (e) {
      print("Error fetching unique offices: $e");
      return [];
    }
  }

  static Future<List<String>> getLearning_Needs() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT DISTINCT Learning_Needs FROM Employee_LearningNeeds
    WHERE Learning_Needs IS NOT NULL AND TRIM(Learning_Needs) <> ''
  ''');
    return result.map((row) => row['Learning_Needs'] as String).toList();
  }

  // In DBHelper class
  static Future<bool> checkLearningNeedExists(
      int employeeId, String learningNeed) async {
    final db = await database; // Get the database instance
    var result = await db.query(
      'Employee_LearningNeeds',
      where: 'Employee_ID = ? AND Learning_Needs = ?',
      whereArgs: [employeeId, learningNeed],
    );

    return result.isNotEmpty; // Return true if a record exists, otherwise false
  }

  static Future<List<String>> getBasisLearning() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT DISTINCT Basis_Learning FROM Employee_LearningNeeds
    WHERE Basis_Learning IS NOT NULL AND TRIM(Basis_Learning) <> ''
  ''');
    return result.map((row) => row['Basis_Learning'] as String).toList();
  }

  static Future<List<String>> getProposedAction() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT DISTINCT Proposed_Action FROM Employee_LearningNeeds
    WHERE Proposed_Action IS NOT NULL AND TRIM(Proposed_Action) <> ''
  ''');
    return result.map((row) => row['Proposed_Action'] as String).toList();
  }

  static Future<List<String>> getDistinctYears() async {
    final db = await database;
    var result = await db.rawQuery(
        'SELECT DISTINCT substr(Target_Schedule, -4) AS year FROM Employee_LearningNeeds WHERE Target_Schedule IS NOT NULL');

    List<String> years = result.map<String>((row) {
      var year = row['year'];
      return year != null ? year.toString() : 'Unknown';
    }).toList();

    return years.where((year) => year != 'Unknown').toList();
  }

  static Future<List<String>> getDistinctQuarters() async {
    final db = await database;
    var result = await db.rawQuery('''
    SELECT DISTINCT Target_Schedule 
    FROM Employee_LearningNeeds
    WHERE Target_Schedule IS NOT NULL
  ''');

    Set<String> quarters = {}; // Using a Set to ensure unique values

    for (var row in result) {
      String targetSchedule = row['Target_Schedule'] as String;

      // Match formats like "Q1 2024" or "1st Quarter of 2024"
      RegExp regExp = RegExp(r'(Q[1-4])|(\d{1,2}(st|nd|rd|th) Quarter)');
      Match? match = regExp.firstMatch(targetSchedule);

      if (match != null) {
        // Extract the correct quarter format
        String quarter = match.group(1) ?? match.group(2) ?? '';
        quarters.add(quarter.trim()); // Ensure no extra spaces
      }
    }

    return quarters.toList()..sort(); // Convert to list and sort
  }

  static Future<List<String>> getTargetSchedule() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT DISTINCT Target_Schedule FROM Employee_LearningNeeds
    WHERE Target_Schedule IS NOT NULL AND TRIM(Target_Schedule) <> ''
    ORDER BY 
      CAST(SUBSTR(Target_Schedule, 1, 1) AS INTEGER),
      CAST(SUBSTR(Target_Schedule, INSTR(Target_Schedule, 'of') + 3) AS INTEGER)
  ''');

    return result.map((row) => row['Target_Schedule'] as String).toList();
  }

  // Example in DBHelper (add this method)
  static Future<List<Map<String, dynamic>>>
      getEmployeesByOfficeOnlyWithLearningNeeds(String office) async {
    final db = await database;
    // SQL query to fetch all employees in the specified office, along with their learning needs
    return await db.rawQuery('''
    SELECT e.First_Name, e.Last_Name, e.Office, ln.Learning_Needs, ln.Basis_Learning, 
           ln.Proposed_Action, ln.Target_Schedule
    FROM Employee e
    LEFT JOIN Employee_LearningNeeds ln ON e.Employee_ID = ln.Employee_ID
    WHERE e.Office = ?
  ''', [office]);
  }

  /// **Delete Employee and Their Learning Needs**
  static Future<void> deleteEmployee(int employeeId) async {
    final db = await database;
    try {
      await db.delete('Employee',
          where: 'Employee_ID = ?', whereArgs: [employeeId]);
      print("Employee deleted: ID = $employeeId");
    } catch (e) {
      print("Error deleting Employee: $e");
    }
  }

  static Future<void> deleteLearningNeed(int lnId) async {
    final db = await database;
    try {
      await db.delete(
        'Employee_LearningNeeds',
        where: 'LN_ID = ?',
        whereArgs: [lnId],
      );
      print("Learning Need deleted: ID = $lnId");
    } catch (e) {
      print("Error deleting Learning Need: $e");
    }
  }

  static Future<List<Map<String, dynamic>>>
      getEmployeesByLearningNeedAndFilters(
          String learningNeed, String? year, String? quarter) async {
    final db = await database;
    String query =
        'SELECT * FROM Employee_LearningNeeds WHERE Learning_Needs = ?';

    // Apply Year filter if selected
    if (year != null && year != 'All') {
      query += ' AND strftime("%Y", Target_Schedule) = ?';
    }

    // Apply Quarter filter if selected
    if (quarter != null && quarter != 'All') {
      query += ' AND Target_Schedule LIKE ?';
    }

    // Prepare the filters
    List<dynamic> filters = [learningNeed];

    if (year != null && year != 'All') filters.add(year);
    if (quarter != null && quarter != 'All') filters.add('%$quarter%');

    return await db.rawQuery(query, filters);
  }

  static Future<void> confirmDeleteEmployee(int employeeId) async {
    final db = await database;
    try {
      await db.delete(
        'Employee',
        where: 'Employee_ID = ?',
        whereArgs: [employeeId],
      );
      print("Employee deleted: ID = $employeeId");
    } catch (e) {
      print("Error deleting Employee: $e");
    }
  }

  /// **Update Employee Details**
  static Future<int> updateEmployee(int id, Map<String, dynamic> data) async {
    final db = await database;
    try {
      int result = await db.update(
        'Employee',
        data,
        where: 'Employee_ID = ?',
        whereArgs: [id],
      );
      print("Update Employee result: $result");
      return result;
    } catch (e) {
      print("Error updating Employee: $e");
      return 0;
    }
  }

  static Future<void> insertEmployeeWithId(
      Map<String, dynamic> employee) async {
    final db = await DBHelper.database;
    await db.insert(
      'Employee',
      employee,
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Replaces if ID already exists
    );
  }

  static Future<void> clearAllEmployeesAndLearningNeeds() async {
    var db = await database;
    // Delete all learning needs first to maintain foreign key integrity
    await db.delete('Employee_LearningNeeds');
    // Then delete all employees
    await db.delete('Employee');
  }

  /// **Close the Database Connection**
  static Future<void> closeDB() async {
    final db = _database;
    if (db != null) {
      await db.close();
      print("Database closed.");
      _database = null;
    }
  }
}
