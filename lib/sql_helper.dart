import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class SQLHelper {
  static Future<Database> db() async {
    return openDatabase(
      join(await getDatabasesPath(), 'kindacode.db'),
      version: 2, // Increment version untuk memicu onUpgrade
      onCreate: (Database database, int version) async {
        await database.execute("""
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            image1 TEXT,
            image2 TEXT,
            image3 TEXT,
            link TEXT,
            createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        """);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          // Tambahkan kolom baru jika versi database lebih lama dari 2
          await db.execute('ALTER TABLE items ADD COLUMN image1 TEXT;');
          await db.execute('ALTER TABLE items ADD COLUMN image2 TEXT;');
          await db.execute('ALTER TABLE items ADD COLUMN image3 TEXT;');
          await db.execute('ALTER TABLE items ADD COLUMN link TEXT;');
        }
      },
    );
  }

  // Membaca semua data
  static Future<List<Map<String, dynamic>>> getItems() async {
    final db = await SQLHelper.db();
    return db.query('items', orderBy: "id DESC");
  }

  // Membaca satu data berdasarkan id
  static Future<Map<String, dynamic>?> getItem(int id) async {
    final db = await SQLHelper.db();
    final result =
        await db.query('items', where: "id = ?", whereArgs: [id], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  static Future<int> createItem(
    String title,
    String? description,
    String? image1,
    String? image2,
    String? image3,
    String? link,
  ) async {
    final db = await SQLHelper.db();
    final data = {
      'title': title,
      'description': description,
      'image1': image1,
      'image2': image2,
      'image3': image3,
      'link': link,
    };
    return db.insert('items', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Memperbarui data
  static Future<int> updateItem(
    int id,
    String title,
    String? description,
    String? image1,
    String? image2,
    String? image3,
    String? link,
  ) async {
    final db = await SQLHelper.db();
    final data = {
      'title': title,
      'description': description,
      'image1': image1,
      'image2': image2,
      'image3': image3,
      'link': link,
      'createdAt': DateTime.now().toString()
    };
    return db.update('items', data, where: "id = ?", whereArgs: [id]);
  }

  // Menghapus data
  static Future<void> deleteItem(int id) async {
    final db = await SQLHelper.db();
    await db.delete('items', where: "id = ?", whereArgs: [id]);
  }
}
