import type { BaseEditor } from "slate";
import { HistoryEditor } from "slate-history";
import { ReactEditor } from "slate-react";
import { Model } from "@appwrite.io/react";
import type { Models } from "appwrite";
import type { sortMethods } from "./constants";

export type CustomText = {
  text: string;
  octave?: number;
  beam?: number;
  slur?: number;
  superscript?: boolean;
};

type ParagraphElement = {
  type: "paragraph";
  children: CustomText[];
  gap?: number;
};

type CodeElement = {
  type: "code";
  children: CustomText[];
  gap?: number;
};

type SlurElement = {
  type: "slur";
  children: CustomText[];
  gap?: number;
};

declare module "slate" {
  interface CustomTypes {
    Editor: BaseEditor & ReactEditor & HistoryEditor;
    Element: ParagraphElement | CodeElement | SlurElement;
    Text: CustomText;
  }
}

export interface DocListItem extends Models.Row {
  title: string;
}

export interface JianpuDoc extends Models.Row {
  title: string;
  content: string;
}

export type SaveState = "init" | "saved" | "unsaved" | "saving";

export type LoadState = "loading" | "loaded" | "error";
