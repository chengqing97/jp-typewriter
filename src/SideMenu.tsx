import styles from "./SideMenu.module.css";
import { useEffect, useRef, useState, type Ref } from "react";
import { LuMenu } from "react-icons/lu";
import { useAppwrite, useAuth } from "@appwrite.io/react";
import type { JianpuDoc } from "./types";
import { DATABASE_ID } from "./constants";
import { Editor, Transforms, type Descendant } from "slate";
import { useSlate } from "slate-react";
import { useEditorContext } from "./useEditorContext";

export function SideMenuButton() {
  const buttonRef = useRef<HTMLDivElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const { tablesDB } = useAppwrite();
  const [showMenu, setShowMenu] = useState(false);
  const [docs, setDocs] = useState<JianpuDoc[]>([]);

  useEffect(() => {
    function onMouseDown(event: MouseEvent) {
      const target = event.target as Node;
      if (!menuRef.current) return;
      if (menuRef.current.contains(target)) return;
      if (buttonRef.current?.contains(target)) return;
      // outside click
      setShowMenu(false);
    }
    document.addEventListener("mousedown", onMouseDown);
    return () => {
      document.removeEventListener("mousedown", onMouseDown);
    };
  }, []);

  useEffect(() => {
    async function getDocs() {
      try {
        const result = await tablesDB.listRows<JianpuDoc>({
          databaseId: DATABASE_ID,
          tableId: "documents",
        });
        setDocs(result.rows);
      } catch (e) {
        window.alert(e);
      }
    }
    getDocs();
  }, []);

  return (
    <>
      <div
        ref={buttonRef}
        className={styles.button}
        onClick={() => setShowMenu(!showMenu)}
      >
        <LuMenu />
      </div>

      {showMenu && (
        <SideMenu
          ref={menuRef}
          docs={docs}
          closeMenu={() => setShowMenu(false)}
        />
      )}
    </>
  );
}

type SideMenuProps = {
  ref: Ref<HTMLDivElement>;
  docs: JianpuDoc[];
  closeMenu: () => void;
};

function SideMenu(props: SideMenuProps) {
  const editor = useSlate();
  const { signOut } = useAuth();
  const { currentDoc, setCurrentDoc } = useEditorContext();

  function openDoc(doc: JianpuDoc) {
    Transforms.removeNodes(editor, {
      at: {
        anchor: Editor.start(editor, []),
        focus: Editor.end(editor, []),
      },
    });
    Transforms.insertNodes(editor, JSON.parse(doc.content), { at: [0] });
    setCurrentDoc(doc);
    props.closeMenu();
  }

  function newDoc() {
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
    setCurrentDoc(null);
    props.closeMenu();
  }

  return (
    <div ref={props.ref} className={styles.menuBody}>
      <button onClick={newDoc}>+ New</button>
      <div style={{ height: 10 }} />
      {props.docs.map((doc) => (
        <div
          key={doc.$id}
          className={styles.menuItem}
          onClick={() => openDoc(doc)}
        >
          {doc.$id == currentDoc?.$id && <div className={styles.dot} />}
          {doc.title}
        </div>
      ))}
      <div style={{ flex: 1 }} />
      <button onClick={() => signOut.signOut()} disabled={signOut.isPending}>
        Logout
      </button>
    </div>
  );
}
