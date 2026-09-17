import { Editor, Element, Transforms, Node, type Descendant } from "slate";

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

  toggleSlur(editor: Editor) {
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

  toggleSuperscript(editor: Editor) {
    const marks = Editor.marks(editor);
    if (marks?.superscript) {
      Editor.removeMark(editor, "superscript");
    } else {
      Editor.addMark(editor, "superscript", true);
    }
  },

  clearFormat(editor: Editor) {
    Editor.removeMark(editor, "beam");
    Editor.removeMark(editor, "octave");
  },

  getTitle(editor: Editor) {
    const firstNonEmptyLine = editor.children.find(
      (node) => Node.string(node).trim() !== "",
    );
    const text = firstNonEmptyLine ? Node.string(firstNonEmptyLine) : "";
    return text;
  },

  setChildren(editor: Editor, children: Descendant[]) {
    Transforms.select(editor, Editor.start(editor, []));
    Editor.withoutNormalizing(editor, () => {
      editor.children = children;
    });
  },

  setText(editor: Editor, text: string) {
    Transforms.select(editor, Editor.start(editor, []));
    Editor.withoutNormalizing(editor, () => {
      editor.children = [
        {
          type: "code",
          children: [{ text }],
        },
      ];
    });
  },
};
