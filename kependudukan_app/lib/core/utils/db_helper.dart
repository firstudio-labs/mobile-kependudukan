import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:ladimas/core/constants/app_constants.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  static Database? _database;

  factory DbHelper() {
    return _instance;
  }

  DbHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await _createPendudukTable(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      await _ensureTableExists(db, 'penduduk');
    }
  }

  Future _createPendudukTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS penduduk (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nik TEXT UNIQUE,
        password TEXT,
        no_hp TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _ensureTableExists(Database db, String tableName) async {
    var tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName';",
    );

    if (tables.isEmpty) {
      if (tableName == 'penduduk') {
        await _createPendudukTable(db);
      }
    }
  }

  Future<void> resetDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, AppConstants.dbName);
    await deleteDatabase(path);
    _database = null;
  }

  Future<int> insertPenduduk(Map<String, dynamic> data) async {
    Database db = await database;

    await _ensureTableExists(db, 'penduduk');
    return await db.insert(
      'penduduk',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getPendudukByCredentials(
    String nik,
    String password,
  ) async {
    Database db = await database;

    await _ensureTableExists(db, 'penduduk');
    List<Map<String, dynamic>> results = await db.query(
      'penduduk',
      where: 'nik = ? AND password = ?',
      whereArgs: [nik, password],
      limit: 1,
    );

    return results.isNotEmpty ? results.first : null;
  }

  Future<bool> checkNikExists(String nik) async {
    Database db = await database;

    await _ensureTableExists(db, 'penduduk');
    List<Map<String, dynamic>> results = await db.query(
      'penduduk',
      where: 'nik = ?',
      whereArgs: [nik],
      limit: 1,
    );

    return results.isNotEmpty;
  }
}
