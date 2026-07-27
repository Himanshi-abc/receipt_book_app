import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';
import '../models/contact_model.dart';
import '../models/khata_entry_model.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/product_category_model.dart';

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
      version: 5,
      onCreate: (db, version) async {
        await _createTransactionsTable(db);
        await _createContactsTable(db);
        await _createKhataEntriesTable(db);
        await _createProductsTable(db);
        await _createCategoriesTable(db);
        await _createProductCategoriesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Only ever ADD tables here - existing tables (and any data already
        // in them on upgrading installs) must never be touched or recreated.
        if (oldVersion < 2) {
          // v1 -> v2: added the Customers/Suppliers khata ledger.
          await _createContactsTable(db);
          await _createKhataEntriesTable(db);
        }
        if (oldVersion < 3) {
          // v2 -> v3: added the Products catalog.
          await _createProductsTable(db);
        }
        if (oldVersion < 4) {
          // v3 -> v4: added user-created categories.
          await _createCategoriesTable(db);
        }
        if (oldVersion < 5) {
          // v4 -> v5: added Product/Service categories (kept separate from
          // Income/Expense categories).
          await _createProductCategoriesTable(db);
        }
      },
    );
    return _db!;
  }

  Future<void> _createTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        bookId TEXT NOT NULL,
        json TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_book ON transactions(bookId)');
  }

  Future<void> _createContactsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contacts (
        id TEXT PRIMARY KEY,
        bookId TEXT NOT NULL,
        json TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_book ON contacts(bookId)');
  }

  Future<void> _createKhataEntriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS khata_entries (
        id TEXT PRIMARY KEY,
        bookId TEXT NOT NULL,
        contactId TEXT NOT NULL,
        json TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_khata_book ON khata_entries(bookId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_khata_contact ON khata_entries(contactId)');
  }

  Future<void> _createProductsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        bookId TEXT NOT NULL,
        json TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_book ON products(bookId)');
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        bookId TEXT NOT NULL,
        json TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_categories_book ON categories(bookId)');
  }

  Future<void> _createProductCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_categories (
        id TEXT PRIMARY KEY,
        bookId TEXT NOT NULL,
        json TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_product_categories_book ON product_categories(bookId)');
  }

  // ---------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------

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

  // ---------------------------------------------------------------------
  // Contacts (Customers / Suppliers)
  // ---------------------------------------------------------------------

  Future<void> upsertContact(Contact c) async {
    final database = await db;
    await database.insert(
      'contacts',
      {
        'id': c.id,
        'bookId': c.bookId,
        'json': jsonEncode(c.toMap()),
        'pendingSync': c.pendingSync ? 1 : 0,
        'updatedAt': c.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Contact>> contactsForBook(String bookId, {ContactType? type}) async {
    final database = await db;
    final rows = await database.query(
      'contacts',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'updatedAt DESC',
    );
    return rows
        .map((r) => Contact.fromMap(r['id'] as String, jsonDecode(r['json'] as String)))
        .where((c) => !c.isDeleted && (type == null || c.type == type))
        .toList();
  }

  Future<List<Contact>> pendingSyncContacts() async {
    final database = await db;
    final rows = await database.query('contacts', where: 'pendingSync = 1');
    return rows
        .map((r) => Contact.fromMap(r['id'] as String, jsonDecode(r['json'] as String)))
        .toList();
  }

  Future<void> markContactSynced(String id) async {
    final database = await db;
    await database.update('contacts', {'pendingSync': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------
  // Khata entries (You Gave / You Got)
  // ---------------------------------------------------------------------

  Future<void> upsertKhataEntry(KhataEntry e) async {
    final database = await db;
    await database.insert(
      'khata_entries',
      {
        'id': e.id,
        'bookId': e.bookId,
        'contactId': e.contactId,
        'json': jsonEncode(e.toMap()),
        'pendingSync': e.pendingSync ? 1 : 0,
        'updatedAt': e.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<KhataEntry?> khataEntryById(String id) async {
    final database = await db;
    final rows = await database.query('khata_entries', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final e = KhataEntry.fromMap(rows.first['id'] as String, jsonDecode(rows.first['json'] as String));
    return e.isDeleted ? null : e;
  }

  Future<List<KhataEntry>> khataEntriesForContact(String contactId) async {
    final database = await db;
    final rows = await database.query(
      'khata_entries',
      where: 'contactId = ?',
      whereArgs: [contactId],
    );
    final entries = rows
        .map((r) => KhataEntry.fromMap(r['id'] as String, jsonDecode(r['json'] as String)))
        .where((e) => !e.isDeleted)
        .toList();
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  Future<List<KhataEntry>> khataEntriesForBook(String bookId) async {
    final database = await db;
    final rows = await database.query(
      'khata_entries',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
    return rows
        .map((r) => KhataEntry.fromMap(r['id'] as String, jsonDecode(r['json'] as String)))
        .where((e) => !e.isDeleted)
        .toList();
  }

  Future<List<KhataEntry>> pendingSyncKhataEntries() async {
    final database = await db;
    final rows = await database.query('khata_entries', where: 'pendingSync = 1');
    return rows
        .map((r) => KhataEntry.fromMap(r['id'] as String, jsonDecode(r['json'] as String)))
        .toList();
  }

  Future<void> markKhataEntrySynced(String id) async {
    final database = await db;
    await database.update('khata_entries', {'pendingSync': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------
  // Products
  // ---------------------------------------------------------------------

  Future<void> upsertProduct(Product p) async {
    final database = await db;
    await database.insert(
      'products',
      {
        'id': p.id,
        'bookId': p.bookId,
        'json': jsonEncode(p.toMap()),
        'pendingSync': p.pendingSync ? 1 : 0,
        'updatedAt': p.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Product>> productsForBook(String bookId) async {
    final database = await db;
    final rows = await database.query(
      'products',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'updatedAt DESC',
    );
    return rows
        .map((r) => Product.fromMap(r['id'] as String, jsonDecode(r['json'] as String)))
        .where((p) => !p.isDeleted)
        .toList();
  }

  Future<List<Product>> pendingSyncProducts() async {
    final database = await db;
    final rows = await database.query('products', where: 'pendingSync = 1');
    return rows
        .map((r) => Product.fromMap(r['id'] as String, jsonDecode(r['json'] as String)))
        .toList();
  }

  Future<void> markProductSynced(String id) async {
    final database = await db;
    await database.update('products', {'pendingSync': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------
  // Categories (user-created, in addition to the built-in defaults)
  // ---------------------------------------------------------------------

  Future<void> upsertCategory(Category c) async {
    final database = await db;
    await database.insert(
      'categories',
      {
        'id': c.id,
        'bookId': c.bookId,
        'json': jsonEncode(c.toMap()),
        'pendingSync': c.pendingSync ? 1 : 0,
        'updatedAt': (c.createdAt ?? DateTime.now()).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Category>> categoriesForBook(String bookId) async {
    final database = await db;
    final rows = await database.query(
      'categories',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
    return rows
        .map((r) => Category.fromMap(r['id'] as String, jsonDecode(r['json'] as String)))
        .where((c) => !c.isDeleted)
        .toList();
  }

  Future<List<Category>> pendingSyncCategories() async {
    final database = await db;
    final rows = await database.query('categories', where: 'pendingSync = 1');
    return rows
        .map((r) => Category.fromMap(r['id'] as String, jsonDecode(r['json'] as String)))
        .toList();
  }

  Future<void> markCategorySynced(String id) async {
    final database = await db;
    await database.update('categories', {'pendingSync': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------
  // Product Categories (kept entirely separate from Income/Expense
  // categories above - Products/Services have their own category domain)
  // ---------------------------------------------------------------------

  Future<void> upsertProductCategory(ProductCategory c) async {
    final database = await db;
    await database.insert(
      'product_categories',
      {
        'id': c.id,
        'bookId': c.bookId,
        'json': jsonEncode(c.toMap()),
        'pendingSync': c.pendingSync ? 1 : 0,
        'updatedAt': (c.createdAt ?? DateTime.now()).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ProductCategory>> productCategoriesForBook(String bookId) async {
    final database = await db;
    final rows = await database.query(
      'product_categories',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
    return rows
        .map((r) => ProductCategory.fromMap(r['id'] as String, jsonDecode(r['json'] as String)))
        .where((c) => !c.isDeleted)
        .toList();
  }

  Future<List<ProductCategory>> pendingSyncProductCategories() async {
    final database = await db;
    final rows = await database.query('product_categories', where: 'pendingSync = 1');
    return rows
        .map((r) => ProductCategory.fromMap(r['id'] as String, jsonDecode(r['json'] as String)))
        .toList();
  }

  Future<void> markProductCategorySynced(String id) async {
    final database = await db;
    await database.update('product_categories', {'pendingSync': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
