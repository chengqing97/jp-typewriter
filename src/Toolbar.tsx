import styles from "./Toolbar.module.css";
import { Editor, Element, Transforms } from "slate";
import { useSlate } from "slate-react";
import { useState, type ButtonHTMLAttributes } from "react";
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
  LuSuperscript,
} from "react-icons/lu";
import { ID, Permission, Role, useAppwrite, useUser } from "@appwrite.io/react";
import type { JianpuDoc, SaveState } from "./types";
import { useEditorContext } from "./useEditorContext";
import { DATABASE_ID, DEFAULT_TITLE } from "./constants";
import { SideMenuButton } from "./SideMenu";
import DeleteDialog from "./DeleteDialog";
import { sortDocs } from "./utils/sortDocs";

export default function Toolbar() {
  const editor = useSlate();
  const { user } = useUser();
  const { tablesDB } = useAppwrite();
  const {
    editableRef,
    currentDoc,
    loadState,
    title,
    docs,
    setDocs,
    setCurrentDoc,
    setTitle,
    saveState,
    setSaveState,
    currentSortIndex,
  } = useEditorContext();
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);

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
      CustomEditor.setChildren(editor, JSON.parse(text));
      localStorage.setItem("currentDoc", text);
      setCurrentDoc(null);
      setTitle(file.name.split(".")[0]);
      setSaveState("unsaved");
    };
    input.click();
  }

  function downloadJSON() {
    const title = currentDoc?.title ?? CustomEditor.getTitle(editor);
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
    setSaveState("saving");
    try {
      const response = await tablesDB.upsertRow<JianpuDoc>({
        databaseId: DATABASE_ID,
        tableId: "documents",
        rowId: currentDoc?.$id ?? ID.unique(),
        data: {
          title: title,
          content: JSON.stringify(editor.children),
        },
        permissions: [
          Permission.read(Role.user(user.$id)),
          Permission.update(Role.user(user.$id)),
          Permission.delete(Role.user(user.$id)),
        ],
      });
      setDocs((docs) => {
        if (!docs) return null;
        let updated = false;
        const updatedDocs = docs.map((doc) => {
          if (doc.$id == response.$id) {
            updated = true;
            return response;
          } else {
            return doc;
          }
        });
        if (updated) {
          return updatedDocs;
        } else {
          updatedDocs.push(response);
          return sortDocs(updatedDocs, currentSortIndex);
        }
      });
      setCurrentDoc(response);
      setSaveState("saved");
    } catch (e) {
      window.alert(e);
      setSaveState("unsaved");
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
    const title = currentDoc?.title ?? CustomEditor.getTitle(editor);

    pdf.addImage(img, "PNG", 0, 0, 210, 297);
    pdf.save(title + ".pdf");
  }

  return (
    <div className={styles.layout}>
      <div className={styles.fixedContainer}>
        <SideMenuButton />
        <input
          className={styles.title}
          value={title}
          onChange={(e) => {
            setTitle(e.currentTarget.value);
            if (e.currentTarget.value == currentDoc?.title) {
              setSaveState("saved");
            } else {
              setSaveState("unsaved");
            }
          }}
          onFocus={() => {
            const derivedTitle = CustomEditor.getTitle(editor);
            if (title === DEFAULT_TITLE && derivedTitle.trim() !== "") {
              setTitle(derivedTitle);
            }
          }}
          onKeyUp={(e) => {
            if (e.code == "Enter" && !e.nativeEvent.isComposing) {
              save();
              e.currentTarget.blur();
            }
          }}
        />
        <TextButton
          className={styles.textButton}
          onClick={save}
          disabled={
            saveState == "saved" ||
            saveState == "saving" ||
            loadState != "loaded"
          }
        >
          {getSaveButtonText(saveState)}
        </TextButton>
        <TextButton className={styles.textButton} onClick={uploadJSON}>
          Upload
        </TextButton>
        <TextButton className={styles.textButton} onClick={downloadJSON}>
          Inspect
        </TextButton>
        <TextButton className={styles.textButton} onClick={exportPDF}>
          Download
        </TextButton>
        {currentDoc && (
          <TextButton
            className={styles.textButton}
            onClick={() => setShowDeleteDialog(true)}
          >
            Delete
          </TextButton>
        )}
        <div style={{ flex: 1 }} />
        {docs === null ? <p className={styles.statusText}>Loading</p> : null}
      </div>
      <div className={styles.floatingContainer}>
        <div className={styles.buttonGroup}>
          <IconButton onClick={toggleMono}>
            <LuType />
          </IconButton>
          <IconButton onClick={editor.undo}>
            <LuUndo2 />
          </IconButton>
          <IconButton onClick={editor.redo}>
            <LuRedo2 />
          </IconButton>
        </div>
        <div className={styles.line} />
        <div className={styles.buttonGroup}>
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
          <IconButton onClick={() => CustomEditor.toggleSuperscript(editor)}>
            <LuSuperscript />
          </IconButton>
          <IconButton onClick={() => CustomEditor.clearFormat(editor)}>
            <LuRemoveFormatting />
          </IconButton>
        </div>
        <div className={styles.line} />
        <div className={styles.buttonGroup}>
          <IconButton onClick={() => insertText("𝄆")}>𝄆</IconButton>
          <IconButton onClick={() => insertText("𝄋")}>𝄋</IconButton>
          <IconButton onClick={() => insertText("𝄌")}>𝄌</IconButton>
          <IconButton onClick={() => insertText("𝄍")}>𝄍</IconButton>
          <IconButton onClick={() => insertText("𝄎")}>𝄎</IconButton>
          <IconButton onClick={() => insertText("𝄏")}>𝄏</IconButton>
          <IconButton onClick={() => insertText("𝄇")}>𝄇</IconButton>
          <IconButton onClick={() => insertText("𝄁")}>𝄁</IconButton>
          <IconButton onClick={() => insertText("𝄂")}>𝄂</IconButton>
        </div>
      </div>
      {showDeleteDialog && (
        <DeleteDialog onDismiss={() => setShowDeleteDialog(false)} />
      )}
    </div>
  );
}
function TextButton(props: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      className={styles.textButton}
      onMouseDown={(e) => e.preventDefault()}
      {...props}
    />
  );
}

function IconButton(props: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      className={styles.iconButton}
      onMouseDown={(e) => e.preventDefault()}
      {...props}
    />
  );
}

function getSaveButtonText(saveState: SaveState) {
  switch (saveState) {
    case "init":
      return "Save";
    case "unsaved":
      return "Save*";
    case "saved":
      return "Saved";
    case "saving":
      return "Saving";
  }
}
