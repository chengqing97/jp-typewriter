import { useLayoutEffect, useRef, useState } from "react";
import type { RenderLeafProps } from "slate-react";

type Rect = {
  x: number;
  y: number;
  height: number;
  width: number;
  char: string;
};

export function Leaf({ attributes, children, leaf }: RenderLeafProps) {
  const ref = useRef<HTMLSpanElement>(null);
  const [rects, setRects] = useState<Rect[]>([]);

  const octaveArray = Array.from({ length: Math.abs(leaf.octave ?? 0) });
  const beamArray = Array.from({ length: leaf.beam ?? 0 });

  useLayoutEffect(() => {
    const element = ref.current;
    if (!element) return;

    const textNode = findTextNode(element);

    if (!textNode) return;

    const text = textNode.textContent ?? "";

    const newRects: Rect[] = [];

    for (let i = 0; i < text.length; i++) {
      const range = document.createRange();

      range.setStart(textNode, i);
      range.setEnd(textNode, i + 1);

      const rect = range.getBoundingClientRect();
      const parentRect = element.getBoundingClientRect();

      newRects.push({
        x: rect.x - parentRect.x,
        y: rect.y - parentRect.y,
        height: rect.height,
        width: rect.width,
        char: text[i],
      });
    }

    setRects(newRects);
  }, [leaf.text]);

  if (!leaf.beam && !leaf.octave) {
    return (
      <span {...attributes}>
        {children}
      </span>
    );
  }

  return (
    <span ref={ref} {...attributes} style={{ position: "relative" }}>
      {children}

      <span
        contentEditable={false}
        style={{
          position: "absolute",
          inset: 0,
          pointerEvents: "none",
          userSelect: "none",
        }}
      >
        {rects.map((rect, i) => (
          <span
            key={i}
            style={{
              position: "absolute",
              left: rect.x,
              height: rect.height,
              width: rect.width,
            }}
          >
            {/^[a-zA-Z1-9]/.test(rect.char) &&
              octaveArray.map((_, i) => (
                <span
                  key={i}
                  style={{
                    position: "absolute",
                    height: 2,
                    width: 2,
                    left: "50%",
                    transform: "translateX(-50%)",
                    backgroundColor: "black",
                    borderRadius: 2,
                    ...((leaf.octave ?? 0) > 0
                      ? {
                        bottom: rect.height - 2 + (4 * i),
                      }
                      : {
                        top: 20 + (4 * i) + (2 * (leaf.beam ?? 0)),
                      }),
                  }}
                />
              ))}
            {/^[a-zA-Z0-9]/.test(rect.char) && beamArray.map((_, i) => (
              <span
                key={i}
                style={{
                  position: "absolute",
                  height: 1,
                  left: 0,
                  right: 0,
                  top: rect.height - 2 + (2 * i),
                  backgroundColor: "black",
                }}
              />
            ))}
          </span>
        ))}
      </span>
    </span>
  );
}

function findTextNode(element: HTMLElement): Text | null {
  const walker = document.createTreeWalker(
    element,
    NodeFilter.SHOW_TEXT,
  );

  return walker.nextNode() as Text | null;
}
