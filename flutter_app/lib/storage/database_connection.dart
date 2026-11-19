import 'package:drift/drift.dart';

import 'database_connection_stub.dart'
    if (dart.library.ffi) 'database_connection_native.dart'
    if (dart.library.js_interop) 'database_connection_web.dart' as platform;

/// Selects a database implementation at compile time so web builds never
/// import dart:io or dart:ffi-backed SQLite code.
QueryExecutor openConnection() => platform.openConnection();
