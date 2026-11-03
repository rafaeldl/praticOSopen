// What a payment proof may be: an image or a PDF below 10 MB, what the Storage
// rules (isValidDocument) and the server (validateReceiptFile) take. The app
// sends HEIC and others as octet-stream (pay.widget.proof-picker); the web
// refuses them before uploading, with a sentence.
export function proofProblem(file: { type: string; size: number }): 'type' | 'size' | null {
  if (!/^image\/[a-z0-9.+-]+$/i.test(file.type) && file.type !== 'application/pdf') return 'type'
  return file.size >= 10 * 1024 * 1024 ? 'size' : null
}
