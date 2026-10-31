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
import { ID, Permission, Role, useAppwrite, useUser } from "@appwrite.io/react";
import { sortDocs } from "./utils/sortDocs";

type EditorContextValue = {
  paperRef: RefObject<HTMLDivElement | null>;
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
  save: (editor: Editor) => Promise<void>;
  isFocused: boolean;
  setIsFocused: Dispatch<SetStateAction<boolean>>;
  keyboardVisible: boolean;
  setKeyboardVisible: Dispatch<SetStateAction<boolean>>;
};

const EditorContext = createContext<EditorContextValue | null>(null);

export function EditorContextProvider(props: PropsWithChildren) {
  const paperRef = useRef<HTMLDivElement>(null);
  const editableRef = useRef<HTMLDivElement>(null);
  const { user } = useUser();
  const { tablesDB } = useAppwrite();
  const [currentDoc, setCurrentDoc] = useState<JianpuDoc | null>(null);
  const [docs, setDocs] = useState<DocListItem[] | null>(null);
  const [title, setTitle] = useState("");
  const [saveState, setSaveState] = useState<SaveState>("init");
  const [loadState, setLoadState] = useState<LoadState>("loaded");
  const [currentSortIndex, setCurrentSortIndex] = useState(0);
  const [isFocused, setIsFocused] = useState(false);
  const [keyboardVisible, setKeyboardVisible] = useState(false);

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

  async function save(editor: Editor) {
    if (!user) return;
    setSaveState("saving");
    try {
      const response = await tablesDB.upsertRow<JianpuDoc>({
        databaseId: DATABASE_ID,
        tableId: "documents",
        rowId: currentDoc?.$id ?? ID.unique(),
        data: {
          title: title,
          content: JSON.stringify(editor.children),
        },
        permissions: [
          Permission.read(Role.user(user.$id)),
          Permission.update(Role.user(user.$id)),
          Permission.delete(Role.user(user.$id)),
        ],
      });
      setDocs((docs) => {
        if (!docs) return null;
        let updated = false;
        const updatedDocs = docs.map((doc) => {
          if (doc.$id == response.$id) {
            updated = true;
            return response;
          } else {
            return doc;
          }
        });
        if (updated) {
          return updatedDocs;
        } else {
          updatedDocs.push(response);
          return sortDocs(updatedDocs, currentSortIndex);
        }
      });
      setCurrentDoc(response);
      setSaveState("saved");
    } catch (e) {
      window.alert(e);
      setSaveState("unsaved");
    }
  }

  return (
    <EditorContext.Provider
      value={{
        paperRef,
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
        save,
        isFocused,
        setIsFocused,
        keyboardVisible,
        setKeyboardVisible,
      }}
    >
      {props.children}
    </EditorContext.Provider>
  );
}

export const useEditorContext = () => useContext(EditorContext)!;
