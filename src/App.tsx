import { useCallback, useMemo, useState } from "react";
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

const defaultValue: Descendant[] = [
  {
    type: "paragraph",
    children: [{ text: "A line of text in a paragraph." }],
  },
];

export default function App() {
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
      <div
        style={{
          minHeight: "100vh",
          display: "flex",
          flexDirection: "column",
          backgroundColor: "whitesmoke",
          alignItems: "center",
        }}
      >
        <Toolbar />

        <Editable
          renderElement={renderElement}
          renderLeaf={renderLeaf}
          spellCheck={false}
          style={{
            flex: 1,
            width: 800,
            maxWidth: "100%",
            padding: 45,
            margin: 50,
            outline: "none",
            backgroundColor: "white",
            textAlign: "left",
            lineHeight: 1.1,
            boxSizing: "border-box",
            userSelect: "none",
            borderRadius: 7,
          }}
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

function ParagraphElement(props: RenderElementProps) {
  return <p {...props.attributes}>{...props.children}</p>;
}

function CodeElement(props: RenderElementProps) {
  return <pre {...props.attributes}>{...props.children}</pre>;
}

function SlurElement(props: RenderElementProps) {
  return (
    <span {...props.attributes} style={{ position: "relative" }}>
      {...props.children}
      <span
        style={{
          position: "absolute",
          left: 7,
          right: 7,
          height: 10,
          bottom: 10,
          borderTop: "1px solid black",
          borderRadius: 5,
        }}
      />
    </span>
  );
}

function withSlur(editor: Editor) {
  const { isInline } = editor;
  editor.isInline = (e) => (e.type === "slur" ? true : isInline(e));
  return editor;
}
