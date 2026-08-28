import styles from "./Dialog.module.css";
import {
  createContext,
  useContext,
  useState,
  type PropsWithChildren,
  type Dispatch,
  useEffect,
  useRef,
} from "react";

type ButtonOption = {
  text: string;
  onClick?: () => void;
};

type DialogOption = {
  title: string;
  buttons: ButtonOption[];
};

type DialogContextValue = {
  showDialog: Dispatch<DialogOption | null>;
};

const DialogContext = createContext<DialogContextValue | null>(null);

export function DialogContextProvider(props: PropsWithChildren) {
  const dialogRef = useRef<HTMLDivElement>(null);
  const [dialog, showDialog] = useState<DialogOption | null>(null);

  useEffect(() => {
    function onMouseDown(event: MouseEvent) {
      const target = event.target as Node;
      if (!dialogRef.current) return;
      if (dialogRef.current.contains(target)) return;
      // outside click
      showDialog(null);
    }
    document.addEventListener("mousedown", onMouseDown);
    return () => {
      document.removeEventListener("mousedown", onMouseDown);
    };
  }, []);

  return (
    <DialogContext.Provider value={{ showDialog }}>
      {props.children}
      {dialog && (
        <div className={styles.layout}>
          <div className={styles.dialogBody}>
            <p>{dialog.title}</p>
            <div className={styles.buttonRow}>
              {dialog.buttons.map((button, i) => (
                <button
                  key={i}
                  onClick={() => {
                    button.onClick && button.onClick();
                    showDialog(null);
                  }}
                >
                  {button.text}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </DialogContext.Provider>
  );
}

export const useDialogContext = () => useContext(DialogContext)!;
