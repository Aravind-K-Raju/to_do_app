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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createHackathonsTable(db);
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
        start_date $textType,
        end_date $textNullable,
        team_size $intNullable,
        tech_stack $textNullable,
        outcome $textNullable,
        project_link $textNullable
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
        status $textType
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
}
