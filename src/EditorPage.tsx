import styles from "./EditorPage.module.css";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createEditor, Range } from "slate";
import {
  Editable,
  type RenderElementProps,
  type RenderLeafProps,
  Slate,
  withReact,
} from "slate-react";
import type { Descendant } from "slate";
import TopBar from "./TopBar";
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
import Toolbar from "./Toolbar";

const defaultValue: Descendant[] = [
  {
    type: "code",
    children: [{ text: "A line of text in a paragraph." }],
  },
];

const A4_RATIO = 210 / 297;

export default function EditorPage() {
  const editableRef = useRef<HTMLDivElement>(null);
  const { paperRef, currentDoc, setSaveState } = useEditorContext();

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
      const paper = paperRef.current;
      if (!editable || !paper) return;

      const h = editable.scrollHeight;
      const w = editable.scrollWidth;

      if (w / h > A4_RATIO) {
        paper.style.maxHeight = w / A4_RATIO + "px";
        paper.style.minHeight = w / A4_RATIO + "px";
        paper.style.maxWidth = w + "px";
        paper.style.minWidth = w + "px";
      } else {
        paper.style.maxHeight = h + "px";
        paper.style.minHeight = h + "px";
        paper.style.maxWidth = h * A4_RATIO + "px";
        paper.style.minWidth = h * A4_RATIO + "px";
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
      <div className={styles.layout}>
        <TopBar />
        <Toolbar />
        <div className={styles.body}>
          <div className={styles.backdrop}>
            <div ref={paperRef} className={styles.paper}>
              <Editable
                ref={editableRef}
                className={styles.editable}
                renderElement={renderElement}
                renderLeaf={renderLeaf}
                autoFocus
                spellCheck={false}
                onKeyDown={(e) => {
                  const ctrlKey = e.metaKey || e.ctrlKey;
                  if (ctrlKey && e.key == "=") {
                    e.preventDefault();
                    CustomEditor.gapUp(editor);
                    return;
                  }
                  if (ctrlKey && e.key == "-") {
                    e.preventDefault();
                    CustomEditor.gapDown(editor);
                    return;
                  }
                  if (ctrlKey && e.key == "s") {
                    e.preventDefault();
                    CustomEditor.toggleSuperscript(editor);
                    return;
                  }
                  if (!editor.selection) return;
                  if (Range.isCollapsed(editor.selection)) return;
                  if (ctrlKey && e.key == "ArrowUp") {
                    e.preventDefault();
                    CustomEditor.octaveUp(editor);
                    return;
                  }
                  if (ctrlKey && e.key == "ArrowDown") {
                    e.preventDefault();
                    CustomEditor.octaveDown(editor);
                    return;
                  }
                  if (ctrlKey && e.key == "ArrowLeft") {
                    e.preventDefault();
                    CustomEditor.beamUp(editor);
                    return;
                  }
                  if (ctrlKey && e.key == "ArrowRight") {
                    e.preventDefault();
                    CustomEditor.beamDown(editor);
                    return;
                  }
                  if (ctrlKey && e.key == "a") {
                    e.preventDefault();
                    CustomEditor.toggleSlur(editor);
                    return;
                  }
                  if (ctrlKey && e.key == "d") {
                    e.preventDefault();
                    CustomEditor.clearFormat(editor);
                    return;
                  }
                  if (ctrlKey && e.key == "i") {
                    e.preventDefault();
                    CustomEditor.toggleItalic(editor);
                    return;
                  }
                }}
              />
            </div>
          </div>
        </div>
      </div>
    </Slate>
  );
}
