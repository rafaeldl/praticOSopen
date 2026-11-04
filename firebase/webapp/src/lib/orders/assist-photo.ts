// Photos for the assistant (order.ai.photo): a file chosen on the computer
// (the phone's camera is a file here), made JPEG of at most 1600 px and quality
// 0.7 as the app's image_picker, base64 for POST /v1/app/ai/order-assist. The
// server takes up to 4 photos of 2 MB each.
export const ASSIST_MAX_PHOTOS = 4
export const ASSIST_MAX_BYTES = 2 * 1024 * 1024
const MAX_SIDE = 1600

/** Width and height that fit in MAX_SIDE, keeping the shape. */
export function fitSize(width: number, height: number, max = MAX_SIDE): { width: number; height: number } {
  const scale = Math.min(1, max / Math.max(width, height, 1))
  return { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) }
}

async function toBase64(blob: Blob): Promise<string> {
  const bytes = new Uint8Array(await blob.arrayBuffer())
  let binary = ''
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000))
  return btoa(binary)
}

/** One photo as the server wants it; throws when the file is not an image the browser can read. */
export async function assistPhoto(file: Blob): Promise<{ mimeType: 'image/jpeg'; data: string }> {
  const bitmap = await createImageBitmap(file)
  const size = fitSize(bitmap.width, bitmap.height)
  const canvas = document.createElement('canvas')
  canvas.width = size.width
  canvas.height = size.height
  canvas.getContext('2d')?.drawImage(bitmap, 0, 0, size.width, size.height)
  bitmap.close?.()
  let quality = 0.7
  let blob: Blob | null = null
  // Smaller until it fits the server's 2 MB.
  while (quality > 0.3) {
    blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', quality))
    if (blob && blob.size <= ASSIST_MAX_BYTES) break
    quality -= 0.15
  }
  if (!blob || blob.size > ASSIST_MAX_BYTES) throw new Error('photo too large')
  return { mimeType: 'image/jpeg', data: await toBase64(blob) }
}
