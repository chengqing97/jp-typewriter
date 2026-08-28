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
import { DATABASE_ID } from "./constants";

type EditorContextValue = {
  editableRef: RefObject<HTMLDivElement | null>;
  currentDoc: JianpuDoc | null;
  setCurrentDoc: Dispatch<JianpuDoc | null>;
  docs: JianpuDoc[];
  getDocs: () => void;
};

export const EditorContext = createContext<EditorContextValue | null>(null);

export function EditorContextProvider(props: PropsWithChildren) {
  const editableRef = useRef<HTMLDivElement>(null);
  const { tablesDB } = useAppwrite();
  const [currentDoc, setCurrentDoc] = useState<JianpuDoc | null>(null);
  const [docs, setDocs] = useState<JianpuDoc[]>([]);

  useEffect(() => {
    const docString = localStorage.getItem("currentDoc");
    if (docString) {
      setCurrentDoc(JSON.parse(docString));
    }
  }, []);

  useEffect(() => {
    if (currentDoc) {
      localStorage.setItem("currentDoc", JSON.stringify(currentDoc));
    } else {
      localStorage.removeItem("currentDoc");
    }
  }, [currentDoc]);

  useEffect(() => {
    getDocs();
  }, []);

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
      value={{ editableRef, currentDoc, setCurrentDoc, docs, getDocs }}
    >
      {props.children}
    </EditorContext.Provider>
  );
}

export const useEditorContext = () => useContext(EditorContext)!;
