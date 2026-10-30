import styles from "./Toolbar.module.css";
import { useRef, type ButtonHTMLAttributes } from "react";
import {
  LuUndo2,
  LuRedo2,
  LuUnderline,
  LuArrowDownToDot,
  LuArrowUpFromDot,
  LuRemoveFormatting,
  LuRainbow,
  LuPlus,
  LuMinus,
  LuSuperscript,
  LuArrowUpToLine,
  LuArrowDownToLine,
  LuItalic,
} from "react-icons/lu";
import { useSlate } from "slate-react";
import { Transforms } from "slate";
import { CustomEditor } from "./CustomEditor";

const DRAG_THRESHOLD = 5;

export default function Toolbar() {
  const containerRef = useRef<HTMLDivElement>(null);
  const isDragging = useRef(false);
  const hasDragged = useRef(false);
  const startX = useRef(0);
  const scrollLeft = useRef(0);
  const editor = useSlate();

  function insertText(text: string) {
    Transforms.insertText(editor, text);
  }

  return (
    <div className={styles.layout}>
      <div
        ref={containerRef}
        className={styles.container}
        onWheel={(e) => {
          if (e.deltaY !== 0) {
            e.currentTarget.scrollLeft += e.deltaY;
          }
        }}
        onMouseLeave={() => (isDragging.current = false)}
        onMouseDown={(e) => {
          isDragging.current = true;
          hasDragged.current = false;
          startX.current = e.pageX;
          scrollLeft.current = containerRef.current!.scrollLeft;
        }}
        onMouseMove={(e) => {
          if (!isDragging.current) return;

          const distance = e.pageX - startX.current;

          if (Math.abs(distance) > DRAG_THRESHOLD) {
            hasDragged.current = true;
          }

          if (hasDragged.current) {
            containerRef.current!.scrollLeft = scrollLeft.current - distance;
          }
        }}
        onMouseUp={() => {
          isDragging.current = false;
        }}
        onClickCapture={(e) => {
          if (hasDragged.current) {
            e.preventDefault();
            e.stopPropagation();
            hasDragged.current = false;
          }
        }}
      >
        <div className={styles.buttonGroup}>
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
          <IconButton onClick={() => CustomEditor.toggleItalic(editor)}>
            <LuItalic />
          </IconButton>
          <IconButton onClick={() => CustomEditor.gapDown(editor)}>
            <LuArrowUpToLine />
          </IconButton>
          <IconButton onClick={() => CustomEditor.gapUp(editor)}>
            <LuArrowDownToLine />
          </IconButton>
          <IconButton onClick={() => CustomEditor.octaveDown(editor)}>
            <LuArrowDownToDot />
          </IconButton>
          <IconButton onClick={() => CustomEditor.octaveUp(editor)}>
            <LuArrowUpFromDot />
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
