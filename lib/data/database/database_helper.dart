import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createHackathonsTable(db);
    }
    if (oldVersion < 3) {
      await _upgradeToV3(db);
    }
    if (oldVersion < 4) {
      await _upgradeToV4(db);
    }
    if (oldVersion < 5) {
      await _upgradeToV5(db);
    }
    if (oldVersion < 6) {
      await _upgradeToV6(db);
    }
    if (oldVersion < 7) {
      await _upgradeToV7(db);
    }
    if (oldVersion < 8) {
      await _upgradeToV8(db);
    }
    if (oldVersion < 9) {
      await _upgradeToV9(db);
    }
    if (oldVersion < 10) {
      await _upgradeToV10(db);
    }
  }

  Future<void> _upgradeToV10(Database db) async {
    // Recreate scheduled_notifications table to fix foreign key reference
    // cause by tasks table rename in V9
    await db.execute(
      'ALTER TABLE scheduled_notifications RENAME TO scheduled_notifications_old',
    );

    await _createScheduledNotificationsTable(db);

    // Copy data
    // Columns: id, scheduled_at, title, body, type, course_id, task_id, assignment_id, hackathon_id
    // We can just copy all
    await db.execute('''
      INSERT INTO scheduled_notifications (id, scheduled_at, title, body, type, course_id, task_id, assignment_id, hackathon_id)
      SELECT id, scheduled_at, title, body, type, course_id, task_id, assignment_id, hackathon_id
      FROM scheduled_notifications_old
    ''');

    await db.execute('DROP TABLE scheduled_notifications_old');
  }

  Future<void> _upgradeToV9(Database db) async {
    // Make course_id nullable in tasks table
    // SQLite doesn't support ALTER COLUMN, so we must recreate the table
    // 1. Rename old table
    await db.execute('ALTER TABLE tasks RENAME TO tasks_old');

    // 2. Create new table with nullable course_id
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const boolType = 'INTEGER NOT NULL';
    const intNullable = 'INTEGER'; // Nullable integer

    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        title $textType,
        description $textNullable,
        is_completed $boolType,
        course_id $intNullable,
        due_date $textNullable,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE
      )
    ''');

    // 3. Copy data from old table to new table
    // We can just copy columns as names match
    await db.execute('''
      INSERT INTO tasks (id, title, description, is_completed, course_id, due_date)
      SELECT id, title, description, is_completed, course_id, due_date
      FROM tasks_old
    ''');

    // 4. Drop old table
    await db.execute('DROP TABLE tasks_old');
  }

  Future<void> _createHackathonsTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intNullable = 'INTEGER';

    await db.execute('''
      CREATE TABLE hackathons (
        id $idType,
        name $textType,
        theme $textNullable,
        description $textNullable,
        start_date $textType,
        end_date $textNullable,
        team_size $intNullable,
        tech_stack $textNullable,
        outcome $textNullable,
        project_link $textNullable
      )
    ''');
  }

  Future<void> _upgradeToV4(Database db) async {
    // Add description column to hackathons table
    await db.execute('ALTER TABLE hackathons ADD COLUMN description TEXT');

    // Create new tables for Event/Hackathon links and dates
    await _createHackathonLinksTable(db);
    await _createHackathonDatesTable(db);
  }

  Future<void> _createHackathonLinksTable(Database db) async {
    await db.execute('''
      CREATE TABLE hackathon_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hackathon_id INTEGER NOT NULL,
        url TEXT NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY (hackathon_id) REFERENCES hackathons (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createHackathonDatesTable(Database db) async {
    await db.execute('''
      CREATE TABLE hackathon_dates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hackathon_id INTEGER NOT NULL,
        date_val TEXT NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY (hackathon_id) REFERENCES hackathons (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeToV3(Database db) async {
    // Add new columns to courses table
    // default 'site' for existing rows (index 0 of enum) in logic, but here strict text
    // We add columns one by one
    await db.execute('ALTER TABLE courses ADD COLUMN type TEXT DEFAULT "site"');
    await db.execute('ALTER TABLE courses ADD COLUMN source_name TEXT');
    await db.execute('ALTER TABLE courses ADD COLUMN channel_name TEXT');

    // Create new tables
    await _createCourseLinksTable(db);
    await _createCourseDatesTable(db);

    // Migrate existing 'platform' data to 'source_name'
    // 'platform' column still exists, we can copy data
    await db.execute('UPDATE courses SET source_name = platform');
  }

  Future<void> _createCourseLinksTable(Database db) async {
    await db.execute('''
      CREATE TABLE course_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL,
        url TEXT NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createCourseDatesTable(Database db) async {
    await db.execute('''
      CREATE TABLE course_dates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL,
        date_val TEXT NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const boolType = 'INTEGER NOT NULL'; // 0 or 1
    // ignore: unused_local_variable
    const intType = 'INTEGER NOT NULL';
    const intNullable = 'INTEGER';
    const realType = 'REAL NOT NULL';

    // Courses Table
    await db.execute('''
      CREATE TABLE courses ( 
        id $idType, 
        title $textType,
        description $textNullable,
        platform $textType,
        start_date $textType,
        completion_date $textNullable,
        progress_percent $realType,
        status $textType,
        type $textType,
        source_name $textType,
        channel_name $textNullable,
        login_mail $textNullable
      )
    ''');

    // Tasks Table
    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        title $textType,
        description $textNullable,
        is_completed $boolType,
        course_id $intNullable,
        due_date $textNullable,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE
      )
    ''');

    // Remove Study Sessions Table creation as it is deprecated

    // Hackathons Table
    await _createHackathonsTable(db);
    // Explicitly add login_mail to hackathons for fresh installs (V5)
    await db.execute('ALTER TABLE hackathons ADD COLUMN login_mail TEXT');

    // New V3 Tables
    await _createCourseLinksTable(db);
    await _createCourseDatesTable(db);

    // New V4 Tables
    await _createHackathonLinksTable(db);
    await _createHackathonDatesTable(db);

    // Assignments Table (V6)
    await _createAssignmentsTable(db);

    // Folders and Notes (V7)
    await _createFoldersTable(db);
    await _createNotesTable(db);

    // Scheduled Notifications (V8)
    await _createScheduledNotificationsTable(db);
  }

  // ---------------- CRUD Operations ----------------

  // --- Courses ---
  Future<int> createCourse(Map<String, dynamic> course) async {
    final db = await instance.database;
    return await db.insert('courses', course);
  }

  Future<Map<String, dynamic>?> getCourse(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'courses',
      columns: null, // all columns
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    } else {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllCourses() async {
    final db = await instance.database;
    return await db.query('courses');
  }

  Future<int> updateCourse(Map<String, dynamic> course) async {
    final db = await instance.database;
    return db.update(
      'courses',
      course,
      where: 'id = ?',
      whereArgs: [course['id']],
    );
  }

  Future<int> deleteCourse(int id) async {
    final db = await instance.database;
    return await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  // --- Tasks ---
  Future<int> createTask(Map<String, dynamic> task) async {
    final db = await instance.database;
    return await db.insert('tasks', task);
  }

  Future<List<Map<String, dynamic>>> getTasksForCourse(int courseId) async {
    final db = await instance.database;
    return await db.query(
      'tasks',
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'is_completed ASC, due_date ASC',
    );
  }

  Future<int> updateTask(Map<String, dynamic> task) async {
    final db = await instance.database;
    return db.update('tasks', task, where: 'id = ?', whereArgs: [task['id']]);
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // --- Assignments (V6) ---

  Future<void> _upgradeToV5(Database db) async {
    // Add login_mail column to courses and hackathons tables
    await db.execute('ALTER TABLE courses ADD COLUMN login_mail TEXT');
    await db.execute('ALTER TABLE hackathons ADD COLUMN login_mail TEXT');
  }

  Future<void> _upgradeToV6(Database db) async {
    await _createAssignmentsTable(db);
  }

  Future<void> _createAssignmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        subject TEXT,
        type TEXT NOT NULL,
        due_date INTEGER NOT NULL,
        submission_date INTEGER,
        is_completed INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _upgradeToV7(Database db) async {
    await _createFoldersTable(db);
    await _createNotesTable(db);
  }

  Future<void> _createFoldersTable(Database db) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        parent_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES folders (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        folder_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createScheduledNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE scheduled_notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scheduled_at TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
        task_id INTEGER REFERENCES tasks(id) ON DELETE CASCADE,
        assignment_id INTEGER REFERENCES assignments(id) ON DELETE CASCADE,
        hackathon_id INTEGER REFERENCES hackathons(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeToV8(Database db) async {
    await _createScheduledNotificationsTable(db);
    // Data backfill happens at app startup via NotificationScheduler.backfillFromExisting()
  }

  Future<int> createAssignment(Map<String, dynamic> assignment) async {
    final db = await instance.database;
    return await db.insert('assignments', assignment);
  }

  Future<List<Map<String, dynamic>>> getAllAssignments() async {
    final db = await instance.database;
    return await db.query(
      'assignments',
      orderBy: 'is_completed ASC, due_date ASC',
    );
  }

  Future<int> updateAssignment(Map<String, dynamic> assignment) async {
    final db = await instance.database;
    return await db.update(
      'assignments',
      assignment,
      where: 'id = ?',
      whereArgs: [assignment['id']],
    );
  }

  Future<int> deleteAssignment(int id) async {
    final db = await instance.database;
    return await db.delete('assignments', where: 'id = ?', whereArgs: [id]);
  }

  // Hackathons (Keeping existing methods)
  Future<int> createHackathon(Map<String, dynamic> hackathon) async {
    final db = await instance.database;
    return await db.insert('hackathons', hackathon);
  }

  Future<List<Map<String, dynamic>>> getAllHackathons() async {
    final db = await instance.database;
    return await db.query('hackathons', orderBy: 'start_date DESC');
  }

  Future<int> updateHackathon(Map<String, dynamic> hackathon) async {
    final db = await instance.database;
    return await db.update(
      'hackathons',
      hackathon,
      where: 'id = ?',
      whereArgs: [hackathon['id']],
    );
  }

  Future<int> deleteHackathon(int id) async {
    final db = await instance.database;
    return await db.delete('hackathons', where: 'id = ?', whereArgs: [id]);
  }

  // --- New Helper Methods for V3 ---

  // Links
  Future<void> insertCourseLinks(
    int courseId,
    List<Map<String, dynamic>> links,
  ) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var link in links) {
      link['course_id'] = courseId;
      batch.insert('course_links', link);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateCourseLinks(
    int courseId,
    List<Map<String, dynamic>> links,
  ) async {
    final db = await instance.database;
    // Simple strategy: delete all for this course and re-insert
    await db.delete(
      'course_links',
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
    await insertCourseLinks(courseId, links);
  }

  Future<List<Map<String, dynamic>>> getLinksForCourse(int courseId) async {
    final db = await instance.database;
    return await db.query(
      'course_links',
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
  }

  // Dates
  Future<void> insertCourseDates(
    int courseId,
    List<Map<String, dynamic>> dates,
  ) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var date in dates) {
      date['course_id'] = courseId;
      batch.insert('course_dates', date);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateCourseDates(
    int courseId,
    List<Map<String, dynamic>> dates,
  ) async {
    final db = await instance.database;
    await db.delete(
      'course_dates',
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
    await insertCourseDates(courseId, dates);
  }

  Future<List<Map<String, dynamic>>> getDatesForCourse(int courseId) async {
    final db = await instance.database;
    return await db.query(
      'course_dates',
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
  }

  // --- Hackathon/Event Helpers (V4) ---

  // Hackathon Links
  Future<void> insertHackathonLinks(
    int hackathonId,
    List<Map<String, dynamic>> links,
  ) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var link in links) {
      link['hackathon_id'] = hackathonId;
      batch.insert('hackathon_links', link);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateHackathonLinks(
    int hackathonId,
    List<Map<String, dynamic>> links,
  ) async {
    final db = await instance.database;
    await db.delete(
      'hackathon_links',
      where: 'hackathon_id = ?',
      whereArgs: [hackathonId],
    );
    await insertHackathonLinks(hackathonId, links);
  }

  Future<List<Map<String, dynamic>>> getLinksForHackathon(
    int hackathonId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'hackathon_links',
      where: 'hackathon_id = ?',
      whereArgs: [hackathonId],
    );
  }

  // Hackathon Dates
  Future<void> insertHackathonDates(
    int hackathonId,
    List<Map<String, dynamic>> dates,
  ) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var date in dates) {
      date['hackathon_id'] = hackathonId;
      batch.insert('hackathon_dates', date);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateHackathonDates(
    int hackathonId,
    List<Map<String, dynamic>> dates,
  ) async {
    final db = await instance.database;
    await db.delete(
      'hackathon_dates',
      where: 'hackathon_id = ?',
      whereArgs: [hackathonId],
    );
    await insertHackathonDates(hackathonId, dates);
  }

  Future<List<Map<String, dynamic>>> getDatesForHackathon(
    int hackathonId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'hackathon_dates',
      where: 'hackathon_id = ?',
      whereArgs: [hackathonId],
    );
  }

  // Distinct Sites
  Future<List<String>> getDistinctSites() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT source_name FROM courses WHERE type = "site" ORDER BY source_name ASC',
    );
    return result.map((row) => row['source_name'] as String).toList();
  }

  // Distinct Login Mails (aggregated from Courses and Hackathons)
  Future<List<String>> getDistinctLoginMails() async {
    final db = await instance.database;
    // Union of mails from both tables
    final result = await db.rawQuery('''
      SELECT DISTINCT login_mail FROM courses WHERE login_mail IS NOT NULL AND login_mail != ''
      UNION
      SELECT DISTINCT login_mail FROM hackathons WHERE login_mail IS NOT NULL AND login_mail != ''
      ORDER BY login_mail ASC
    ''');
    return result.map((row) => row['login_mail'] as String).toList();
  }

  // --- Folders & Notes Operations (V7) ---

  // Folders
  Future<int> createFolder(Map<String, dynamic> folder) async {
    final db = await instance.database;
    return await db.insert('folders', folder);
  }

  Future<List<Map<String, dynamic>>> getFolders({int? parentId}) async {
    final db = await instance.database;
    final whereClause = parentId == null
        ? 'parent_id IS NULL'
        : 'parent_id = ?';
    final whereArgs = parentId == null ? [] : [parentId];

    return await db.query(
      'folders',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
  }

  Future<int> updateFolder(Map<String, dynamic> folder) async {
    final db = await instance.database;
    return await db.update(
      'folders',
      folder,
      where: 'id = ?',
      whereArgs: [folder['id']],
    );
  }

  Future<int> deleteFolder(int id) async {
    final db = await instance.database;
    return await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // Notes
  Future<int> createNote(Map<String, dynamic> note) async {
    final db = await instance.database;
    return await db.insert('notes', note);
  }

  Future<List<Map<String, dynamic>>> getNotes({int? folderId}) async {
    final db = await instance.database;
    final whereClause = folderId == null
        ? 'folder_id IS NULL'
        : 'folder_id = ?';
    final whereArgs = folderId == null ? [] : [folderId];

    return await db.query(
      'notes',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );
  }

  Future<int> updateNote(Map<String, dynamic> note) async {
    final db = await instance.database;
    return await db.update(
      'notes',
      note,
      where: 'id = ?',
      whereArgs: [note['id']],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // --- Scheduled Notifications (V8) ---

  Future<int> insertScheduledNotification(
    Map<String, dynamic> notification,
  ) async {
    final db = await instance.database;
    return await db.insert('scheduled_notifications', notification);
  }

  Future<List<Map<String, dynamic>>> getNotificationsFor(
    String fkColumn,
    int itemId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'scheduled_notifications',
      where: '$fkColumn = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deleteNotificationsFor(String fkColumn, int itemId) async {
    final db = await instance.database;
    await db.delete(
      'scheduled_notifications',
      where: '$fkColumn = ?',
      whereArgs: [itemId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllScheduledNotifications() async {
    final db = await instance.database;
    return await db.query('scheduled_notifications');
  }
}
