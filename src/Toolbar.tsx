import { Editor, Transforms } from "slate";
import { useSlate } from "slate-react";

export default function Toolbar() {
  const editor = useSlate();

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
    Transforms.wrapNodes(editor, { type: "slur", children: [] }, {
      at: editor.selection,
      split: true,
    });
  }

  function clear() {
    Editor.removeMark(editor, "beam");
    Editor.removeMark(editor, "octave");
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
      <button onClick={() => handleOctave(1)}>Oct+</button>
      <button onClick={() => handleOctave(-1)}>Oct-</button>
      <button onClick={() => handleBeam(1)}>Line+</button>
      <button onClick={() => handleBeam(-1)}>Line-</button>
      <button onClick={addSlur}>Slur/Tie</button>
      <button onClick={clear}>Clear</button>
    </div>
  );
}
