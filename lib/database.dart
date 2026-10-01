import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'security_service.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  final _aes = AesGcm.with256bits();

  Future<String> get _databasePath async =>
      p.join(await getDatabasesPath(), 'secure_docs.db');

  Future<Database> open() async {
    if (_db != null && _db!.isOpen) return _db!;
    final dbKey = await SecurityService.instance.getDatabaseKey();
    if (dbKey == null || dbKey.isEmpty) {
      throw StateError('Database encryption key is missing.');
    }

    _db = await openDatabase(
      await _databasePath,
      password: dbKey,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_documents_owner ON documents(owner_name COLLATE NOCASE)',
          );
        }
      },
    );
    return _db!;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE document_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference_no TEXT NOT NULL UNIQUE,
        owner_name TEXT NOT NULL,
        document_type_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(document_type_id) REFERENCES document_types(id)
          ON DELETE RESTRICT ON UPDATE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE document_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        image_order INTEGER NOT NULL,
        file_name TEXT,
        mime_type TEXT,
        sha256 TEXT NOT NULL,
        image_blob BLOB NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_documents_type ON documents(document_type_id)');
    await db.execute('CREATE INDEX idx_documents_owner ON documents(owner_name COLLATE NOCASE)');
    await db.execute('CREATE INDEX idx_images_doc ON document_images(document_id, image_order)');

    final now = DateTime.now().toIso8601String();
    for (final name in ['Aadhaar', 'Medical', 'Education', 'PAN', 'Passport', 'Other']) {
      await db.insert('document_types', {
        'name': name,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) await db.close();
  }

  Future<List<DocumentType>> getDocumentTypes() async {
    final db = await open();
    final rows = await db.rawQuery('''
      SELECT dt.id, dt.name,
             (SELECT COUNT(*) FROM documents d WHERE d.document_type_id = dt.id) AS record_count
      FROM document_types dt
      ORDER BY dt.name COLLATE NOCASE
    ''');
    return rows.map(DocumentType.fromMap).toList();
  }

  Future<bool> documentTypeExists(int id) async {
    final db = await open();
    final rows = await db.rawQuery(
      'SELECT 1 FROM document_types WHERE id = ? LIMIT 1',
      [id],
    );
    return rows.isNotEmpty;
  }

  Future<bool> documentTypeNameExists(String name, {int? excludingId}) async {
    final clean = name.trim();
    if (clean.isEmpty) return false;
    final db = await open();
    final rows = excludingId == null
        ? await db.rawQuery(
            'SELECT 1 FROM document_types WHERE name = ? COLLATE NOCASE LIMIT 1',
            [clean],
          )
        : await db.rawQuery(
            'SELECT 1 FROM document_types WHERE name = ? COLLATE NOCASE AND id <> ? LIMIT 1',
            [clean, excludingId],
          );
    return rows.isNotEmpty;
  }

  Future<int> addDocumentType(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Document type cannot be empty.');
    if (await documentTypeNameExists(clean)) {
      throw ArgumentError('A document type with this name already exists.');
    }
    final db = await open();
    final now = DateTime.now().toIso8601String();
    return db.insert('document_types', {
      'name': clean,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> editDocumentType(int id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Document type cannot be empty.');
    if (await documentTypeNameExists(clean, excludingId: id)) {
      throw ArgumentError('A document type with this name already exists.');
    }
    final db = await open();
    final changed = await db.update(
      'document_types',
      {'name': clean, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed != 1) {
      throw StateError('Document type was not found.');
    }
  }

  Future<bool> deleteDocumentType(int id) async {
    final db = await open();
    final count = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM documents WHERE document_type_id = ?',
            [id],
          ),
        ) ??
        0;
    if (count > 0) return false;
    await db.delete('document_types', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  Future<String> createDocument({
    required String ownerName,
    required int documentTypeId,
    required List<PickedImageData> images,
  }) async {
    final owner = ownerName.trim();
    if (owner.isEmpty) throw ArgumentError('Owner name is required.');
    if (images.isEmpty || images.length > 5) {
      throw ArgumentError('Each document must have between 1 and 5 images.');
    }

    final db = await open();
    final ref = _newReference();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final typeRows = await txn.rawQuery(
        'SELECT 1 FROM document_types WHERE id = ? LIMIT 1',
        [documentTypeId],
      );
      if (typeRows.isEmpty) {
        throw StateError('The selected document type no longer exists. Please choose it again.');
      }

      final docId = await txn.insert('documents', {
        'reference_no': ref,
        'owner_name': owner,
        'document_type_id': documentTypeId,
        'created_at': now,
        'updated_at': now,
      });
      for (var i = 0; i < images.length; i++) {
        await _insertImage(txn, docId, i + 1, images[i], now);
      }
    });
    return ref;
  }

  Future<List<DocumentListItem>> getDocuments({
    String query = '',
    int? typeId,
  }) async {
    final db = await open();
    final where = <String>[];
    final args = <Object?>[];
    final clean = query.trim();
    if (clean.isNotEmpty) {
      where.add('(d.owner_name LIKE ? OR d.reference_no LIKE ? OR dt.name LIKE ?)');
      final q = '%$clean%';
      args.addAll([q, q, q]);
    }
    if (typeId != null) {
      where.add('d.document_type_id = ?');
      args.add(typeId);
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT d.id, d.reference_no, d.owner_name, d.document_type_id,
             dt.name AS document_type, d.created_at, d.updated_at,
             (SELECT COUNT(*) FROM document_images i WHERE i.document_id = d.id) AS image_count
      FROM documents d
      JOIN document_types dt ON dt.id = d.document_type_id
      $whereSql
      ORDER BY d.updated_at DESC, d.id DESC
    ''', args);
    return rows.map(DocumentListItem.fromMap).toList();
  }

  Future<DocumentListItem?> getDocument(int id) async {
    final db = await open();
    final rows = await db.rawQuery('''
      SELECT d.id, d.reference_no, d.owner_name, d.document_type_id,
             dt.name AS document_type, d.created_at, d.updated_at,
             (SELECT COUNT(*) FROM document_images i WHERE i.document_id = d.id) AS image_count
      FROM documents d
      JOIN document_types dt ON dt.id = d.document_type_id
      WHERE d.id = ?
      LIMIT 1
    ''', [id]);
    return rows.isEmpty ? null : DocumentListItem.fromMap(rows.first);
  }

  Future<List<StoredImage>> getImages(int documentId) async {
    final db = await open();
    final rows = await db.query(
      'document_images',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'image_order',
    );
    return rows.map(StoredImage.fromMap).toList();
  }

  Future<void> updateDocument({
    required int id,
    required String ownerName,
    required int documentTypeId,
  }) async {
    final clean = ownerName.trim();
    if (clean.isEmpty) throw ArgumentError('Owner name is required.');
    final db = await open();
    await db.transaction((txn) async {
      final typeRows = await txn.rawQuery(
        'SELECT 1 FROM document_types WHERE id = ? LIMIT 1',
        [documentTypeId],
      );
      if (typeRows.isEmpty) {
        throw StateError('The selected document type no longer exists. Please choose it again.');
      }
      final changed = await txn.update(
        'documents',
        {
          'owner_name': clean,
          'document_type_id': documentTypeId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed != 1) {
        throw StateError('Document was not found.');
      }
    });
  }

  Future<void> addImages(int documentId, List<PickedImageData> images) async {
    if (images.isEmpty) return;
    final db = await open();
    await db.transaction((txn) async {
      final docRows = await txn.rawQuery(
        'SELECT 1 FROM documents WHERE id = ? LIMIT 1',
        [documentId],
      );
      if (docRows.isEmpty) {
        throw StateError('Document was not found.');
      }
      if (images.any((image) => image.bytes.isEmpty)) {
        throw ArgumentError('One of the selected pictures is empty or unreadable.');
      }
      final count = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM document_images WHERE document_id = ?',
            [documentId],
          )) ??
          0;
      if (count + images.length > 5) {
        throw ArgumentError('Maximum 5 images are allowed per document.');
      }
      final now = DateTime.now().toIso8601String();
      for (var i = 0; i < images.length; i++) {
        await _insertImage(txn, documentId, count + i + 1, images[i], now);
      }
      await txn.update(
        'documents',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [documentId],
      );
    });
  }

  Future<DeleteImageResult> deleteImage(int imageId, int documentId) async {
    final db = await open();
    return db.transaction((txn) async {
      final docRows = await txn.rawQuery(
        'SELECT 1 FROM documents WHERE id = ? LIMIT 1',
        [documentId],
      );
      if (docRows.isEmpty) return DeleteImageResult.notFound;

      final imageRows = await txn.rawQuery(
        'SELECT 1 FROM document_images WHERE id = ? AND document_id = ? LIMIT 1',
        [imageId, documentId],
      );
      if (imageRows.isEmpty) return DeleteImageResult.notFound;

      final count = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM document_images WHERE document_id = ?',
            [documentId],
          )) ??
          0;

      if (count <= 1) {
        await txn.delete('documents', where: 'id = ?', whereArgs: [documentId]);
        return DeleteImageResult.documentDeleted;
      }

      await txn.delete(
        'document_images',
        where: 'id = ? AND document_id = ?',
        whereArgs: [imageId, documentId],
      );
      await _normalizeImageOrder(txn, documentId);
      await txn.update(
        'documents',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [documentId],
      );
      return DeleteImageResult.imageDeleted;
    });
  }

  Future<void> moveImage(int documentId, int imageId, int delta) async {
    if (delta == 0) return;
    final db = await open();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'document_images',
        columns: ['id'],
        where: 'document_id = ?',
        whereArgs: [documentId],
        orderBy: 'image_order',
      );
      final ids = rows.map((e) => e['id'] as int).toList();
      final current = ids.indexOf(imageId);
      if (current < 0) return;
      final target = current + delta;
      if (target < 0 || target >= ids.length) return;
      final temp = ids[current];
      ids[current] = ids[target];
      ids[target] = temp;
      for (var i = 0; i < ids.length; i++) {
        await txn.update(
          'document_images',
          {'image_order': i + 1},
          where: 'id = ?',
          whereArgs: [ids[i]],
        );
      }
      await txn.update(
        'documents',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [documentId],
      );
    });
  }

  Future<void> deleteDocument(int id) async {
    final db = await open();
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<DatabaseStats> getStats() async {
    final db = await open();
    final docs = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM documents')) ?? 0;
    final images = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM document_images')) ?? 0;
    final types = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM document_types')) ?? 0;
    final file = File(await _databasePath);
    final bytes = await file.exists() ? await file.length() : 0;
    return DatabaseStats(documents: docs, images: images, types: types, bytes: bytes);
  }

  Future<File> createEncryptedBackup(String backupPassword) async {
    if (backupPassword.length < 8) {
      throw ArgumentError('Backup password must be at least 8 characters.');
    }
    await open();
    await close();
    try {
      final dbFile = File(await _databasePath);
      if (!await dbFile.exists()) throw StateError('Database file not found.');
      final dbKey = await SecurityService.instance.getDatabaseKey();
      if (dbKey == null) throw StateError('Database key not found.');

      final inner = utf8.encode(jsonEncode({
        'format': 'secure-doc-backup-inner-v1',
        'dbKey': dbKey,
        'db': base64Encode(await dbFile.readAsBytes()),
      }));

      final salt = SecurityService.instance.randomBytes(16);
      final nonce = SecurityService.instance.randomBytes(12);
      final keyBytes = await SecurityService.instance.deriveBackupKey(backupPassword, salt);
      final box = await _aes.encrypt(
        inner,
        secretKey: SecretKey(keyBytes),
        nonce: nonce,
      );
      final outer = {
        'format': 'secure-doc-backup-v1',
        'createdAt': DateTime.now().toIso8601String(),
        'salt': base64Encode(salt),
        'nonce': base64Encode(box.nonce),
        'cipherText': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      };

      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final out = File(p.join(dir.path, 'secure-doc-backup-$stamp.sdbak'));
      await out.writeAsString(jsonEncode(outer), flush: true);
      return out;
    } finally {
      await open();
    }
  }

  Future<void> restoreEncryptedBackup(String backupPath, String backupPassword) async {
    final file = File(backupPath);
    if (!await file.exists()) throw ArgumentError('Backup file does not exist.');
    final outer = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (outer['format'] != 'secure-doc-backup-v1') {
      throw const FormatException('Unsupported backup format.');
    }

    final salt = base64Decode(outer['salt'] as String);
    final nonce = base64Decode(outer['nonce'] as String);
    final cipher = base64Decode(outer['cipherText'] as String);
    final mac = base64Decode(outer['mac'] as String);
    final keyBytes = await SecurityService.instance.deriveBackupKey(backupPassword, salt);
    final clear = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(keyBytes),
    );
    final inner = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    if (inner['format'] != 'secure-doc-backup-inner-v1') {
      throw const FormatException('Backup payload is invalid.');
    }
    final restoredKey = inner['dbKey'] as String;
    final restoredDb = base64Decode(inner['db'] as String);
    final originalKey = await SecurityService.instance.getDatabaseKey();

    await close();
    final dbPath = await _databasePath;
    final target = File(dbPath);
    final safety = File('$dbPath.pre-restore');
    final wal = File('$dbPath-wal');
    final shm = File('$dbPath-shm');
    if (await target.exists()) await target.copy(safety.path);
    if (await wal.exists()) await wal.delete();
    if (await shm.exists()) await shm.delete();
    try {
      await target.writeAsBytes(restoredDb, flush: true);
      await SecurityService.instance.setDatabaseKey(restoredKey);
      await open();
      await getStats();
      final restored = await open();
      final invalidCount = Sqflite.firstIntValue(await restored.rawQuery('''
        SELECT COUNT(*)
        FROM documents d
        WHERE (SELECT COUNT(*) FROM document_images i WHERE i.document_id = d.id) < 1
           OR (SELECT COUNT(*) FROM document_images i WHERE i.document_id = d.id) > 5
      ''')) ?? 0;
      if (invalidCount > 0) {
        throw StateError('Backup contains documents outside the required 1–5 picture range.');
      }
      if (await safety.exists()) await safety.delete();
    } catch (e) {
      await close();
      if (await safety.exists()) await safety.copy(target.path);
      if (originalKey != null && originalKey.isNotEmpty) {
        await SecurityService.instance.setDatabaseKey(originalKey);
      }
      rethrow;
    } finally {
      if (_db == null) {
        try {
          await open();
        } catch (_) {}
      }
    }
  }

  Future<void> _insertImage(
    DatabaseExecutor db,
    int documentId,
    int order,
    PickedImageData image,
    String now,
  ) async {
    if (image.bytes.isEmpty) throw ArgumentError('Empty image is not allowed.');
    await db.insert('document_images', {
      'document_id': documentId,
      'image_order': order,
      'file_name': image.fileName,
      'mime_type': image.mimeType,
      'sha256': await _sha256Hex(image.bytes),
      'image_blob': image.bytes,
      'created_at': now,
    });
  }

  Future<void> _normalizeImageOrder(DatabaseExecutor db, int documentId) async {
    final rows = await db.query(
      'document_images',
      columns: ['id'],
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'image_order, id',
    );
    for (var i = 0; i < rows.length; i++) {
      await db.update(
        'document_images',
        {'image_order': i + 1},
        where: 'id = ?',
        whereArgs: [rows[i]['id']],
      );
    }
  }

  String _newReference() {
    final d = DateTime.now();
    final date = '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final token = const Uuid().v4().replaceAll('-', '').substring(0, 8).toUpperCase();
    return 'DOC-$date-$token';
  }

  Future<String> _sha256Hex(List<int> bytes) async {
    final digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

enum DeleteImageResult { imageDeleted, documentDeleted, notFound }

class DocumentType {
  final int id;
  final String name;
  final int recordCount;
  const DocumentType({required this.id, required this.name, required this.recordCount});
  factory DocumentType.fromMap(Map<String, Object?> m) => DocumentType(
        id: m['id'] as int,
        name: m['name'] as String,
        recordCount: (m['record_count'] as int?) ?? 0,
      );
}

class PickedImageData {
  final Uint8List bytes;
  final String fileName;
  final String? mimeType;
  PickedImageData({required this.bytes, required this.fileName, this.mimeType});
}

class DocumentListItem {
  final int id;
  final String referenceNo;
  final String ownerName;
  final int documentTypeId;
  final String documentType;
  final int imageCount;
  final String createdAt;
  final String updatedAt;
  const DocumentListItem({
    required this.id,
    required this.referenceNo,
    required this.ownerName,
    required this.documentTypeId,
    required this.documentType,
    required this.imageCount,
    required this.createdAt,
    required this.updatedAt,
  });
  factory DocumentListItem.fromMap(Map<String, Object?> m) => DocumentListItem(
        id: m['id'] as int,
        referenceNo: m['reference_no'] as String,
        ownerName: m['owner_name'] as String,
        documentTypeId: m['document_type_id'] as int,
        documentType: m['document_type'] as String,
        imageCount: (m['image_count'] as int?) ?? 0,
        createdAt: m['created_at'] as String,
        updatedAt: m['updated_at'] as String,
      );
}

class StoredImage {
  final int id;
  final int order;
  final String sha256Value;
  final Uint8List bytes;
  final String? fileName;
  final String? mimeType;
  StoredImage({
    required this.id,
    required this.order,
    required this.sha256Value,
    required this.bytes,
    this.fileName,
    this.mimeType,
  });
  factory StoredImage.fromMap(Map<String, Object?> m) => StoredImage(
        id: m['id'] as int,
        order: m['image_order'] as int,
        sha256Value: m['sha256'] as String,
        bytes: m['image_blob'] as Uint8List,
        fileName: m['file_name'] as String?,
        mimeType: m['mime_type'] as String?,
      );
}

class DatabaseStats {
  final int documents;
  final int images;
  final int types;
  final int bytes;
  const DatabaseStats({
    required this.documents,
    required this.images,
    required this.types,
    required this.bytes,
  });
}
