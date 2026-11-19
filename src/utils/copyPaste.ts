import { type Descendant, Editor, Range, Transforms } from "slate";
import { ReactEditor } from "slate-react";

const SLATE_FRAGMENT_MIME = "application/x-slate-fragment";

function encodeSlateFragment(fragment: Descendant[]): string {
  const json = JSON.stringify(fragment);
  // UTF-8 safe base64 encoding
  const bytes = new TextEncoder().encode(json);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function decodeSlateFragment(encoded: string): Descendant[] | null {
  if (!encoded) return null;
  try {
    const binary = atob(encoded);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    const json = new TextDecoder().decode(bytes);
    const parsed = JSON.parse(json);
    return Array.isArray(parsed) ? (parsed as Descendant[]) : null;
  } catch {
    return null;
  }
}

/**
 * Copies the current Slate selection to the system clipboard
 * as both a rich Slate fragment and plain text.
 */
export async function copy(
  editor: Editor,
  savedSelection?: Range | null,
): Promise<boolean> {
  const selection = editor.selection ?? savedSelection ?? null;
  if (!selection || Range.isCollapsed(selection)) {
    return false;
  }

  const fragment = Editor.fragment(editor, selection);
  const plainText = Editor.string(editor, selection);

  if (!fragment.length && !plainText) {
    return false;
  }

  ReactEditor.focus(editor);
  if (!editor.selection && savedSelection) {
    Transforms.select(editor, savedSelection);
  }

  try {
    if (
      navigator.clipboard &&
      typeof ClipboardItem !== "undefined" &&
      typeof navigator.clipboard.write === "function"
    ) {
      const encodedFragment = encodeSlateFragment(fragment);
      const item = new ClipboardItem({
        "text/plain": new Blob([plainText], { type: "text/plain" }),
        [SLATE_FRAGMENT_MIME]: new Blob([encodedFragment], {
          type: "text/plain",
        }),
      });
      await navigator.clipboard.write([item]);
      return true;
    }

    if (
      navigator.clipboard &&
      typeof navigator.clipboard.writeText === "function"
    ) {
      await navigator.clipboard.writeText(plainText);
      return true;
    }
  } catch (err) {
    console.error("Slate copy() failed:", err);
  }

  return false;
}

/**
 * Pastes from the system clipboard into Slate, preferring a rich
 * Slate fragment and falling back to plain text.
 */
export async function paste(
  editor: Editor,
  savedSelection?: Range | null,
): Promise<boolean> {
  ReactEditor.focus(editor);
  if (!editor.selection && savedSelection) {
    Transforms.select(editor, savedSelection);
  }

  try {
    // 1. Try reading rich Slate fragment via Clipboard API
    if (navigator.clipboard && typeof navigator.clipboard.read === "function") {
      const items = await navigator.clipboard.read();
      for (const item of items) {
        if (item.types.includes(SLATE_FRAGMENT_MIME)) {
          const blob = await item.getType(SLATE_FRAGMENT_MIME);
          const encoded = await blob.text();
          const fragment = decodeSlateFragment(encoded);

          if (fragment && fragment.length > 0) {
            Transforms.insertFragment(editor, fragment);
            return true;
          }
        }
      }
    }

    // 2. Fallback to plain text
    if (
      navigator.clipboard &&
      typeof navigator.clipboard.readText === "function"
    ) {
      const text = await navigator.clipboard.readText();
      if (text) {
        Transforms.insertText(editor, text);
        return true;
      }
    }
  } catch (err) {
    console.error("Slate paste() failed:", err);
  }

  return false;
}
