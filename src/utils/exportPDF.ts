import { downloadPDF } from "dompdf.js";

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  let binary = "";
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

async function loadFontAsBase64(
  url: string,
  fontFamily: string,
  fontWeight: number = 400,
  fontStyle: "normal" | "italic" = "normal",
) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to load font: ${url}`);
  const buffer = await res.arrayBuffer();
  return {
    fontFamily,
    fontBase64: arrayBufferToBase64(buffer),
    fontWeight,
    fontStyle,
  };
}

export async function handleExport(div: HTMLDivElement, filename: string) {
  try {
    await document.fonts.ready;

    const width = div.offsetWidth;
    const height = div.offsetHeight;

    console.log(height, width);

    const [wenkai, notoMusic, courierPrime] = await Promise.all([
      loadFontAsBase64(
        "/fonts/LXGWWenKaiMonoTC-Regular.ttf",
        "LXGW WenKai Mono TC",
        400,
      ),
      loadFontAsBase64("/fonts/NotoMusic-Regular.ttf", "Noto Music", 400),
      loadFontAsBase64(
        "/fonts/CourierPrime-Italic.ttf",
        "Courier Prime",
        400,
        "italic",
      ),
    ]);

    await downloadPDF(
      div,
      {
        format: "a4",
        pagination: false,
        backgroundColor: "#ffffff",
        putOnlyUsedFonts: true,
        fontConfig: [wenkai, notoMusic, courierPrime],
        pageWidthPt: height / 2,
        pageHeightPt: height,
      },
      filename,
    );
  } catch (err) {
    console.error(err);
    alert("Export failed – check console");
  }
}
