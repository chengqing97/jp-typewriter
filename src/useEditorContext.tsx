import {
  createContext,
  type RefObject,
  useRef,
  type PropsWithChildren,
  useContext,
  useState,
  type Dispatch,
  useEffect,
} from "react";
import type { JianpuDoc } from "./types";
import { useAppwrite } from "@appwrite.io/react";
import { DATABASE_ID, DEFAULT_TITLE } from "./constants";

type EditorContextValue = {
  editableRef: RefObject<HTMLDivElement | null>;
  currentDoc: JianpuDoc | null;
  setCurrentDoc: Dispatch<JianpuDoc | null>;
  docs: JianpuDoc[];
  getDocs: () => void;
  title: string;
  setTitle: Dispatch<string>;
};

export const EditorContext = createContext<EditorContextValue | null>(null);

export function EditorContextProvider(props: PropsWithChildren) {
  const editableRef = useRef<HTMLDivElement>(null);
  const { tablesDB } = useAppwrite();
  const [currentDoc, setCurrentDoc] = useState<JianpuDoc | null>(null);
  const [docs, setDocs] = useState<JianpuDoc[]>([]);
  const [title, setTitle] = useState("");

  useEffect(() => {
    const prevDoc = localStorage.getItem("currentDoc");
    if (prevDoc) {
      setCurrentDoc(JSON.parse(prevDoc));
    }
  }, []);

  useEffect(() => {
    getDocs();
  }, []);

  useEffect(() => {
    if (currentDoc) {
      localStorage.setItem("currentDoc", JSON.stringify(currentDoc));
      setTitle(currentDoc.title);
    } else {
      localStorage.removeItem("currentDoc");
      setTitle(DEFAULT_TITLE);
    }
  }, [currentDoc]);

  async function getDocs() {
    try {
      const { rows } = await tablesDB.listRows<JianpuDoc>({
        databaseId: DATABASE_ID,
        tableId: "documents",
      });
      setDocs(rows);
    } catch (e) {
      window.alert(e);
    }
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
      }}
    >
      {props.children}
    </EditorContext.Provider>
  );
}

export const useEditorContext = () => useContext(EditorContext)!;
