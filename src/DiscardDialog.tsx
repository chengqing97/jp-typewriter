import { useAppwrite } from "@appwrite.io/react";
import styles from "./Dialog.module.css";
import { DATABASE_ID } from "./constants";
import { useEditorContext } from "./useEditorContext";
import { useState } from "react";
import { useSlate } from "slate-react";

type Props = {
  onDismiss: () => void;
};

export default function DiscardDialog(props: Props) {
  // const editor = useSlate();
  // const { tablesDB } = useAppwrite();
  // const { currentDoc, newDoc, setDocs } = useEditorContext();
  // const [deleting, setDeleting] = useState(false);


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
