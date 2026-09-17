import {
  createContext,
  useRef,
  useContext,
  useState,
  useEffect,
  type Dispatch,
  type PropsWithChildren,
  type RefObject,
  type SetStateAction,
} from "react";
import type { DocListItem, JianpuDoc, LoadState, SaveState } from "./types";
import { DATABASE_ID, DEFAULT_TITLE } from "./constants";
import { Editor } from "slate";
import { CustomEditor } from "./CustomEditor";
import { useAppwrite } from "@appwrite.io/react";

type EditorContextValue = {
  editableRef: RefObject<HTMLDivElement | null>;
  currentDoc: JianpuDoc | null;
  setCurrentDoc: Dispatch<JianpuDoc | null>;
  docs: DocListItem[] | null;
  setDocs: Dispatch<SetStateAction<DocListItem[] | null>>;
  title: string;
  setTitle: Dispatch<string>;
  newDoc: (editor: Editor) => void;
  saveState: SaveState;
  setSaveState: Dispatch<SaveState>;
  currentSortIndex: number;
  setCurrentSortIndex: Dispatch<number>;
  loadState: LoadState;
  setLoadState: Dispatch<LoadState>;
};

const EditorContext = createContext<EditorContextValue | null>(null);

export function EditorContextProvider(props: PropsWithChildren) {
  const editableRef = useRef<HTMLDivElement>(null);
  const { tablesDB } = useAppwrite();
  const [currentDoc, setCurrentDoc] = useState<JianpuDoc | null>(null);
  const [docs, setDocs] = useState<DocListItem[] | null>(null);
  const [title, setTitle] = useState("");
  const [saveState, setSaveState] = useState<SaveState>("init");
  const [loadState, setLoadState] = useState<LoadState>("loaded");
  const [currentSortIndex, setCurrentSortIndex] = useState(0);

  useEffect(() => {
    (async () => {
      const prevContent = localStorage.getItem("currentDoc");
      if (prevContent) {
        const prevDoc = JSON.parse(prevContent);
        setCurrentDoc(prevDoc);
        const latestDoc = await tablesDB.getRow<JianpuDoc>({
          databaseId: DATABASE_ID,
          tableId: "documents",
          rowId: prevDoc.$id,
        });
        setSaveState(
          latestDoc.content === localStorage.getItem("content")
            ? "saved"
            : "unsaved",
        );
      }
    })();
  }, []);

  useEffect(() => {
    if (currentDoc) {
      localStorage.setItem("currentDoc", JSON.stringify(currentDoc));
      setTitle(currentDoc.title);
    } else {
      setTitle(DEFAULT_TITLE);
    }
  }, [currentDoc]);

  function newDoc(editor: Editor) {
    CustomEditor.setText(editor, "");
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
        setDocs,
        title,
        setTitle,
        newDoc,
        saveState,
        setSaveState,
        currentSortIndex,
        setCurrentSortIndex,
        loadState,
        setLoadState,
      }}
    >
      {props.children}
    </EditorContext.Provider>
  );
}

export const useEditorContext = () => useContext(EditorContext)!;
