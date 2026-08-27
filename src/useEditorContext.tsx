import {
  createContext,
  type RefObject,
  useRef,
  type PropsWithChildren,
  useContext,
  useState,
  type Dispatch,
} from "react";
import type { JianpuDoc } from "./types";

type EditorContextValue = {
  editableRef: RefObject<HTMLDivElement | null>;
  currentDoc: JianpuDoc | null;
  setCurrentDoc: Dispatch<JianpuDoc | null>;
};

export const EditorContext = createContext<EditorContextValue | null>(null);

export function EditorContextProvider(props: PropsWithChildren) {
  const editableRef = useRef<HTMLDivElement>(null);
  const [currentDoc, setCurrentDoc] = useState<JianpuDoc | null>(null);

  return (
    <EditorContext.Provider value={{ editableRef, currentDoc, setCurrentDoc }}>
      {props.children}
    </EditorContext.Provider>
  );
}

export const useEditorContext = () => useContext(EditorContext)!;
