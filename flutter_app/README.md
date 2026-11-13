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

## Next engineering steps

1. Add widget tests for vertical movement, wrapped lines, selection and editing.
2. Implement a document-aware editing controller that preserves formatting runs
   while text is inserted, deleted, pasted and selected.
3. Render octave dots, beams, superscript and slurs without inserting
   caret-interactive WidgetSpans into the text flow.
4. Add pagination and import/export compatibility with the existing Slate JSON.
5. Port account, cloud storage and collaboration features after the editing
   engine is validated.

The prototype is intentionally small. It is an editing-behaviour spike, not yet
a feature-complete migration.
