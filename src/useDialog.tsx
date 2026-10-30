import styles from "./Dialog.module.css";
import {
  createContext,
  useContext,
  useState,
  type PropsWithChildren,
  type Dispatch,
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
  const [dialog, showDialog] = useState<DialogOption | null>(null);

  return (
    <DialogContext.Provider value={{ showDialog }}>
      {props.children}
      {dialog && (
        <div className={styles.layout} onClick={() => showDialog(null)}>
          <div className={styles.dialogBody}>
            <p className={styles.title}>{dialog.title}</p>
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
