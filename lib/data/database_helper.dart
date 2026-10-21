import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/focus_preset.dart';
import '../models/session_log.dart';

class DatabaseHelper {
  DatabaseHelper._(this._path);

  // not final so tests can swap in a temp database
  static DatabaseHelper instance = DatabaseHelper._('focus_studio.db');

  // tests use this to get a throwaway database
  factory DatabaseHelper.forPath(String path) => DatabaseHelper._(path);

  final String _path;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final full = _path == inMemoryDatabasePath
        ? _path
        : join(await getDatabasesPath(), _path);
    _db = await openDatabase(
      full,
      version: 1,
      onConfigure: (db) async {
        // sqlite ignores foreign keys unless you turn them on
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE FocusPreset (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT NOT NULL,
            moodTag TEXT NOT NULL,
            plannedSeconds INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE SessionLog (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            presetId INTEGER NOT NULL,
            startedAt TEXT NOT NULL,
            plannedSecondsSnapshot INTEGER NOT NULL,
            completedSeconds INTEGER NOT NULL,
            moodTagSnapshot TEXT NOT NULL,
            status TEXT NOT NULL,
            source TEXT NOT NULL,
            note TEXT,
            FOREIGN KEY (presetId) REFERENCES FocusPreset (id)
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ---- FocusPreset ----

  Future<int> insertPreset(FocusPreset p) async {
    final err = p.validate();
    if (err != null) throw ArgumentError(err);
    final db = await database;
    return db.insert('FocusPreset', p.toMap()..remove('id'));
  }

  Future<List<FocusPreset>> getPresets({String? mood}) async {
    final db = await database;
    final rows = await db.query(
      'FocusPreset',
      where: mood == null ? null : 'moodTag = ?',
      whereArgs: mood == null ? null : [mood],
      orderBy: 'label COLLATE NOCASE',
    );
    return rows.map(FocusPreset.fromMap).toList();
  }

  Future<FocusPreset?> getPreset(int id) async {
    final db = await database;
    final rows = await db.query('FocusPreset', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : FocusPreset.fromMap(rows.first);
  }

  Future<int> updatePreset(FocusPreset p) async {
    if (p.id == null) throw ArgumentError('Preset has no id');
    final err = p.validate();
    if (err != null) throw ArgumentError(err);
    final db = await database;
    return db.update('FocusPreset', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  // ---- SessionLog (just insert for now, the rest comes with the history screen) ----

  Future<int> insertLog(SessionLog log) async {
    final err = log.validate();
    if (err != null) throw ArgumentError(err);
    final db = await database;
    return db.insert('SessionLog', log.toMap()..remove('id'));
  }

  // how many logs would go away if this preset is deleted (for the dialog)
  Future<int> countLogsForPreset(int presetId) async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM SessionLog WHERE presetId = ?', [presetId]);
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // deletes the preset and its logs together, or neither
  Future<void> deletePreset(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('SessionLog', where: 'presetId = ?', whereArgs: [id]);
      await txn.delete('FocusPreset', where: 'id = ?', whereArgs: [id]);
    });
  }

  // average completed minutes over finished sessions, and how many there were
  Future<({double? averageMinutes, int count})> getAverageCompleted() async {
    final db = await database;
    final rows = await db.rawQuery(
        "SELECT AVG(completedSeconds) AS avg, COUNT(*) AS c FROM SessionLog "
        "WHERE status = ? AND completedSeconds > 0",
        ['finished']);
    final avg = rows.first['avg'] as num?;
    final count = rows.first['c'] as int;
    return (averageMinutes: avg == null ? null : avg / 60, count: count);
  }
}
