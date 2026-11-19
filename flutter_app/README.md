# Flutter Jianpu editor prototype

This is an isolated Flutter prototype alongside the existing React/Slate app.
It does not replace or modify the current application.

## Run

```sh
cd flutter_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Run the isolated SuperEditor spacing prototype

This is a separate entrypoint. It leaves the existing editor unchanged and
starts with sample Jianpu lines so paragraph spacing, cross-paragraph
selection, typing, and keyboard navigation can be evaluated independently.

```sh
cd flutter_app
flutter pub get
flutter run -t lib/main_super_editor_prototype.dart
```

The prototype currently tests paragraph-level spacing only. It does not yet
load existing Jianpu documents or migrate octave dots, beams, slurs, clipboard,
undo/redo, or persistence.

### Run in a browser

Drift uses SQLite compiled to WebAssembly on the web. Download the matching
runtime assets once (and again whenever the resolved Drift version changes):

```sh
bash tool/download_drift_web_assets.sh
flutter run -d chrome
```

The script downloads `sqlite3.wasm` and `drift_worker.js` for Drift 2.35.4 into
`web/`. Keep the script version aligned with the `drift` version in
`pubspec.lock`. The browser database is separate from the native
`jianpu_documents.db`; browser documents are stored by the browser's local
storage implementation and do not automatically transfer between devices.

For a production web deployment, ensure `.wasm` files are served with the
`application/wasm` MIME type. Drift can fall back to IndexedDB-backed storage
when the browser does not support its preferred file-system APIs.

Drift generates the typed database implementation in
`lib/storage/app_database.g.dart`. Run the code-generation command after
changing the Drift tables or database annotations.

## Current scope

- One Flutter `EditableText` surface (not one field per character).
- Physical keyboard text editing and Flutter-managed caret/selection.
- A4-proportioned paper preview.
- Jianpu digit input toolbar and select-all.
- A framework-independent Jianpu run/document model.
- Local SQLite persistence through Drift, with reactive document-list updates.
- Document drawer with create, open, rename, and delete actions.
- Existing `jianpu_documents.db` documents are retained when moving from
  sqflite repository access to Drift.

## Next engineering steps

1. Add widget and persistence tests for document lifecycle and editing.
2. Add pagination and import/export compatibility with the existing Slate JSON.
3. Add the Supabase sync layer on top of the local-first document repository.
4. Add collaboration features after sync is validated.

The prototype is intentionally small. It is an editing-behaviour spike, not yet
a feature-complete migration.
