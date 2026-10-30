import styles from "./SideBar.module.css";
import { useEffect, useRef, useState, type Ref } from "react";
import { LuArrowDown, LuMenu, LuRotateCcw, LuSearch } from "react-icons/lu";
import { Query, useAppwrite, useAuth } from "@appwrite.io/react";
import type { DocListItem, JianpuDoc } from "./types";
import { Editor } from "slate";
import { useSlate } from "slate-react";
import { useEditorContext } from "./useEditorContext";
import { DATABASE_ID, sortMethods } from "./constants";
import { sortDocs } from "./utils/sortDocs";
import { CustomEditor } from "./CustomEditor";
import { useDialogContext } from "./useDialog";

export function SideBarButton() {
  const buttonRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const { tablesDB } = useAppwrite();
  const { setDocs, currentSortIndex } = useEditorContext();
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

  useEffect(() => {
    getDocs();
  }, []);

  async function getDocs() {
    setDocs([]);
    try {
      const { rows } = await tablesDB.listRows<JianpuDoc>({
        databaseId: DATABASE_ID,
        tableId: "documents",
        queries: [
          Query.limit(1000),
          Query.equal("visible", true),
          sortMethods[currentSortIndex].query,
        ],
      });
      setDocs(rows);
      return rows;
    } catch (e) {
      window.alert(e);
    }
  }

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
        <SideBar
          ref={menuRef}
          closeMenu={() => setShowMenu(false)}
          onReload={getDocs}
        />
      )}
    </>
  );
}

type SideMenuProps = {
  ref: Ref<HTMLDivElement>;
  closeMenu: () => void;
  onReload: () => void;
};

function SideBar(props: SideMenuProps) {
  const editor = useSlate();
  const { tablesDB } = useAppwrite();
  const { user, signOut } = useAuth();
  const {
    currentDoc,
    currentSortIndex,
    docs,
    newDoc,
    save,
    saveState,
    setDocs,
    setCurrentDoc,
    setCurrentSortIndex,
    setLoadState,
    setSaveState,
  } = useEditorContext();
  const { showDialog } = useDialogContext();
  const [searchResults, setSearchResults] = useState<DocListItem[] | null>(
    null,
  );

  function changeOrder() {
    let nextIndex = currentSortIndex + 1;
    if (nextIndex >= sortMethods.length) {
      nextIndex = 0;
    }
    setCurrentSortIndex(nextIndex);
    setDocs((docs) => sortDocs(docs, nextIndex));
  }

  async function openDoc(doc: DocListItem) {
    props.closeMenu();
    setLoadState("loading");
    setCurrentDoc({ ...doc, content: "" });
    CustomEditor.setText(editor, "Loading...");
    try {
      const result = await tablesDB.getRow<JianpuDoc>({
        databaseId: DATABASE_ID,
        tableId: "documents",
        rowId: doc.$id,
      });

      Editor.withoutNormalizing(editor, () => {
        editor.children = JSON.parse(result.content);
      });
      localStorage.setItem("content", result.content);
      setCurrentDoc(result);
      setLoadState("loaded");
      setSaveState("saved");
    } catch (e) {
      CustomEditor.setText(editor, `${e}`);
    }
  }

  async function handleDocClick(doc: DocListItem) {
    if (saveState == "unsaved") {
      showDialog({
        title: "You have unsaved changes",
        buttons: [
          { text: "Cancel", onClick: () => {} },
          {
            text: "Discard",
            onClick: () => openDoc(doc),
          },
          {
            text: "Save",
            onClick: async () => {
              await save(editor);
              openDoc(doc);
            },
          },
        ],
      });
    } else {
      openDoc(doc);
    }
  }

  async function search(text: string) {
    if (!docs) return;
    if (text.trim().length == 0) {
      setSearchResults(null);
      return;
    }
    setSearchResults(
      docs.filter((doc) =>
        doc.title.toLowerCase().includes(text.toLowerCase()),
      ),
    );
  }

  function logout() {
    localStorage.clear();
    signOut.signOut();
  }

  return (
    <div ref={props.ref} className={styles.menuBody}>
      <div className={styles.topRow}>
        <p className={styles.count}>{docs ? `Total ${docs.length}` : ""}</p>
        <button
          onClick={() => {
            newDoc(editor);
            props.closeMenu();
          }}
        >
          + New
        </button>
        <button className={styles.reloadButton} onClick={props.onReload}>
          <LuRotateCcw />
        </button>
        <div style={{ flex: 1 }} />
        <button className={styles.sortButton} onClick={changeOrder}>
          {sortMethods[currentSortIndex].name}
          <LuArrowDown />
        </button>
      </div>

      <LuSearch className={styles.searchIcon} />
      <input
        className={styles.searchBox}
        autoFocus
        onChange={(e) => search(e.currentTarget.value)}
      />
      <div className={styles.scrollable}>
        {searchResults?.length === 0 ? (
          <p className={styles.message}>No result</p>
        ) : docs === null ? (
          <p className={styles.message}>Loading...</p>
        ) : (
          (searchResults ?? docs).map((doc) => (
            <div
              key={doc.$id}
              className={styles.menuItem}
              onClick={() => handleDocClick(doc)}
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
