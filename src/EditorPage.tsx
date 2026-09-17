import styles from "./EditorPage.module.css";
import { useCallback, useEffect, useMemo, useState } from "react";
import { createEditor, Range } from "slate";
import {
  Editable,
  type RenderElementProps,
  type RenderLeafProps,
  Slate,
  withReact,
} from "slate-react";
import type { Descendant } from "slate";
import Toolbar from "./Toolbar";
import { withHistory } from "slate-history";
import { CustomLeaf } from "./CustomLeaf";
import { CustomEditor } from "./CustomEditor";
import {
  CodeElement,
  ParagraphElement,
  SlurElement,
  withSlur,
} from "./CustomElements";
import { useEditorContext } from "./useEditorContext";

const defaultValue: Descendant[] = [
  {
    type: "code",
    children: [{ text: "A line of text in a paragraph." }],
  },
];

const A4_RATIO = 210 / 297;

export default function EditorPage() {
  const { editableRef, currentDoc, setSaveState } = useEditorContext();

  const [editor] = useState(() =>
    withSlur(withReact(withHistory(createEditor()))),
  );

  const initialValue = useMemo(() => {
    const jsonString = localStorage.getItem("content");
    if (!jsonString) {
      return defaultValue;
    }
    return JSON.parse(jsonString);
  }, []);

  const renderElement = useCallback((props: RenderElementProps) => {
    switch (props.element.type) {
      case "paragraph":
        return <ParagraphElement {...props} />;
      case "code":
        return <CodeElement {...props} />;
      case "slur":
        return <SlurElement {...props} />;
    }
  }, []);

  const renderLeaf = useCallback((props: RenderLeafProps) => {
    return <CustomLeaf {...props} />;
  }, []);

  const resizePaper = useCallback(() => {
    requestAnimationFrame(() => {
      const editable = editableRef.current;
      if (!editable) return;

      editable.style.height = "auto";
      editable.style.width = "auto";

      const h = editable.scrollHeight;
      const w = editable.scrollWidth;

      if (w / h > A4_RATIO) {
        editable.style.height = w / A4_RATIO + "px";
      } else {
        editable.style.width = h * A4_RATIO + "px";
      }
    });
  }, []);

  useEffect(() => {
    resizePaper();
  }, [currentDoc]);

  return (
    <Slate
      editor={editor}
      initialValue={initialValue}
      onValueChange={(value) => {
        resizePaper();
        const content = JSON.stringify(value);
        localStorage.setItem("content", content);
        setSaveState(content === currentDoc?.content ? "saved" : "unsaved");
      }}
    >
      <Toolbar />
      <div className={styles.layout}>
        <Editable
          ref={editableRef}
          className={styles.editable}
          renderElement={renderElement}
          renderLeaf={renderLeaf}
          autoFocus
          spellCheck={false}
          onKeyDown={(e) => {
            if (!editor.selection) return;
            if (Range.isCollapsed(editor.selection)) return;
            if (e.ctrlKey && e.key == "ArrowUp") {
              e.preventDefault();
              CustomEditor.octaveUp(editor);
              return;
            }
            if (e.ctrlKey && e.key == "ArrowDown") {
              e.preventDefault();
              CustomEditor.octaveDown(editor);
              return;
            }
            if (e.ctrlKey && e.key == "ArrowLeft") {
              e.preventDefault();
              CustomEditor.beamUp(editor);
              return;
            }
            if (e.ctrlKey && e.key == "ArrowRight") {
              e.preventDefault();
              CustomEditor.beamDown(editor);
              return;
            }
            if (e.ctrlKey && e.key == "a") {
              e.preventDefault();
              CustomEditor.toggleSlur(editor);
              return;
            }
            if (e.ctrlKey && e.key == "s") {
              e.preventDefault();
              CustomEditor.toggleSuperscript(editor);
              return;
            }
            if (e.ctrlKey && e.key == "d") {
              e.preventDefault();
              CustomEditor.clearFormat(editor);
              return;
            }
          }}
        />
      </div>
    </Slate>
  );
}
