import { Editor, Element, Transforms } from "slate";
import { useSlate } from "slate-react";
import { CustomEditor } from "./App";
import type { HTMLAttributes } from "react";

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
    const filename = prompt("Enter file name:", "Jianpu");
    if (!filename) return;
    const json = JSON.stringify(editor.children, null, 2);
    const blob = new Blob([json], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename + ".json";
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
      <ToolbarButton onClick={toggleMono}>Mono</ToolbarButton>
      <ToolbarButton onClick={editor.undo}>Undo</ToolbarButton>
      <ToolbarButton onClick={editor.redo}>Redo</ToolbarButton>
      <ToolbarButton onClick={() => CustomEditor.octaveUp(editor)}>
        Oct+
      </ToolbarButton>
      <ToolbarButton onClick={() => CustomEditor.octaveDown(editor)}>
        Oct-
      </ToolbarButton>
      <ToolbarButton onClick={() => CustomEditor.beamUp(editor)}>
        Line+
      </ToolbarButton>
      <ToolbarButton onClick={() => CustomEditor.beamDown(editor)}>
        Line-
      </ToolbarButton>
      <ToolbarButton onClick={() => CustomEditor.toggleSlur(editor)}>
        Slur/Tie
      </ToolbarButton>
      <ToolbarButton onClick={clear}>Clear</ToolbarButton>
      <div style={{ flex: 1 }} />
      <ToolbarButton onClick={open}>Open</ToolbarButton>
      <ToolbarButton onClick={save}>Save</ToolbarButton>
    </div>
  );
}

function ToolbarButton(props: HTMLAttributes<HTMLButtonElement>) {
  return <button onMouseDown={(e) => e.preventDefault()} {...props} />;
}
