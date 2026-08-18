import { useCallback, useState } from "react";
import { createEditor, Editor, Transforms } from "slate";
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

type ParagraphElement = { type: "paragraph"; children: CustomText[] };
type SlurElement = { type: "slur"; children: CustomText[] };
type CustomText = {
  text: string;
  octave?: number;
  beam?: number;
  slur?: number;
};

declare module "slate" {
  interface CustomTypes {
    Editor: BaseEditor & ReactEditor;
    Element: ParagraphElement | SlurElement;
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
  const [editor] = useState(() => withSlur(withReact(createEditor())));

  const renderElement = useCallback((props: RenderElementProps) => {
    switch (props.element.type) {
      case "slur":
        return <SlurElement {...props} />;
      case "paragraph":
        return <ParagraphElement {...props} />;
    }
  }, []);
  const renderLeaf = useCallback((props: RenderLeafProps) => {
    return (
      <span {...props.attributes} style={{ position: "relative" }}>
        {props.children}
        <JianpuFormatting leaf={props.leaf} />
      </span>
    );
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
          renderElement={renderElement}
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

function ParagraphElement(props: RenderElementProps) {
  return <span {...props.attributes}>{...props.children}</span>;
}

function SlurElement(props: RenderElementProps) {
  return (
    <span {...props.attributes} style={{ position: "relative" }}>
      {...props.children}
      <div
        style={{
          position: "absolute",
          left: 5,
          right: 5,
          height: 5,
          bottom: 18,
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

function JianpuFormatting({ leaf }: { leaf: CustomText }) {
  const octaveArray = Array.from({ length: Math.abs(leaf.octave ?? 0) });
  const beamArray = Array.from({ length: leaf.beam ?? 0 });

  return (
    <span
      style={{
        position: "absolute",
        left: 0,
        pointerEvents: "none",
        userSelect: "none",
      }}
    >
      {[...leaf.text].map((char, i) => (
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
          {char != " " && octaveArray.map((_, i) => (
            <span
              key={i}
              style={{
                position: "absolute",
                height: 2,
                width: 2,
                left: "50%",
                transform: "translateX(-50%)",
                backgroundColor: "black",
                ...((leaf.octave ?? 0) > 0
                  ? {
                    bottom: 16 + (4 * i),
                  }
                  : {
                    top: 20 + (4 * i) + (2 * (leaf.beam ?? 0)),
                  }),
              }}
            />
          ))}
          {char != " " && beamArray.map((_, i) => (
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
