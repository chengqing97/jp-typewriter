import {
  createContext,
  useRef,
  useContext,
  useState,
  useEffect,
  type Dispatch,
  type PropsWithChildren,
  type RefObject,
} from "react";
import type { JianpuDoc, SaveState } from "./types";
import { useAppwrite } from "@appwrite.io/react";
import { DATABASE_ID, DEFAULT_TITLE, sortMethods } from "./constants";
import { Editor, Transforms, type Descendant } from "slate";

type EditorContextValue = {
  editableRef: RefObject<HTMLDivElement | null>;
  currentDoc: JianpuDoc | null;
  setCurrentDoc: Dispatch<JianpuDoc | null>;
  docs: JianpuDoc[] | null;
  getDocs: () => void;
  title: string;
  setTitle: Dispatch<string>;
  newDoc: (editor: Editor) => void;
  saveState: SaveState;
  setSaveState: Dispatch<SaveState>;
  currentSortIndex: number;
  changeOrder: () => void;
};

const EditorContext = createContext<EditorContextValue | null>(null);

export function EditorContextProvider(props: PropsWithChildren) {
  const editableRef = useRef<HTMLDivElement>(null);
  const { tablesDB } = useAppwrite();
  const [currentDoc, setCurrentDoc] = useState<JianpuDoc | null>(null);
  const [docs, setDocs] = useState<JianpuDoc[] | null>(null);
  const [title, setTitle] = useState("");
  const [saveState, setSaveState] = useState<SaveState>("init");
  const [currentSortIndex, setCurrentSortIndex] = useState(0);

  useEffect(() => {
    (async () => {
      const prevContent = localStorage.getItem("currentDoc");
      if (prevContent) {
        const prevDoc = JSON.parse(prevContent);
        setCurrentDoc(prevDoc);
        const docs = await getDocs();
        if (!docs) return;
        const latestDoc = docs.find((doc) => doc.$id === prevDoc.$id);
        if (!latestDoc) return;
        setCurrentDoc(latestDoc);
      } else {
        getDocs();
      }
    })();
  }, []);

  useEffect(() => {
    if (currentDoc) {
      localStorage.setItem("currentDoc", JSON.stringify(currentDoc));
      setTitle(currentDoc.title);
      setSaveState(
        currentDoc.content === localStorage.getItem("content")
          ? "saved"
          : "unsaved",
      );
    }
  }, [currentDoc]);

  async function getDocs(sortIndex?: number) {
    try {
      const { rows } = await tablesDB.listRows<JianpuDoc>({
        databaseId: DATABASE_ID,
        tableId: "documents",
        queries: [sortMethods[sortIndex ?? currentSortIndex].query],
      });
      setDocs(rows);
      return rows;
    } catch (e) {
      window.alert(e);
    }
  }

  function changeOrder() {
    let nextIndex = currentSortIndex + 1;
    if (nextIndex >= sortMethods.length) {
      nextIndex = 0;
    }
    getDocs(nextIndex);
    setCurrentSortIndex(nextIndex);
  }

  function newDoc(editor: Editor) {
    const emptyValue: Descendant[] = [
      {
        type: "code",
        children: [{ text: "" }],
      },
    ];
    Transforms.removeNodes(editor, {
      at: {
        anchor: Editor.start(editor, []),
        focus: Editor.end(editor, []),
      },
    });
    Transforms.insertNodes(editor, emptyValue, { at: [0] });
    localStorage.removeItem("currentDoc");
    setCurrentDoc(null);
    setTitle(DEFAULT_TITLE);
    setSaveState("init");
  }
  return (
    <EditorContext.Provider
      value={{
        editableRef,
        currentDoc,
        setCurrentDoc,
        docs,
        getDocs,
        title,
        setTitle,
        newDoc,
        saveState,
        setSaveState,
        currentSortIndex,
        changeOrder,
      }}
    >
      {props.children}
    </EditorContext.Provider>
  );
}

export const useEditorContext = () => useContext(EditorContext)!;
