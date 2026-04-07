const FALLBACK = { r: 30, g: 30, b: 30 };

export interface RGB {
  r: number;
  g: number;
  b: number;
}

/**
 * Extract the average (dominant) color from an image URL using an offscreen canvas.
 * Returns a dark fallback on error or CORS failure.
 */
export function getDominantColor(url: string): Promise<RGB> {
  return new Promise((resolve) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      try {
        const canvas = document.createElement('canvas');
        canvas.width = 1;
        canvas.height = 1;
        const ctx = canvas.getContext('2d');
        if (!ctx) {
          resolve(FALLBACK);
          return;
        }
        ctx.drawImage(img, 0, 0, 1, 1);
        const [r, g, b] = ctx.getImageData(0, 0, 1, 1).data;
        resolve({ r, g, b });
      } catch {
        resolve(FALLBACK);
      }
    };
    img.onerror = () => resolve(FALLBACK);
    img.src = url;
  });
}
