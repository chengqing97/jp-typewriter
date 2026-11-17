# Flutter Jianpu editor prototype

This is an isolated Flutter prototype alongside the existing React/Slate app.
It does not replace or modify the current application.

## Run

```sh
cd flutter_app
flutter pub get
flutter run
```

## Current scope

- One Flutter `EditableText` surface (not one field per character).
- Physical keyboard text editing and Flutter-managed caret/selection.
- A4-proportioned paper preview.
- Jianpu digit input toolbar and select-all.
- A framework-independent Jianpu run/document model.
- Local SQLite document storage with automatic debounced saving.
- Document drawer with create, open, rename, and delete actions.

## Next engineering steps

1. Add widget and persistence tests for document lifecycle and editing.
2. Add pagination and import/export compatibility with the existing Slate JSON.
3. Add the Supabase sync layer on top of the local-first document repository.
4. Add collaboration features after sync is validated.

The prototype is intentionally small. It is an editing-behaviour spike, not yet
a feature-complete migration.
