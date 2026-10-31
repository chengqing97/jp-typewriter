import styles from "./App.module.css";
import { useAuth } from "@appwrite.io/react";
import EditorPage from "./EditorPage";
import LoginPage from "./LoginPage";
import { EditorContextProvider } from "./useEditorContext";
import { OFFLINE_MODE } from "./constants";

export default function App() {
  const { user, isLoading } = useAuth();

  if (OFFLINE_MODE)
    return (
      <EditorContextProvider>
        <EditorPage />
      </EditorContextProvider>
    );

  if (isLoading)
    return (
      <div className={styles.center}>
        <p>Loading...</p>
      </div>
    );

  if (user) {
    return (
      <EditorContextProvider>
        <EditorPage />
      </EditorContextProvider>
    );
  }

  return <LoginPage />;
}
