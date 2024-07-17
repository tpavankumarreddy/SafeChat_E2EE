import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';


class DatabaseHelper {
  static Database? _database;
  static const _tableName = 'user_data';
  static const _columnId = 'id';
  static const _columnEmail = 'email';
  static const _columnName = 'nickname';
  static const _columnImagePath ='ImgPath';

  // Singleton pattern: Private constructor
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  // Getter for the database instance
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'user_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            $_columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $_columnEmail TEXT,
            $_columnName TEXT,
            $_columnImagePath TEXT

          )
        ''');
      },
    );
  }

  // Insert email
  Future<int> insertEmail(String email) async {
    final db = await instance.database;
    return await db.insert(_tableName, {_columnEmail: email});
  }

  // Query all emails
  Future<List<String>> queryAllEmails() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    return List.generate(maps.length, (i) => maps[i][_columnEmail]);
  }

  // Delete email by emial
  Future<int> deleteEmail(String email) async {
    final db = await instance.database;
    return await db.delete(
      _tableName,
      where: '$_columnEmail = ?',
      whereArgs: [email],
    );
  }

  // Update email by emial
  Future<int> updateEmail(String oldEmail, String newEmail) async {
    final db = await instance.database;
    return await db.update(
      _tableName,
      {_columnEmail: newEmail},
      where: '$_columnEmail = ?',
      whereArgs: [oldEmail],
    );
  }

  // Insert nickname and image path
  Future<int> insertProfileData(String nickname, String imagePath) async {
    final db = await instance.database;
    return await db.insert(_tableName, {_columnName: nickname, _columnImagePath: imagePath});
  }

  // Query nickname and image path
  Future<Map<String, dynamic>?> queryProfileData() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    if (maps.isEmpty) return null; // No data found
    return maps.first; // Return the first row (assuming single user profile)
  }

  // Update nickname and image path
  Future<int> updateProfileData(String nickname, String imagePath) async {
    final db = await instance.database;
    return await db.update(
      _tableName,
      {_columnName: nickname, _columnImagePath: imagePath},
      where: '$_columnId = ?',
      whereArgs: [1], // Assuming single user profile (update based on ID)
    );
  }


  // Clear all data from the database
  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.delete(_tableName);
  }
}
