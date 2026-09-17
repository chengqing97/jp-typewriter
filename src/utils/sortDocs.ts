import type { DocListItem } from "../types";

export function sortDocs(
  docs: DocListItem[] | null,
  index: number,
): DocListItem[] | null {
  if (docs === null) return null;
  return [...docs].sort((a, b) => {
    switch (index) {
      case 0:
        return a.title.localeCompare(b.title);
      case 1:
        return (
          new Date(b.$createdAt).getTime() - new Date(a.$createdAt).getTime()
        );
      case 2:
        return (
          new Date(b.$updatedAt).getTime() - new Date(a.$updatedAt).getTime()
        );
      default:
        return 0;
    }
  });
}
