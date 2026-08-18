import { Editor, Element, Transforms } from "slate";
import { useSlate } from "slate-react";

export default function Toolbar() {
  const editor = useSlate();

  function toggleMono() {
    const [match] = Editor.nodes(
      editor,
      { match: (n) => Element.isElement(n) && n.type === "code" },
    );
    Transforms.setNodes(
      editor,
      { type: match ? "paragraph" : "code" },
      { match: (n) => Element.isElement(n) && Editor.isBlock(editor, n) },
    );
  }

  function handleOctave(value: -1 | 1) {
    const marks = Editor.marks(editor);
    if (!marks) return;
    const newValue = (marks.octave ?? 0) + value;
    Editor.addMark(editor, "octave", newValue);
  }

  function handleBeam(value: -1 | 1) {
    const marks = Editor.marks(editor);
    if (!marks) return;
    const newValue = (marks.beam ?? 0) + value;
    if (newValue < 0) return;
    Editor.addMark(editor, "beam", newValue);
  }

  function addSlur() {
    if (!editor.selection) return;
    Transforms.wrapNodes(
      editor,
      { type: "slur", children: [] },
      { at: editor.selection, split: true },
    );
  }

  function clear() {
    Editor.removeMark(editor, "beam");
    Editor.removeMark(editor, "octave");
  }

  function open() {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = ".json,application/json";
    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) return;
      const text = await file.text();
      const value = JSON.parse(text);
      Transforms.removeNodes(editor, {
        at: {
          anchor: Editor.start(editor, []),
          focus: Editor.end(editor, []),
        },
      });
      Transforms.insertNodes(editor, value, { at: [0] });
    };
    input.click();
  }

  function save() {
    const json = JSON.stringify(editor.children, null, 2);
    const blob = new Blob([json], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "jianpu.json";
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "row",
        boxSizing: "border-box",
        padding: 20,
        gap: 10,
      }}
    >
      <button onClick={toggleMono}>Mono</button>
      <button onClick={editor.undo}>Undo</button>
      <button onClick={editor.redo}>Redo</button>
      <button onClick={() => handleOctave(1)}>Oct+</button>
      <button onClick={() => handleOctave(-1)}>Oct-</button>
      <button onClick={() => handleBeam(1)}>Line+</button>
      <button onClick={() => handleBeam(-1)}>Line-</button>
      <button onClick={addSlur}>Slur/Tie</button>
      <button onClick={clear}>Clear</button>
      <div style={{ flex: 1 }} />
      <button onClick={open}>Open</button>
      <button onClick={save}>Save</button>
    </div>
  );
}
