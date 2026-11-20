import styles from "./TopBar.module.css";
import { useSlate } from "slate-react";
import { useState, type ButtonHTMLAttributes } from "react";
import { CustomEditor } from "./CustomEditor";
import type { SaveState } from "./types";
import { useEditorContext } from "./useEditorContext";
import { DEFAULT_TITLE, OFFLINE_MODE } from "./constants";
import { SideBarButton } from "./SideBar";
import DeleteDialog from "./DeleteDialog";
import { handleExport } from "./utils/exportPDF";

export default function TopBar() {
  const editor = useSlate();
  const {
    paperRef,
    currentDoc,
    loadState,
    title,
    docs,
    setCurrentDoc,
    setTitle,
    saveState,
    setSaveState,
    save,
  } = useEditorContext();
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);

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

  async function exportPDF() {
    const div = paperRef.current;
    if (!div) return;
    const filename = currentDoc?.title ?? CustomEditor.getTitle(editor);
    handleExport(div, filename);
  }

  return (
    <div className={styles.container}>
      {!OFFLINE_MODE && <SideBarButton />}
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
        onKeyDown={(e) => {
          if (e.code == "Enter" && !e.nativeEvent.isComposing) {
            save(editor);
            e.currentTarget.blur();
          }
        }}
      />
      <TextButton
        className={styles.textButton}
        onClick={() => save(editor)}
        disabled={
          saveState == "saved" || saveState == "saving" || loadState != "loaded"
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
      <p className={styles.statusText}>
        {OFFLINE_MODE ? "Offline" : docs === null ? "Loading" : ""}
      </p>
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
