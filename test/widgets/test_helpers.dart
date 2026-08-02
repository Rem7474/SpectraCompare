import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spectra_compare/core/storage/database.dart';

/// A fresh, in-memory, ffi-backed `AppDatabase` for widget tests — no device
/// needed (see plan's `sqflite_common_ffi` rationale). Call `sqfliteFfiInit()`
/// once per test file (e.g. in `setUpAll`) before using this.
///
/// Uses `databaseFactoryFfiNoIsolate` rather than `databaseFactoryFfi`:
/// `testWidgets`' `pumpAndSettle` runs inside a fake-async zone that can
/// drain microtasks but never resolves real cross-isolate messages, so the
/// isolate-hopping factory hangs forever mid-query under `pumpAndSettle`.
/// The no-isolate factory runs queries as plain synchronous-then-microtask
/// calls, which the fake-async zone handles fine.
AppDatabase testAppDatabase() {
  return AppDatabase(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
}
