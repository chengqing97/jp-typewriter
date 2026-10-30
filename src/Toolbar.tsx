import styles from "./Toolbar.module.css";
import type { ButtonHTMLAttributes } from "react";
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
import { useSlate } from "slate-react";
import { Editor, Element, Transforms } from "slate";
import { CustomEditor } from "./CustomEditor";

export default function Toolbar() {
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

  function insertText(text: string) {
    Transforms.insertText(editor, text);
  }

  return (
    <div className={styles.layout}>
      <div className={styles.container}>
        <div className={styles.buttonGroup}>
          <IconButton onClick={toggleMono}>
            <LuType />
          </IconButton>
          <IconButton
            disabled={editor.history.undos.length == 0}
            onClick={editor.undo}
          >
            <LuUndo2 />
          </IconButton>
          <IconButton
            disabled={editor.history.redos.length == 0}
            onClick={editor.redo}
          >
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
    </div>
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
