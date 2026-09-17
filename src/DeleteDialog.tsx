import { useAppwrite } from "@appwrite.io/react";
import styles from "./Dialog.module.css";
import { DATABASE_ID } from "./constants";
import { useEditorContext } from "./useEditorContext";
import { useState } from "react";
import { useSlate } from "slate-react";

type Props = {
  onDismiss: () => void;
};

export default function DeleteDialog(props: Props) {
  const editor = useSlate();
  const { tablesDB } = useAppwrite();
  const { currentDoc, newDoc, setDocs } = useEditorContext();
  const [deleting, setDeleting] = useState(false);

  async function deleteDoc() {
    if (!currentDoc) return;
    setDeleting(true);
    try {
      await tablesDB.deleteRow({
        databaseId: DATABASE_ID,
        tableId: "documents",
        rowId: currentDoc.$id,
      });
      setDocs((docs) =>
        docs === null ? null : docs.filter((doc) => doc.$id !== currentDoc.$id),
      );
      newDoc(editor);
    } catch (e) {
      window.alert(e);
    } finally {
      setDeleting(false);
      props.onDismiss();
    }
  }

  if (deleting) {
    <div className={styles.layout}>
      <div className={styles.dialogBody}>
        <p>Deleting...</p>
      </div>
    </div>;
  }

  return (
    <div className={styles.layout} onClick={props.onDismiss}>
      <div className={styles.dialogBody} onClick={(e) => e.stopPropagation()}>
        <p className={styles.text}>Confirm delete?</p>
        <div className={styles.buttonRow}>
          <button className={styles.button} onClick={deleteDoc}>
            Yes
          </button>
          <button className={styles.button} onClick={props.onDismiss}>
            No
          </button>
        </div>
      </div>
    </div>
  );
}
