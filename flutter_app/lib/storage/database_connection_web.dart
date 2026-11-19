import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Browser-backed SQLite using Drift's WebAssembly runtime. The database is
/// persisted by Drift using the best storage API supported by the browser.
QueryExecutor openConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'jianpu_documents',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
      return result.resolvedExecutor;
    }),
  );
}
