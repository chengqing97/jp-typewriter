import styles from "./Toolbar.module.css";
import { Editor, Element, Transforms } from "slate";
import { useSlate } from "slate-react";
import type { HTMLAttributes, RefObject } from "react";
import { CustomEditor } from "./CustomEditor";
import html2canvas from "html2canvas";
import jsPDF from "jspdf";

type Props = {
  editableRef: RefObject<HTMLDivElement | null>;
};

export default function Toolbar(props: Props) {
  const editor = useSlate();

  function toggleMono() {
    const [match] = Editor.nodes(editor, {
      match: (n) => Element.isElement(n) && n.type === "code",
    });
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

  function insertText(text: string) {
    Transforms.insertText(editor, text);
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
    const title = CustomEditor.getTitle(editor);
    const json = JSON.stringify(editor.children, null, 2);
    const blob = new Blob([json], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = title + ".json";
    a.click();
    URL.revokeObjectURL(url);
  }

  async function exportPDF() {
    const div = props.editableRef.current;
    if (!div) return;

    const canvas = await html2canvas(div, {
      scale: 2,
      useCORS: true,
    });

    const width = div.offsetWidth;
    const height = div.offsetHeight;

    const pdf = new jsPDF({
      orientation: width > height ? "landscape" : "portrait",
      unit: "px",
      format: [width, height],
    });

    const img = canvas.toDataURL("image/png");
    const title = CustomEditor.getTitle(editor);

    pdf.addImage(img, "PNG", 0, 0, width, height);
    pdf.save(title + ".pdf");
  }

  return (
    <div className={styles.container}>
      <div className={styles.column}>
        <div className={styles.row}>
          <ToolbarButton onClick={toggleMono}>Mono</ToolbarButton>
          <ToolbarButton onClick={editor.undo}>Undo</ToolbarButton>
          <ToolbarButton onClick={editor.redo}>Redo</ToolbarButton>
          <ToolbarButton onClick={() => CustomEditor.octaveDown(editor)}>
            Oct-
          </ToolbarButton>
          <ToolbarButton onClick={() => CustomEditor.octaveUp(editor)}>
            Oct+
          </ToolbarButton>
          <ToolbarButton onClick={() => CustomEditor.beamDown(editor)}>
            Line-
          </ToolbarButton>
          <ToolbarButton onClick={() => CustomEditor.beamUp(editor)}>
            Line+
          </ToolbarButton>
          <ToolbarButton onClick={() => CustomEditor.toggleSlur(editor)}>
            Slur/Tie
          </ToolbarButton>
          <ToolbarButton onClick={() => CustomEditor.toggleSuperscript(editor)}>
            Sup
          </ToolbarButton>
          <ToolbarButton onClick={clear}>Clear</ToolbarButton>
        </div>
        <div className={styles.row}>
          <ToolbarButton onClick={() => insertText("𝄆")}>𝄆</ToolbarButton>
          <ToolbarButton onClick={() => insertText("𝄋")}>𝄋</ToolbarButton>
          <ToolbarButton onClick={() => insertText("𝄌")}>𝄌</ToolbarButton>
          <ToolbarButton onClick={() => insertText("𝄍")}>𝄍</ToolbarButton>
          <ToolbarButton onClick={() => insertText("𝄎")}>𝄎</ToolbarButton>
          <ToolbarButton onClick={() => insertText("𝄏")}>𝄏</ToolbarButton>
          <ToolbarButton onClick={() => insertText("𝄇")}>𝄇</ToolbarButton>
          <ToolbarButton onClick={() => insertText("𝄂")}>𝄂</ToolbarButton>
          <div style={{ width: 20 }} />
          <ToolbarButton onClick={open}>Open</ToolbarButton>
          <ToolbarButton onClick={save}>Save</ToolbarButton>
          <ToolbarButton onClick={exportPDF}>Export</ToolbarButton>
        </div>
      </div>
    </div>
  );
}

function ToolbarButton(props: HTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      className={styles.button}
      onMouseDown={(e) => e.preventDefault()}
      {...props}
    />
  );
}
