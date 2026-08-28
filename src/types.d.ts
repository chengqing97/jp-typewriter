import type { BaseEditor } from "slate";
import { HistoryEditor } from "slate-history";
import { ReactEditor } from "slate-react";
import { Model } from "@appwrite.io/react";
import type { Models } from "appwrite";

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
};

type CodeElement = {
  type: "code";
  children: CustomText[];
};

type SlurElement = {
  type: "slur";
  children: CustomText[];
};

declare module "slate" {
  interface CustomTypes {
    Editor: BaseEditor & ReactEditor & HistoryEditor;
    Element: ParagraphElement | CodeElement | SlurElement;
    Text: CustomText;
  }
}

export interface JianpuDoc extends Models.Row {
  title: string;
  content: string;
}
