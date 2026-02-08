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
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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
    const intType = 'INTEGER NOT NULL';
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

    // Course Certificates Table
    await db.execute('''
      CREATE TABLE course_certificates (
        id $idType,
        course_id $intType,
        certificate_path $textType,
        date_earned $textType,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE
      )
    ''');

    // Tasks Table
    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        title $textType,
        description $textNullable,
        is_completed $boolType,
        course_id $intType,
        due_date $textNullable,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE
      )
    ''');

    // Study Sessions Table
    await db.execute('''
      CREATE TABLE study_sessions (
        id $idType,
        course_id $intType,
        start_time $textType,
        duration_minutes $intType,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE
      )
    ''');

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

  // --- Certificates ---
  Future<int> addCertificate(Map<String, dynamic> certificate) async {
    final db = await instance.database;
    return await db.insert('course_certificates', certificate);
  }

  Future<List<Map<String, dynamic>>> getCertificatesForCourse(
    int courseId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'course_certificates',
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
  }

  Future<int> deleteCertificate(int id) async {
    final db = await instance.database;
    return await db.delete(
      'course_certificates',
      where: 'id = ?',
      whereArgs: [id],
    );
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

  // --- Study Sessions ---
  Future<int> startSession(Map<String, dynamic> session) async {
    final db = await instance.database;
    return await db.insert('study_sessions', session);
  }

  Future<List<Map<String, dynamic>>> getSessionsForCourse(int courseId) async {
    final db = await instance.database;
    return await db.query(
      'study_sessions',
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'start_time DESC',
    );
  }

  // --- Hackathons ---
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

  Future<void> _upgradeToV5(Database db) async {
    // Add login_mail column to courses and hackathons tables
    await db.execute('ALTER TABLE courses ADD COLUMN login_mail TEXT');
    await db.execute('ALTER TABLE hackathons ADD COLUMN login_mail TEXT');
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
}
