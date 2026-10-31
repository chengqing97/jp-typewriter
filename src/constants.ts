import { Query } from "appwrite";

export const DATABASE_ID = "6a9027460002764fdbf8";

export const DEFAULT_TITLE = "Untitled";

export const jianpuNote = /^[a-ac-zA-Z1-9]/;

export const sortMethods = [
  {
    name: "Name",
    query: Query.orderAsc("title"),
  },
  {
    name: "Created Date",
    query: Query.orderDesc("$createdAt"),
  },
  {
    name: "Modified Date",
    query: Query.orderDesc("$updatedAt"),
  },
];

export const OFFLINE_MODE = import.meta.env.VITE_OFFLINE_MODE === "true";
