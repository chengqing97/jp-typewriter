import {
  LuArrowDown,
  LuArrowLeft,
  LuArrowRight,
  LuArrowUp,
  LuKeyboard,
} from "react-icons/lu";
import styles from "./VirtualKeyboard.module.css";
import { useEffect, useRef, useState } from "react";
import { Transforms, Range } from "slate";
import { useSlate } from "slate-react";
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
    const { selection } = editor;
    if (!selection) return;

    const reverse = direction === "ArrowLeft" || direction === "ArrowUp";

    if (!shift && Range.isExpanded(selection)) {
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
          edge: reverse ? "start" : "end",
        });
      }
      return;
    }

    Transforms.move(editor, {
      distance: 1,
      unit: ctrl
        ? "word"
        : direction === "ArrowLeft" || direction === "ArrowRight"
          ? "character"
          : "line",
      reverse,
      ...(shift ? { edge: "focus" as const } : {}),
    });
  }

  function arrowButton(direction: Direction, icon: React.ReactNode) {
    return (
      <button
        type="button"
        className={styles.arrowButton}
        onPointerDown={(e) => {
          e.preventDefault();
          moveCursor(direction);
        }}
      >
        {icon}
      </button>
    );
  }
  if (!isFocused) return null;
  return (
    <>
      {/* Left: Modifier keys */}
      {keyboardVisible && (
        <div className={styles.leftWrapper}>
          <div className={styles.modifierContainer}>
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
        </div>
      )}

      {/* Right: Toggle + Arrow keys */}
      <div className={styles.rightWrapper}>
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
          <div className={styles.arrowContainer}>
            {arrowButton("ArrowLeft", <LuArrowLeft />)}

            <div className={styles.arrowColumn}>
              {arrowButton("ArrowUp", <LuArrowUp />)}
              {arrowButton("ArrowDown", <LuArrowDown />)}
            </div>

            {arrowButton("ArrowRight", <LuArrowRight />)}
          </div>
        )}
      </div>
    </>
  );
}
