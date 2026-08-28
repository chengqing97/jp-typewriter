import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.tsx";
import { AppwriteProvider } from "@appwrite.io/react";
import { DialogContextProvider } from "./useDialog.tsx";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <AppwriteProvider
      endpoint={import.meta.env.VITE_APPWRITE_ENDPOINT}
      projectId={import.meta.env.VITE_APPWRITE_PROJECT_ID}
    >
      <DialogContextProvider>
        <App />
      </DialogContextProvider>
    </AppwriteProvider>
  </StrictMode>,
);
