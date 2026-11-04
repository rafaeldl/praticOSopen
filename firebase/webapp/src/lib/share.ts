// Sending things on the web, the same for every screen (the app's share sheet
// on a computer): WhatsApp in a new tab (wa.me), the copy, and the browser's
// own share sheet (Web Share API) where it exists, with the file when the
// browser takes files. The number goes already normalized (lib/phone
// whatsappNumber); without one, WhatsApp asks for the contact.
//
// onShare is the single point every way of sending passes through: it sends the
// analytics "share" event (method sheet | whatsapp | clipboard, content_type
// what was sent), once per send.
import { logShare, type ShareMethod } from '@/lib/analytics'

export type { ShareMethod }
/** What was sent (content_type): the app sends "order" for the order's link; the web adds the others. */
export type ShareContent = 'order' | 'pdf' | 'photo' | 'receipt' | 'invoice' | 'invite'
export type ShareListener = (method: ShareMethod, context: string) => void

let listener: ShareListener | null = null

/** Also hears each share (tests). One at a time; null takes it off. */
export function setShareListener(next: ShareListener | null): void {
  listener = next
}

/** Something was sent: method and what (content_type). */
export function onShare(method: ShareMethod, context: string): void {
  logShare(method, context)
  try {
    listener?.(method, context)
  } catch (error) {
    console.warn('share: listener failed', error)
  }
}

/** wa.me with the text; without a number WhatsApp asks for the contact. */
export function whatsappUrl(number: string | null | undefined, text: string): string {
  return `https://wa.me/${number ?? ''}?text=${encodeURIComponent(text)}`
}

/** Opens WhatsApp in a new tab. False when the browser blocked the tab. */
export function openWhatsapp(number: string | null | undefined, text: string, context: string): boolean {
  const opened = window.open(whatsappUrl(number, text), '_blank')
  if (!opened) return false
  try {
    opened.opener = null
  } catch {
    // Another origin already: nothing to cut.
  }
  onShare('whatsapp', context)
  return true
}

type Nav = Navigator & { share?: (data: ShareData) => Promise<void>; canShare?: (data: ShareData) => boolean }
const nav = (): Nav | null => (typeof navigator === 'undefined' ? null : (navigator as Nav))

/** The browser has a share sheet (phones, Safari, Chrome on Windows and Mac). */
export function canShareSheet(): boolean {
  return typeof nav()?.share === 'function'
}

/** The sheet takes these files (navigator.canShare({ files })). */
export function canShareFiles(files: File[]): boolean {
  const n = nav()
  if (!files.length || typeof n?.share !== 'function' || typeof n.canShare !== 'function') return false
  try {
    return n.canShare({ files })
  } catch {
    return false
  }
}

/** The browser's sheet. Closed by the person is "cancelled", not a failure. */
export async function shareSheet(data: ShareData, context: string): Promise<'shared' | 'cancelled' | 'unavailable' | 'failed'> {
  const n = nav()
  if (typeof n?.share !== 'function') return 'unavailable'
  try {
    await n.share(data)
    onShare('sheet', context)
    return 'shared'
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') return 'cancelled'
    console.warn('share: sheet failed', error)
    return 'failed'
  }
}

/** Copies the text. False when the browser refused. */
export async function copyText(text: string, context: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text)
    onShare('clipboard', context)
    return true
  } catch {
    return false
  }
}

/** A file from a link (a photo, a nota's PDF); null when it cannot be read (another site without CORS). */
export async function fileFromUrl(url: string, name: string): Promise<File | null> {
  try {
    const response = await fetch(url)
    if (!response.ok) return null
    const blob = await response.blob()
    return new File([blob], name, { type: blob.type || 'application/octet-stream' })
  } catch {
    return null
  }
}

/** Saves a file through the browser's download. */
export function downloadFile(file: Blob, name: string): void {
  const url = URL.createObjectURL(file)
  const link = document.createElement('a')
  link.href = url
  link.download = name
  link.rel = 'noopener'
  document.body.append(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(url), 10_000)
}
