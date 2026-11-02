import {
  LuArrowDown,
  LuArrowLeft,
  LuArrowRight,
  LuArrowUp,
  LuKeyboard,
} from "react-icons/lu";
import styles from "./VirtualKeyboard.module.css";
import { useEffect, useRef, useState } from "react";
import { Transforms, Range, Editor, Element } from "slate";
import { useSlate, ReactEditor } from "slate-react";
import { useEditorContext } from "./useEditorContext";

type Direction = "ArrowLeft" | "ArrowRight" | "ArrowUp" | "ArrowDown";
type Modifier = "shift" | "ctrl";

export default function VirtualKeyboard() {
  const editor = useSlate();
  const { editableRef, isFocused, keyboardVisible, setKeyboardVisible } =
    useEditorContext();

  const pointers = useRef(new Map<number, Modifier>());
  const [shift, setShift] = useState(false);
  const [ctrl, setCtrl] = useState(false);

  function updateModifiers() {
    const values = [...pointers.current.values()];
    setShift(values.includes("shift"));
    setCtrl(values.includes("ctrl"));
  }

  function pressModifier(e: React.PointerEvent, modifier: Modifier) {
    e.preventDefault();

    pointers.current.set(e.pointerId, modifier);
    updateModifiers();
  }

  useEffect(() => {
    function releaseModifier(e: PointerEvent) {
      if (pointers.current.delete(e.pointerId)) {
        updateModifiers();
      }
    }

    window.addEventListener("pointerup", releaseModifier);
    window.addEventListener("pointercancel", releaseModifier);

    return () => {
      window.removeEventListener("pointerup", releaseModifier);
      window.removeEventListener("pointercancel", releaseModifier);
    };
  }, []);

  function moveCursor(direction: Direction) {
    const { selection: editorSelection } = editor;
    const windowSelection = window.getSelection();
    const [block] = Editor.nodes(editor, {
      match: (n) => Element.isElement(n) && Editor.isBlock(editor, n),
    });

    if (!editorSelection) return;
    if (!windowSelection) return;
    if (!block) return;

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
        onClick={() => setKeyboardVisible((v) => !v)}
        aria-label={
          keyboardVisible ? "Hide virtual keyboard" : "Show virtual keyboard"
        }
        aria-expanded={keyboardVisible}
      >
        <LuKeyboard />
      </button>
      {keyboardVisible && (
        <div className={styles.keyboardContainer}>
          <div className={styles.leftPart}>
            <button
              type="button"
              className={`${styles.modifierButton} ${
                shift ? styles.active : ""
              }`}
              onPointerDown={(e) => pressModifier(e, "shift")}
            >
              Shift
            </button>
            <button
              type="button"
              className={`${styles.modifierButton} ${
                ctrl ? styles.active : ""
              }`}
              onPointerDown={(e) => pressModifier(e, "ctrl")}
            >
              Ctrl
            </button>
          </div>

          <div className={styles.middlePart}>
            <button
              type="button"
              className={styles.actionButton}
              onPointerDown={(e) => {
                e.preventDefault();
                e.stopPropagation();
                ReactEditor.focus(editor);
                const { selection } = editor;
                if (!selection || Range.isCollapsed(selection)) return;
                document.execCommand("cut");
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
                ReactEditor.focus(editor);
                const { selection } = editor;
                if (!selection || Range.isCollapsed(selection)) return;
                document.execCommand("copy");
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
              }}
            >
              Paste
            </button>
          </div>

          <div className={styles.rightPart}>
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
