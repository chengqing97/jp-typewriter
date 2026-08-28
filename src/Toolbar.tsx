import styles from "./Toolbar.module.css";
import { Editor, Element, Transforms } from "slate";
import { useSlate } from "slate-react";
import { type HTMLAttributes } from "react";
import { CustomEditor } from "./CustomEditor";
import html2canvas from "html2canvas";
import jsPDF from "jspdf";
import {
  LuUndo2,
  LuRedo2,
  LuUnderline,
  LuArrowDownToDot,
  LuArrowUpFromDot,
  LuRemoveFormatting,
  LuRainbow,
  LuType,
  LuPlus,
  LuMinus,
} from "react-icons/lu";
import { ID, Permission, Role, useAppwrite, useUser } from "@appwrite.io/react";
import type { JianpuDoc } from "./types";
import { useEditorContext } from "./useEditorContext";
import { DATABASE_ID } from "./constants";
import { SideMenuButton } from "./SideMenu";

export default function Toolbar() {
  const editor = useSlate();
  const { user } = useUser();
  const { tablesDB } = useAppwrite();
  const { editableRef, currentDoc } = useEditorContext();

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

  function uploadJSON() {
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

  function downloadJSON() {
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

  async function save() {
    if (!user) return;
    try {
      const response = await tablesDB.upsertRow<JianpuDoc>({
        databaseId: DATABASE_ID,
        tableId: "documents",
        rowId: currentDoc?.$id ?? ID.unique(),
        data: {
          title: CustomEditor.getTitle(editor),
          content: JSON.stringify(editor.children),
        },
        permissions: [
          Permission.read(Role.user(user.$id)),
          Permission.update(Role.user(user.$id)),
          Permission.delete(Role.user(user.$id)),
        ],
      });
      window.alert("Saved!");
      console.log("saved", response);
    } catch (e) {
      window.alert(e);
    }
  }

  async function exportPDF() {
    const div = editableRef.current;
    if (!div) return;

    const canvas = await html2canvas(div, {
      scale: 2,
      useCORS: true,
    });

    const width = div.offsetWidth;
    const height = div.offsetHeight;

    const pdf = new jsPDF({
      orientation: width > height ? "landscape" : "portrait",
      unit: "mm",
      format: "a4",
      compress: true,
    });

    const img = canvas.toDataURL("image/jpeg", 0.8);
    const title = CustomEditor.getTitle(editor);

    pdf.addImage(img, "PNG", 0, 0, 210, 297);
    pdf.save(title + ".pdf");
  }

  return (
    <div className={styles.layout}>
      <div className={styles.fixedContainer}>
        <SideMenuButton />
        <input className={styles.title} defaultValue="Untitled" />
        <TextButton className={styles.textButton} onClick={save}>
          Save
        </TextButton>
        <TextButton className={styles.textButton} onClick={() => {}}>
          Save As
        </TextButton>
        <TextButton className={styles.textButton} onClick={downloadJSON}>
          Download
        </TextButton>
        <TextButton className={styles.textButton} onClick={uploadJSON}>
          Import
        </TextButton>
        <TextButton className={styles.textButton} onClick={exportPDF}>
          Export
        </TextButton>
      </div>
      <div className={styles.floatingContainer}>
        <IconButton onClick={toggleMono}>
          <LuType />
        </IconButton>
        <IconButton onClick={editor.undo}>
          <LuUndo2 />
        </IconButton>
        <IconButton onClick={editor.redo}>
          <LuRedo2 />
        </IconButton>
        <div className={styles.line} />
        <IconButton onClick={() => CustomEditor.octaveUp(editor)}>
          <LuArrowUpFromDot />
        </IconButton>
        <IconButton onClick={() => CustomEditor.octaveDown(editor)}>
          <LuArrowDownToDot />
        </IconButton>
        <IconButton onClick={() => CustomEditor.beamDown(editor)}>
          <LuUnderline />
          <LuMinus size={12} />
        </IconButton>
        <IconButton onClick={() => CustomEditor.beamUp(editor)}>
          <LuUnderline />
          <LuPlus size={12} />
        </IconButton>
        <IconButton onClick={() => CustomEditor.toggleSlur(editor)}>
          <LuRainbow />
        </IconButton>
        <IconButton onClick={clear}>
          <LuRemoveFormatting />
        </IconButton>
        <div className={styles.line} />
        <IconButton onClick={() => insertText("𝄆")}>𝄆</IconButton>
        <IconButton onClick={() => insertText("𝄋")}>𝄋</IconButton>
        <IconButton onClick={() => insertText("𝄌")}>𝄌</IconButton>
        <IconButton onClick={() => insertText("𝄍")}>𝄍</IconButton>
        <IconButton onClick={() => insertText("𝄎")}>𝄎</IconButton>
        <IconButton onClick={() => insertText("𝄏")}>𝄏</IconButton>
        <IconButton onClick={() => insertText("𝄇")}>𝄇</IconButton>
        <IconButton onClick={() => insertText("𝄂")}>𝄂</IconButton>
      </div>
    </div>
  );
}
function TextButton(props: HTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      className={styles.textButton}
      onMouseDown={(e) => e.preventDefault()}
      {...props}
    />
  );
}

function IconButton(props: HTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      className={styles.iconButton}
      onMouseDown={(e) => e.preventDefault()}
      {...props}
    />
  );
}
