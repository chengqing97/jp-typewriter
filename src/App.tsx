import styles from "./App.module.css";
import { useAuth } from "@appwrite.io/react";
import EditorPage from "./EditorPage";
import LoginPage from "./LoginPage";
import { EditorContextProvider } from "./useEditorContext";

export default function App() {
  const { user, isLoading } = useAuth();

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
