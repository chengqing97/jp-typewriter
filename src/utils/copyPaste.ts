import { Editor, Node, Transforms } from "slate";
import { ReactEditor } from "slate-react";

export async function handleCut(editor: Editor) {
  if (!editor.selection) return;

  const data = new DataTransfer();
  ReactEditor.setFragmentData(editor, data, "cut");

  const fragment = Editor.fragment(editor, editor.selection);
  const plainText = fragment.map((node) => Node.string(node)).join("\n");
  data.setData("text/plain", plainText);

  try {
    await navigator.clipboard.write([
      new ClipboardItem({
        "text/plain": new Blob([data.getData("text/plain")], {
          type: "text/plain",
        }),
        "text/html": new Blob([data.getData("text/html")], {
          type: "text/html",
        }),
      }),
    ]);

    Transforms.delete(editor);
  } catch (err) {
    console.error("custom cut failed");
    document.execCommand("cut");
  }
}

export async function handleCopy(editor: Editor) {
  if (!editor.selection) return;

  const data = new DataTransfer();
  ReactEditor.setFragmentData(editor, data, "copy");

  const fragment = Editor.fragment(editor, editor.selection);
  const plainText = fragment.map((node) => Node.string(node)).join("\n");
  data.setData("text/plain", plainText);

  try {
    await navigator.clipboard.write([
      new ClipboardItem({
        "text/plain": new Blob([data.getData("text/plain")], {
          type: "text/plain",
        }),
        "text/html": new Blob([data.getData("text/html")], {
          type: "text/html",
        }),
        // Note: application/x-slate-fragment is often blocked by the async Clipboard API
        // (especially Safari). The fragment is still embedded in the HTML as data-slate-fragment.
      }),
    ]);
  } catch (err) {
    console.error("custom copy failed");
    document.execCommand("copy");
  }
}

export async function handlePaste(editor: ReactEditor) {
  ReactEditor.focus(editor);

  try {
    const clipboardItems = await navigator.clipboard.read();
    const data = new DataTransfer();

    for (const item of clipboardItems) {
      for (const type of item.types) {
        const blob = await item.getType(type);
        const text = await blob.text();
        data.setData(type, text);
      }
    }
    ReactEditor.insertData(editor, data);
  } catch (err) {
    console.error("custom paste failed");
    document.execCommand("paste");
  }
}
