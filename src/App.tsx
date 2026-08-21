import styles from "./App.module.css";
import { useCallback, useMemo, useRef, useState } from "react";
import { createEditor, Editor, Transforms } from "slate";
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
import { Leaf } from "./Leaf";
import { CustomEditor } from "./CustomEditor";
import {
  CodeElement,
  ParagraphElement,
  SlurElement,
  withSlur,
} from "./SlateElements";

const defaultValue: Descendant[] = [
  {
    type: "paragraph",
    children: [{ text: "A line of text in a paragraph." }],
  },
];

export default function App() {
  const editableRef = useRef<HTMLDivElement>(null);
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
    return <Leaf {...props} />;
  }, []);

  return (
    <Slate
      editor={editor}
      initialValue={initialValue}
      onChange={(value) => {
        const isAstChange = editor.operations.some(
          (op) => "set_selection" !== op.type,
        );
        if (isAstChange) {
          const content = JSON.stringify(value);
          localStorage.setItem("content", content);
        }
      }}
    >
      <Toolbar editableRef={editableRef} />
      <div className={styles.layout}>
        <Editable
          ref={editableRef}
          className={styles.editable}
          renderElement={renderElement}
          renderLeaf={renderLeaf}
          spellCheck={false}
          onKeyDown={(e) => {
            if (e.ctrlKey && e.key == "a") {
              e.preventDefault();
              Transforms.select(editor, {
                anchor: Editor.start(editor, []),
                focus: Editor.end(editor, []),
              });
              return;
            }
            if (e.altKey && e.key == "ArrowUp") {
              e.preventDefault();
              CustomEditor.octaveUp(editor);
              return;
            }
            if (e.altKey && e.key == "ArrowDown") {
              e.preventDefault();
              CustomEditor.octaveDown(editor);
              return;
            }
            if (e.altKey && e.key == "ArrowRight") {
              e.preventDefault();
              CustomEditor.beamUp(editor);
              return;
            }
            if (e.altKey && e.key == "ArrowLeft") {
              e.preventDefault();
              CustomEditor.beamDown(editor);
              return;
            }
            if (e.altKey && e.key == "s") {
              e.preventDefault();
              CustomEditor.toggleSlur(editor);
              return;
            }
          }}
        />
      </div>
    </Slate>
  );
}
