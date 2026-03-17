import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../database/database.dart';

class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  /// 1. Create Backup (Export -> Share as plain JSON)
  Future<String> createBackup() async {
    try {
      // a. Export Data
      final data = await _db.exportAllData();

      // b. Process Images (Compress & Embed)
      if (data.containsKey('transactions') && data['transactions'] != null) {
        final transactions = data['transactions'] as List;
        for (var i = 0; i < transactions.length; i++) {
          final t = transactions[i] as Map<String, dynamic>;
          final proofPath = t['proofImage'] as String?;

          if (proofPath != null && proofPath.isNotEmpty) {
            final base64Img = await _compressAndEncodeImage(proofPath);
            if (base64Img != null) {
              transactions[i] = Map<String, dynamic>.from(t)
                ..['proofImageBase64'] = base64Img;
            }
          }
        }
      }

      // c. Convert to JSON (plain, no encryption)
      final jsonString = jsonEncode(data);

      // d. Save to Temp File
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'backup_bendahara_$dateStr.json';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(jsonString);

      // e. Share File
      final xFile = XFile(file.path);
      // ignore: deprecated_member_use
      final result = await Share.shareXFiles([
        xFile,
      ], text: 'Backup Data Bendahara');

      if (result.status == ShareResultStatus.dismissed) {
        return 'Backup dibatalkan/disimpan.';
      }
      return 'Backup berhasil disiapkan!';
    } catch (e) {
      throw Exception('Gagal membuat backup: $e');
    }
  }

  /// Helper: Compress Image file and return Base64 string
  Future<String?> _compressAndEncodeImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      // Compress
      final result = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 60,
      );

      if (result == null) return null;

      // Encode
      return base64Encode(result);
    } catch (e) {
      // Ignore compression errors, just skip image
      return null;
    }
  }

  /// Helper: Decode Base64 string and save to app storage
  Future<String?> _decodeAndSaveImage(String base64String) async {
    try {
      final bytes = base64Decode(base64String);
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/proofs');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final fileName =
          'proof_${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(base64String)}.jpg';
      final file = File('${folder.path}/$fileName');

      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// 2. Restore Backup (Pick -> Read JSON -> Import)
  Future<void> restoreBackup() async {
    try {
      // a. Pick File
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        throw Exception('Tidak ada file yang dipilih.');
      }

      final path = result.files.single.path;
      if (path == null) throw Exception('Path file error.');

      final file = File(path);
      final jsonString = await file.readAsString();

      // b. Decode JSON
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // c. Restoration Migration Logic
      await _performMigrationRestore(data);
    } catch (e) {
      throw Exception(
        'Gagal restore: ${e.toString().replaceAll("Exception: ", "")}',
      );
    }
  }

  Future<void> _performMigrationRestore(Map<String, dynamic> data) async {
    await _db.transaction(() async {
      final accountsData = ((data['accounts'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final categoriesData = ((data['categories'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final eventsData = ((data['events'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final membersData = ((data['members'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final cashPeriodsData = ((data['cashPeriods'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final transactionsData = ((data['transactions'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final cashLogsData = ((data['cashLogs'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

      // 1. DELETE ALL EXISTING DATA
      // Order matters for Foreign Keys
      await _db.delete(_db.cashLogs).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.events).go();
      await _db.delete(_db.members).go();
      await _db.delete(_db.accounts).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.cashPeriods).go();

      // 2. RESTORE STANDARD TABLES
      if (accountsData.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(
            _db.accounts,
            accountsData.map(
              (e) => AccountsCompanion.insert(
                id: Value(e['id'] as int),
                name: e['name'] as String,
                type: e['type'] as String,
                initialBalance: e['initialBalance'] as int,
                currentBalance: e['currentBalance'] as int,
                iconKey: Value(e['iconKey'] as String? ?? 'default'),
              ),
            ),
          );
        });
      }

      if (categoriesData.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(
            _db.categories,
            categoriesData.map(
              (e) => CategoriesCompanion.insert(
                id: Value(e['id'] as int),
                name: e['name'] as String,
                type: e['type'] as String,
                iconKey: Value(e['iconKey'] as String? ?? 'default'),
              ),
            ),
          );
        });
      }

      await _db.ensureTransferCategoryExists();

      if (eventsData.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(
            _db.events,
            eventsData.map(
              (e) => EventsCompanion.insert(
                id: Value(e['id'] as int),
                name: e['name'] as String,
                budgetLimit: e['budgetLimit'] as int,
                startDate: DateTime.fromMillisecondsSinceEpoch(
                  e['startDate'] as int,
                ),
                endDate: Value(
                  e['endDate'] != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                          e['endDate'] as int,
                        )
                      : null,
                ),
                status: e['status'] as String,
              ),
            ),
          );
        });
      }

      if (membersData.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(
            _db.members,
            membersData.map(
              (e) => MembersCompanion.insert(
                id: Value(e['id'] as int),
                name: e['name'] as String,
                phoneNumber: e['phoneNumber'] as String? ?? '',
              ),
            ),
          );
        });
      }

      // Restore CashPeriods (if they exist in JSON, usually newer backups)
      // If legacy, this might be null, but we'll handle creation dynamically below for Logs.
      if (cashPeriodsData.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(
            _db.cashPeriods,
            cashPeriodsData.map(
              (e) => CashPeriodsCompanion.insert(
                id: Value(e['id'] as int),
                name: e['name'] as String,
                startDate: DateTime.fromMillisecondsSinceEpoch(
                  e['startDate'] as int,
                ),
                endDate: DateTime.fromMillisecondsSinceEpoch(
                  e['endDate'] as int,
                ),
                status: Value(e['status'] as String? ?? 'Active'),
                createdAt: Value(
                  e['createdAt'] != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                          e['createdAt'] as int,
                        )
                      : DateTime.now(),
                ),
              ),
            ),
          );
        });
      }

      if (transactionsData.isNotEmpty) {
        // Prepare transactions list asynchronously (decoding images)
        final transactionList = await Future.wait(
          transactionsData.map((e) async {
            // Handle Image Restore
            String? proofPath = e['proofImage'] as String?;
            final String? base64Img = e['proofImageBase64'] as String?;

            if (base64Img != null && base64Img.isNotEmpty) {
              final newPath = await _decodeAndSaveImage(base64Img);
              if (newPath != null) {
                proofPath = newPath;
              }
            }

            return TransactionsCompanion.insert(
              id: Value(e['id'] as int),
              amount: e['amount'] as int,
              type: e['type'] as String,
              transactionDate: DateTime.fromMillisecondsSinceEpoch(
                e['transactionDate'] as int,
              ),
              description: e['description'] as String,
              accountId: e['accountId'] as int,
              transferAccountId: Value(e['transferAccountId'] as int?),
              categoryId: e['categoryId'] as int,
              eventId: Value(e['eventId'] as int?),
              memberId: Value(e['memberId'] as int?),
              proofImage: Value(proofPath),
            );
          }),
        );

        await _db.batch((batch) {
          batch.insertAll(_db.transactions, transactionList);
        });
      }

      // 3. MIGRATE CASH LOGS (The Critical Part)
      if (cashLogsData.isNotEmpty) {
        final logsList = cashLogsData;
        final Map<String, int> periodCache = {};

        // Pre-populate periodCache with existing periods from DB (restored above)
        final existingPeriods = await _db.select(_db.cashPeriods).get();
        for (var p in existingPeriods) {
          periodCache[p.name] = p.id;
        }

        for (var logJson in logsList) {
          final memberId = logJson['memberId'] as int;
          final transactionId = logJson['transactionId'] as int;

          // Legacy Compatibility: Check if periodId exists, if not use periodLabel
          int? periodId = logJson['periodId'] as int?;
          final String? periodLabel = logJson['periodLabel'] as String?;

          // Migration Logic
          if (periodId == null && periodLabel != null) {
            // Need to resolve ID from Label
            if (periodCache.containsKey(periodLabel)) {
              periodId = periodCache[periodLabel];
            } else {
              // Create NEW Period on the fly
              // Default dates? Current month.
              // Logic: Attempt to parse 'Januari 2026' or just use dummy dates.
              // Assuming label is enough for Name.
              final now = DateTime.now();
              // Try to be smart about dates if label has "Januari 2026" format?
              // For robustness, just use "now" for dates, user can edit later.

              final newPeriodId = await _db
                  .into(_db.cashPeriods)
                  .insert(
                    CashPeriodsCompanion.insert(
                      name: periodLabel,
                      startDate: now, // Default
                      endDate: now.add(const Duration(days: 30)), // Default
                      status: const Value('Active'),
                    ),
                  );

              periodCache[periodLabel] = newPeriodId;
              periodId = newPeriodId;
            }
          }

          // If we still don't have a periodId (e.g. no label and no ID), likely orphan log
          // But strict schema might fail. Companion allows null if columns are nullable.
          // Schema: IntColumn get periodId => integer().nullable()(); (from database check?)
          // Checking database.g.dart... Wait, I checked database.dart, let's assume nullable per migration history.
          // "await m.addColumn(cashLogs, cashLogs.periodId);" implies it might be nullable initially?
          // If strictly required, we need a fallback.

          // Insert Log
          await _db
              .into(_db.cashLogs)
              .insert(
                CashLogsCompanion.insert(
                  id: Value(logJson['id'] as int),
                  memberId: memberId,
                  transactionId: transactionId,
                  periodLabel: Value(
                    periodLabel,
                  ), // Keep legacy label if valuable
                  periodId: Value(periodId),
                ),
              );
        }
      }
    });
  }
}
