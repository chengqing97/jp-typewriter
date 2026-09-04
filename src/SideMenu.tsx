import styles from "./SideMenu.module.css";
import { useEffect, useRef, useState, type Ref } from "react";
import { LuArrowDown, LuMenu } from "react-icons/lu";
import { useAuth } from "@appwrite.io/react";
import type { JianpuDoc } from "./types";
import { Editor, Transforms } from "slate";
import { useSlate } from "slate-react";
import { useEditorContext } from "./useEditorContext";
import { sortMethods } from "./constants";

export function SideMenuButton() {
  const buttonRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
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
        <SideMenu ref={menuRef} closeMenu={() => setShowMenu(false)} />
      )}
    </>
  );
}

type SideMenuProps = {
  ref: Ref<HTMLDivElement>;
  closeMenu: () => void;
};

function SideMenu(props: SideMenuProps) {
  const editor = useSlate();
  const { user, signOut } = useAuth();
  const {
    currentDoc,
    setCurrentDoc,
    newDoc,
    docs,
    currentSortIndex,
    changeOrder,
  } = useEditorContext();

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

  function logout() {
    localStorage.clear();
    signOut.signOut();
  }

  return (
    <div ref={props.ref} className={styles.menuBody}>
      <div className={styles.topRow}>
        <button
          onClick={() => {
            newDoc(editor);
            props.closeMenu();
          }}
        >
          + New
        </button>
        <div style={{ flex: 1 }} />
        <button className={styles.sortButton} onClick={changeOrder}>
          {sortMethods[currentSortIndex].name}
          <LuArrowDown />
        </button>
      </div>
      <div className={styles.scrollable}>
        {docs === null ? (
          <p>Loading...</p>
        ) : (
          docs.map((doc) => (
            <div
              key={doc.$id}
              className={styles.menuItem}
              onClick={() => openDoc(doc)}
            >
              {doc.$id == currentDoc?.$id && <div className={styles.dot} />}
              <span className={styles.itemText}>{doc.title}</span>
            </div>
          ))
        )}
      </div>
      <div className={styles.accountRow}>
        <p className={styles.emailText}>{user!.email}</p>
        <div style={{ flex: 1 }} />
        <button onClick={logout} disabled={signOut.isPending}>
          Logout
        </button>
      </div>
    </div>
  );
}
