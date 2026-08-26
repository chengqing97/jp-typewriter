import { useEffect, useRef, useState } from "react";
import styles from "./DocsMenu.module.css";
import { LuMenu } from "react-icons/lu";
import { useAuth } from "@appwrite.io/react";

export default function FileList() {
  const buttonRef = useRef<HTMLDivElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const [showMenu, setShowMenu] = useState(false);
  const { signOut } = useAuth();

  useEffect(() => {
    function onMouseDown(event: MouseEvent) {
      const target = event.target as Node;
      if (!menuRef.current) return;
      if (menuRef.current.contains(target)) return;
      if (buttonRef.current?.contains(target)) return;
      setShowMenu(false); // outside click
    }
    document.addEventListener("mousedown", onMouseDown);
    return () => {
      document.removeEventListener("mousedown", onMouseDown);
    };
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
        <div ref={menuRef} className={styles.menuBody}>
          <div style={{ flex: 1 }} />
          <button
            onClick={() => signOut.signOut()}
            disabled={signOut.isPending}
          >
            Logout
          </button>
        </div>
      )}
    </>
  );
}
// {docs?.map((doc) => (
//   <div
//     key={doc.id}
//     className={styles.menuItem}
//     onClick={() => props.onOpen(doc)}
//   >
//     {doc.title}
//   </div>
// ))}
