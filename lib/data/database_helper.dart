import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseHelper {
  static Database? _database;
  static const _userTable = 'user_data';
  static const _messageTable = 'messages';
  static const _groupTable = 'group_data';


  // Columns for user data
  static const _columnId = 'id';
  static const _columnEmail = 'email';
  static const _columnName = 'nickname';
  static const _columnImagePath = 'ImgPath';

  // Columns for chat messages
  static const _columnSenderID = 'senderID';
  static const _columnReceiverID = 'receiverID';
  static const _columnMessage = 'message';
  static const _columnTimestamp = 'timestamp';
  static const _columnIsCurrentUser = 'isCurrentUser';
  static const _columnMessageID = 'messageID';

  static const _columnGId = 'id';

  static const _columnGroupName = 'groupName';
  static const _columnGroupId = 'groupId';
  static const _columnGroupMembers = 'groupMembers';




  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final DatabaseHelper instance = DatabaseHelper._();

  DatabaseHelper._();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String currentUserID = _auth.currentUser!.uid;
    final path = join(await getDatabasesPath(), 'user_database$currentUserID.db');
    return await openDatabase(
      path,
      version: 30, // Increment the version number
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE $_userTable (
          $_columnId INTEGER PRIMARY KEY AUTOINCREMENT,
          $_columnEmail TEXT,
          $_columnName TEXT,
          $_columnImagePath TEXT
        )
      ''');
        await db.execute('''
        CREATE TABLE $_messageTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          $_columnMessageID TEXT,
          $_columnSenderID TEXT,
          $_columnReceiverID TEXT,
          $_columnMessage TEXT,
          $_columnTimestamp TEXT,
          $_columnIsCurrentUser INTEGER
        )
      ''');
        await db.execute('''
        CREATE TABLE $_groupTable (
          $_columnGId INTEGER PRIMARY KEY AUTOINCREMENT,
          $_columnGroupName TEXT,
          $_columnGroupId TEXT,
          $_columnGroupMembers TEXT
  )
''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 30) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_groupTable (
              $_columnGId INTEGER PRIMARY KEY AUTOINCREMENT,
              $_columnGroupName TEXT,
              $_columnGroupId TEXT,
              $_columnGroupMembers TEXT
            )
          ''');
        }
      },
    );
  }


  Future<bool> messageExists(String messageID) async {
    final db = await database;
    final result = await db.query(
      _messageTable,
      where: '$_columnMessageID = ?',
      whereArgs: [messageID],
    );
    return result.isNotEmpty;
  }

  // Insert decrypted chat messages into local database
  Future<int> insertMessage({
    required String messageID,
    required String senderID,
    required String receiverID,
    required String message,
    required String timestamp,
    required bool isCurrentUser,
  }) async {
    final db = await database;

    // Check if message exists before inserting
    bool exists = await messageExists(messageID);
    if (exists) return 0; // Skip duplicate messages
    return await db.insert(
      _messageTable,
      {
        _columnMessageID: messageID,
        _columnSenderID: senderID,
        _columnReceiverID: receiverID,
        _columnMessage: message,
        _columnTimestamp: timestamp,
        _columnIsCurrentUser: isCurrentUser ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Retrieve chat messages between the current user and a specific receiver
  Future<List<Map<String, dynamic>>> getMessages(String senderID, String receiverID) async {
    final db = await database;
    return await db.query(
      _messageTable,
      where: '($_columnSenderID = ? AND $_columnReceiverID = ?) OR ($_columnSenderID = ? AND $_columnReceiverID = ?)',
      whereArgs: [senderID, receiverID, receiverID, senderID],
      orderBy: '$_columnTimestamp ASC',
    );
  }

  // Clear chat messages
  Future<void> clearChatMessages() async {
    final db = await database;
    await db.delete(_messageTable);
  }

  // Existing user data methods remain unchanged

  Future<int> insertEmail(String email, String nickname) async {
    final db = await instance.database;
    return await db.insert(_userTable, {
      _columnEmail: email,
      _columnName: nickname,
    });
  }

  Future<int> insertGroup(String groupName, String groupId, List<String> members) async {
    final db = await database;

    // Convert members list to a single string (comma-separated)
    String membersString = members.join(',');

    return await db.insert(_groupTable, {

      _columnGroupName: groupName,
      _columnGroupId: groupId,
      _columnGroupMembers: membersString,
    },
      conflictAlgorithm: ConflictAlgorithm.ignore, // Avoid duplicate groups
    );
  }


  Future<List<String>> fetchGroupMembersFromDB(String groupId) async {
    final db = await database;

    final result = await db.query(
      _groupTable,
      columns: [_columnGroupMembers],
      where: '$_columnGroupId = ?',
      whereArgs: [groupId],
    );

    if (result.isNotEmpty) {
      print("Fetched Group Data: ${result.first}");

      // Handle null case properly
      final membersString = result.first[_columnGroupMembers] as String?;

      if (membersString == null || membersString.trim().isEmpty) {
        print("⚠️ No members found, returning empty list.");
        return [];
      }

      final membersList = membersString.split(',');
      print("✅ Group members fetched from local DB: $membersList");

      return membersList;
    } else {
      print("⚠️ No group found in local DB for groupId: $groupId");
      return []; // Return empty list if no group is found
    }
  }





  Future<List<Map<String, dynamic>>> queryAllEmailsWithNicknames() async {
    final db = await instance.database;
    return await db.query(_userTable);
  }

  Future<int> deleteEmail(String email) async {
    final db = await instance.database;
    return await db.delete(_userTable, where: '$_columnEmail = ?', whereArgs: [email]);
  }

  Future<int> deleteMessage(String messageID) async {
    final db = await instance.database;
    return await db.delete(_messageTable, where: '$_columnMessageID = ?', whereArgs: [messageID]);
  }

  Future<int> deleteByEmailOrNickname(String emailOrNickname) async {
    final db = await instance.database;
    int result = await db.delete(
      _userTable,
      where: '$_columnEmail = ?',
      whereArgs: [emailOrNickname],
    );
    if (result == 0) {
      result = await db.delete(
        _userTable,
        where: '$_columnName = ?',
        whereArgs: [emailOrNickname],
      );
    }
    return result;
  }

  Future<int> updateEmail(String oldEmail, String newEmail) async {
    final db = await instance.database;
    return await db.update(
      _userTable,
      {_columnEmail: newEmail},
      where: '$_columnEmail = ?',
      whereArgs: [oldEmail],
    );
  }

  Future<int> insertProfileData(String nickname, String imagePath) async {
    final db = await instance.database;
    return await db.insert(_userTable, {
      _columnName: nickname,
      _columnImagePath: imagePath,
    });
  }

  Future<Map<String, dynamic>?> queryProfileData() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(_userTable);
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<int> updateProfileData(String nickname, String imagePath) async {
    final db = await instance.database;
    return await db.update(
      _userTable,
      {_columnName: nickname, _columnImagePath: imagePath},
      where: '$_columnId = ?',
      whereArgs: [1],
    );
  }

  Future<String?> getEmailByNickname(String nickname) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _userTable,
      where: '$_columnName = ?',
      whereArgs: [nickname],
    );
    return maps.isNotEmpty ? maps.first[_columnEmail] as String : null;
  }

  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.delete(_userTable);
  }
  Future<List<Map<String, dynamic>>> queryAllGroups() async {
    final db = await database;
    return await db.query(_groupTable); // Fetch all groups from SQLite
  }

  Future<String?> getGroupId(String groupName) async {
    final db = await database;

    // Query the database for the group ID where the groupName matches
    List<Map<String, dynamic>> result = await db.query(
      _groupTable,
      columns: [_columnGroupId],
      where: '$_columnGroupName = ?',
      whereArgs: [groupName],
    );

    if (result.isNotEmpty) {
      return result.first[_columnGroupId] as String;
    } else {
      return null; // Return null if not found
    }
  }






}

