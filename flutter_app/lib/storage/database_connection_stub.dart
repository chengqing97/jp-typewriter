import 'package:drift/drift.dart';

/// Fails clearly on platforms for which no database implementation exists.
QueryExecutor openConnection() {
  throw UnsupportedError('No Drift database implementation for this platform.');
}
