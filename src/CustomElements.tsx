import { Editor } from "slate";
import type { RenderElementProps } from "slate-react";
import { jianpuNote } from "./constants";
import type { CSSProperties } from "react";

export function ParagraphElement(props: RenderElementProps) {
  return <p {...props.attributes}>{...props.children}</p>;
}

export function CodeElement(props: RenderElementProps) {
  return <pre {...props.attributes}>{...props.children}</pre>;
}

export function SlurElement(props: RenderElementProps) {
  const charOctaveList = props.element.children.flatMap(
    ({ text, octave, superscript }) => {
      return text.split("").map((char) => {
        return jianpuNote.test(char)
          ? Math.max(octave ?? 0, 0) + (superscript ? 0.5 : 0)
          : null;
      });
    },
  );

  const length = charOctaveList.length;

  function getSlurStyle(): CSSProperties {
    if (length === 1) {
      // Fermata
      return {
        left: -1,
        right: -1,
        height: 14,
        bottom: 9,
      };
    } else if (
      length > 2 &&
      charOctaveList.slice(1, -1).every((x) => x === null)
    ) {
      // Tie
      return {
        left: 7,
        right: 7,
        height: 10,
        bottom: 9,
      };
    } else {
      // Slur
      return {
        left: Math.min(length * 1.7, 5),
        right: Math.min(length * 1.7, 5),
        height: 9,
        bottom: 10 + 4 * Math.max(...charOctaveList.map((x) => x ?? 0)),
      };
    }
  }

  return (
    <span {...props.attributes} style={{ position: "relative" }}>
      {...props.children}
      <span
        style={{
          position: "absolute",
          borderTop: "1px solid black",
          borderRadius: 5,
          ...getSlurStyle(),
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
