import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';

/// SRS Section 9 (Reliability): "never lose a transaction once the user
/// taps Save - write to local storage first, before showing 'Saved'."
/// SRS Section 9 (Offline-first): "capturing and editing must work with no
/// internet; sync automatically when back online."
///
/// This class is the local-first source of truth. The sync service reads
/// rows where pendingSync = 1 and pushes them to Firestore, then clears
/// the flag. The UI always reads from here, never waits on network.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'receipt_book_local.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            bookId TEXT NOT NULL,
            json TEXT NOT NULL,
            pendingSync INTEGER NOT NULL DEFAULT 1,
            updatedAt TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_tx_book ON transactions(bookId)');
      },
    );
    return _db!;
  }

  Future<void> upsertTransaction(AppTransaction tx) async {
    final database = await db;
    await database.insert(
      'transactions',
      {
        'id': tx.id,
        'bookId': tx.bookId,
        'json': jsonEncode(tx.toMap()),
        'pendingSync': tx.pendingSync ? 1 : 0,
        'updatedAt': tx.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AppTransaction>> transactionsForBook(String bookId) async {
    final database = await db;
    final rows = await database.query(
      'transactions',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'updatedAt DESC',
    );
    return rows
        .map((r) => AppTransaction.fromMap(
            r['id'] as String, jsonDecode(r['json'] as String)))
        .where((t) => !t.isDeleted)
        .toList();
  }

  Future<List<AppTransaction>> pendingSyncTransactions() async {
    final database = await db;
    final rows = await database.query('transactions',
        where: 'pendingSync = 1');
    return rows
        .map((r) => AppTransaction.fromMap(
            r['id'] as String, jsonDecode(r['json'] as String)))
        .toList();
  }

  Future<void> markSynced(String id) async {
    final database = await db;
    await database.update('transactions', {'pendingSync': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
