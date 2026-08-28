import styles from "./SideMenu.module.css";
import { useEffect, useRef, useState, type Ref } from "react";
import { LuMenu } from "react-icons/lu";
import { useAuth } from "@appwrite.io/react";
import type { JianpuDoc } from "./types";
import { Editor, Transforms } from "slate";
import { useSlate } from "slate-react";
import { useEditorContext } from "./useEditorContext";

export function SideMenuButton() {
  const buttonRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const { docs } = useEditorContext();
  const [showMenu, setShowMenu] = useState(false);

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

  return (
    <>
      <button
        ref={buttonRef}
        className={styles.button}
        onClick={() => setShowMenu(!showMenu)}
      >
        <LuMenu />
      </button>

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
  const { currentDoc, setCurrentDoc, newDoc } = useEditorContext();

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

  return (
    <div ref={props.ref} className={styles.menuBody}>
      <button
        onClick={() => {
          newDoc(editor);
          props.closeMenu();
        }}
      >
        + New
      </button>
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
