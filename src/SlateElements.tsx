import { Editor } from "slate";
import type { RenderElementProps } from "slate-react";

export function ParagraphElement(props: RenderElementProps) {
  return (
    <p
      {...props.attributes}
      style={{
        margin: 0,
        fontFamily: "system-ui, 'Segoe UI', Roboto, sans-serif",
      }}
    >
      {...props.children}
    </p>
  );
}

export function CodeElement(props: RenderElementProps) {
  return (
    <pre
      {...props.attributes}
      style={{
        margin: 0,
        fontFamily: "ui-monospace, Consolas, monospace",
      }}
    >
      {...props.children}
    </pre>
  );
}

export function SlurElement(props: RenderElementProps) {
  return (
    <span {...props.attributes} style={{ position: "relative" }}>
      {...props.children}
      <span
        style={{
          position: "absolute",
          left: 7,
          right: 7,
          height: 10,
          bottom: 9,
          borderTop: "1px solid black",
          borderRadius: 5,
        }}
      />
    </span>
  );
}

export function withSlur(editor: Editor) {
  const { isInline } = editor;
  editor.isInline = (e) => (e.type === "slur" ? true : isInline(e));
  return editor;
}
