import { useCallback, useState } from "react";
import { createEditor, Editor, Transforms } from "slate";
import { Editable, type RenderLeafProps, Slate, withReact } from "slate-react";
import type { BaseEditor, Descendant } from "slate";
import { ReactEditor } from "slate-react";
import Toolbar from "./Toolbar";

type CustomElement = { type: "paragraph"; children: CustomText[] };
type CustomText = { text: string; octave?: number; beam?: number };

declare module "slate" {
  interface CustomTypes {
    Editor: BaseEditor & ReactEditor;
    Element: CustomElement;
    Text: CustomText;
  }
}

const initialValue: Descendant[] = [
  {
    type: "paragraph",
    children: [{ text: "A line of text in a paragraph." }],
  },
];

export default function App() {
  const [editor] = useState(() => withReact(createEditor()));

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
          console.log(JSON.stringify(value));
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
          renderLeaf={renderLeaf}
          spellCheck={false}
          style={{
            height: "100%",
            width: "100%",
            padding: 20,
            textAlign: "left",
            boxSizing: "border-box",
          }}
          onKeyDown={(e) => {
            if (e.ctrlKey && e.key == "a") {
              e.preventDefault();
              Transforms.select(editor, {
                anchor: Editor.start(editor, []),
                focus: Editor.end(editor, []),
              });
            }
          }}
        />
      </div>
    </Slate>
  );
}

function Leaf(props: RenderLeafProps) {
  return (
    <span {...props.attributes} style={{ position: "relative" }}>
      {props.children}
      <JianpuFormatting {...props.leaf} />
    </span>
  );
}

function JianpuFormatting(props: CustomText) {
  return (
    <span
      style={{
        position: "absolute",
        left: 0,
        pointerEvents: "none",
        userSelect: "none",
      }}
    >
      {[...props.text].map((char, i) => (
        <span
          key={i}
          style={{
            position: "relative",
            color: "pink",
          }}
        >
          <span
            style={{
              visibility: "hidden",
            }}
          >
            {char}
          </span>
          {char != " " &&
            Array.from({ length: Math.abs(props.octave ?? 0) }).map((
              _,
              i,
            ) => (
              <span
                key={i}
                style={{
                  position: "absolute",
                  height: 2,
                  width: 2,
                  left: "50%",
                  transform: "translateX(-50%)",
                  backgroundColor: "black",
                  ...((props.octave ?? 0) > 0
                    ? {
                      bottom: 16 + (4 * i),
                    }
                    : {
                      top: 20 + (4 * i) + (2 * (props.beam ?? 0)),
                    }),
                }}
              />
            ))}
          {char != " " &&
            Array.from({ length: props.beam ?? 0 }).map((_, i) => (
              <span
                key={i}
                style={{
                  position: "absolute",
                  height: 1,
                  left: 0,
                  right: 0,
                  top: 20 + (2 * i),
                  backgroundColor: "black",
                }}
              />
            ))}
        </span>
      ))}
    </span>
  );
}
