import {
  LuArrowDown,
  LuArrowLeft,
  LuArrowRight,
  LuArrowUp,
  LuKeyboard,
} from "react-icons/lu";
import styles from "./VirtualKeyboard.module.css";
import { useRef, useState } from "react";
import { Transforms, Range, Editor, Element } from "slate";
import { useSlate } from "slate-react";
import { useEditorContext } from "./useEditorContext";
import { handleCopy, handleCut, handlePaste } from "./utils/copyPaste";

type Direction = "ArrowLeft" | "ArrowRight" | "ArrowUp" | "ArrowDown";

export default function VirtualKeyboard() {
  const editor = useSlate();
  const { editableRef, isFocused, keyboardVisible, toggleKeyboard } =
    useEditorContext();

  const [leftShift, setLeftShift] = useState(false);
  const [leftCtrl, setLeftCtrl] = useState(false);
  const [rightShift, setRightShift] = useState(false);
  const [rightCtrl, setRightCtrl] = useState(false);

  function moveCursor(direction: Direction) {
    const { selection: editorSelection } = editor;
    const windowSelection = window.getSelection();
    const [block] = Editor.nodes(editor, {
      match: (n) => Element.isElement(n) && Editor.isBlock(editor, n),
    });

    if (!editorSelection) return;
    if (!windowSelection) return;
    if (!block) return;

    const shift = leftShift || rightShift;
    const ctrl = leftCtrl || rightCtrl;

    if (!shift && Range.isExpanded(editorSelection)) {
      if (ctrl) {
        editableRef.current?.dispatchEvent(
          new KeyboardEvent("keydown", {
            key: direction,
            code: direction,
            bubbles: true,
            cancelable: true,
            shiftKey: shift,
            ctrlKey: ctrl,
          }),
        );
      } else {
        Transforms.collapse(editor, {
          edge:
            direction === "ArrowLeft" || direction === "ArrowUp"
              ? "start"
              : "end",
        });
      }
      return;
    }

    if (ctrl) {
      switch (direction) {
        case "ArrowUp":
          Transforms.move(editor, {
            distance: 1,
            unit: "line",
            reverse: true,
            edge: shift ? "focus" : undefined,
          });
          break;
        case "ArrowDown":
          Transforms.move(editor, {
            distance: 1,
            unit: "line",
            reverse: false,
            edge: shift ? "focus" : undefined,
          });
          break;
        case "ArrowLeft":
          Transforms.move(editor, {
            distance: 1,
            unit: "word",
            reverse: true,
            edge: shift ? "focus" : undefined,
          });
          break;
        case "ArrowRight":
          Transforms.move(editor, {
            distance: 1,
            unit: "word",
            reverse: false,
            edge: shift ? "focus" : undefined,
          });
          break;
      }
      return;
    }

    switch (direction) {
      case "ArrowUp":
        windowSelection.modify(shift ? "extend" : "move", "backward", "line");
        break;
      case "ArrowDown":
        windowSelection.modify(shift ? "extend" : "move", "forward", "line");
        break;
      case "ArrowLeft":
        Transforms.move(editor, {
          distance: 1,
          unit: "character",
          reverse: true,
          edge: shift ? "focus" : undefined,
        });
        break;
      case "ArrowRight":
        Transforms.move(editor, {
          distance: 1,
          unit: "character",
          reverse: false,
          edge: shift ? "focus" : undefined,
        });
        break;
    }
  }
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  function stopMoving() {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
      timeoutRef.current = null;
    }

    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }

  function arrowButton(direction: Direction, icon: React.ReactNode) {
    return (
      <button
        type="button"
        className={styles.arrowButton}
        onPointerDown={(e) => {
          e.preventDefault();

          moveCursor(direction); // Immediate movement

          timeoutRef.current = setTimeout(() => {
            intervalRef.current = setInterval(() => {
              moveCursor(direction);
            }, 35);
          }, 200);
        }}
        onPointerUp={stopMoving}
        onPointerLeave={stopMoving}
        onPointerCancel={stopMoving}
      >
        {icon}
      </button>
    );
  }
  if (!isFocused) return null;
  return (
    <div className={styles.layout}>
      <button
        type="button"
        className={styles.toggleButton}
        onPointerDown={(e) => e.preventDefault()}
        onClick={toggleKeyboard}
        aria-label={
          keyboardVisible ? "Hide virtual keyboard" : "Show virtual keyboard"
        }
        aria-expanded={keyboardVisible}
      >
        <LuKeyboard />
      </button>
      {keyboardVisible && (
        <div className={styles.keyboardContainer}>
          <div className={styles.group1}>
            <button
              type="button"
              className={`${styles.modifierButton} ${
                leftShift ? styles.active : ""
              }`}
              onPointerDown={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setLeftShift(true);
              }}
              onPointerUp={() => setLeftShift(false)}
            >
              Shift
            </button>
            <button
              type="button"
              className={`${styles.modifierButton} ${
                leftCtrl ? styles.active : ""
              }`}
              onPointerDown={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setLeftCtrl(true);
              }}
              onPointerUp={() => setLeftCtrl(false)}
            >
              Ctrl
            </button>
          </div>
          <div style={{ flex: 1 }} />

          <div className={styles.group2}>
            <button
              type="button"
              className={styles.actionButton}
              onPointerDown={(e) => {
                e.preventDefault();
                e.stopPropagation();
                handleCut(editor);
              }}
            >
              Cut
            </button>
            <button
              type="button"
              className={styles.actionButton}
              onPointerDown={(e) => {
                e.preventDefault();
                e.stopPropagation();
                handleCopy(editor);
              }}
            >
              Copy
            </button>
            <button
              type="button"
              className={styles.actionButton}
              onPointerDown={async (e) => {
                e.preventDefault();
                e.stopPropagation();
                handlePaste(editor);
              }}
            >
              Paste
            </button>
          </div>

          <div style={{ flex: 1 }} />
          <div className={styles.group3}>
            <button
              type="button"
              className={`${styles.modifierButton} ${
                rightShift ? styles.active : ""
              }`}
              onPointerDown={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setRightShift((x) => !x);
              }}
            >
              Shift
            </button>
            <button
              type="button"
              className={`${styles.modifierButton} ${
                rightCtrl ? styles.active : ""
              }`}
              onPointerDown={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setRightCtrl((x) => !x);
              }}
            >
              Ctrl
            </button>
          </div>
          <div className={styles.group4}>
            {arrowButton("ArrowLeft", <LuArrowLeft />)}

            <div className={styles.arrowColumn}>
              {arrowButton("ArrowUp", <LuArrowUp />)}
              {arrowButton("ArrowDown", <LuArrowDown />)}
            </div>

            {arrowButton("ArrowRight", <LuArrowRight />)}
          </div>
        </div>
      )}
    </div>
  );
}
