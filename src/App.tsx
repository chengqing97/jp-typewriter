import { useCallback, useMemo, useState } from "react";
import { createEditor, Editor, Element, Transforms } from "slate";
import {
  Editable,
  type RenderElementProps,
  type RenderLeafProps,
  Slate,
  withReact,
} from "slate-react";
import type { BaseEditor, Descendant } from "slate";
import { ReactEditor } from "slate-react";
import Toolbar from "./Toolbar";
import { HistoryEditor, withHistory } from "slate-history";
import { Leaf } from "./Leaf";

type CustomText = {
  text: string;
  octave?: number;
  beam?: number;
  slur?: number;
};

type ParagraphElement = { type: "paragraph"; children: CustomText[] };
type CodeElement = { type: "code"; children: CustomText[] };
type SlurElement = { type: "slur"; children: CustomText[] };

declare module "slate" {
  interface CustomTypes {
    Editor: BaseEditor & ReactEditor & HistoryEditor;
    Element: ParagraphElement | CodeElement | SlurElement;
    Text: CustomText;
  }
}

const defaultValue: Descendant[] = [
  {
    type: "paragraph",
    children: [{ text: "A line of text in a paragraph." }],
  },
];

export const CustomEditor = {
  octaveUp(editor: Editor) {
    const marks = Editor.marks(editor);
    if (!marks) return;
    const newValue = (marks.octave ?? 0) + 1;
    Editor.addMark(editor, "octave", newValue);
  },

  octaveDown(editor: Editor) {
    const marks = Editor.marks(editor);
    if (!marks) return;
    const newValue = (marks.octave ?? 0) - 1;
    Editor.addMark(editor, "octave", newValue);
  },

  beamUp(editor: Editor) {
    const marks = Editor.marks(editor);
    if (!marks) return;
    const newValue = (marks.beam ?? 0) + 1;
    Editor.addMark(editor, "beam", newValue);
  },

  beamDown(editor: Editor) {
    const marks = Editor.marks(editor);
    if (!marks) return;
    const newValue = (marks.beam ?? 0) - 1;
    if (newValue < 0) return;
    Editor.addMark(editor, "beam", newValue);
  },

  addSlur(editor: Editor) {
    if (!editor.selection) return;

    const [match] = Editor.nodes(editor, {
      match: (n) => Element.isElement(n) && n.type === "slur",
    });

    if (match) {
      Transforms.unwrapNodes(editor, {
        at: editor.selection,
        match: (n) => Element.isElement(n) && n.type === "slur",
      });
    } else {
      Transforms.wrapNodes(
        editor,
        { type: "slur", children: [] },
        { at: editor.selection, split: true },
      );
    }
  },
};

export default function App() {
  const [editor] = useState(() =>
    withSlur(withReact(withHistory(createEditor())))
  );

  const initialValue = useMemo(
    () => {
      const jsonString = localStorage.getItem("content");
      if (!jsonString) {
        return defaultValue;
      }
      return JSON.parse(jsonString);
    },
    [],
  );

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
          height: "100vh",
          display: "flex",
          flexDirection: "column",
        }}
      >
        <Toolbar />

        <Editable
          renderElement={renderElement}
          renderLeaf={renderLeaf}
          spellCheck={false}
          style={{
            height: "100%",
            width: "100%",
            padding: 50,
            textAlign: "left",
            lineHeight: 1.1,
            boxSizing: "border-box",
            userSelect: "none",
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
  editor.isInline = (e) => e.type === "slur" ? true : isInline(e);
  return editor;
}
