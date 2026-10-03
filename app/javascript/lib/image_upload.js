// ⚡ FRONT · lib/image_upload — prépare une image d'article dans le navigateur, puis l'envoie à l'endpoint de l'équipe
// Rôle : chargé par import() seulement (éditeur du blog, couverture) : plus grand côté borné, WebP 0,82 (JPEG à défaut), sans métadonnées
// ADR  : 0051, 0060, 0073 · UDR : 0065 (§3.4.3) · mêmes règles de réduction que identity/photo_picker_controller.js

const QUALITY = 0.82
// An upload that never answers (a stalled connection) is given up: the editor and « Enregistrer » are free again.
export const UPLOAD_TIMEOUT = 60_000

// The image decodes, but into nothing (0 × 0, or no visible pixel: a WebP cut down to its header, for instance).
export class EmptyImage extends Error {}

// A named refusal: reason is a key of the form's image_messages (format, too_many, too_heavy, forbidden, failed), or
// "server", whose French text, written by the server (422 { error }), is in detail.
export class Refusal extends Error {
  constructor(reason, detail = "") {
    super(reason)
    this.reason = reason
    this.detail = detail
  }
}

// Type announced by the browser, then the article's image count (the editor only), shrink, then weight (UDR-0065 §3.4.3).
// An image the browser cannot decode, or that decodes into nothing, leaves as it is: the server decides (BL-12).
export async function prepareImage(file, { accept, maxSide, maxBytes, full = false }) {
  if (!accept.includes(file.type)) throw new Refusal("format")
  if (full) throw new Refusal("too_many")

  const ready = await shrinkImage(file, { maxSide }).catch((error) => {
    if (error instanceof EmptyImage) return file
    throw error
  })
  if (ready.size > maxBytes) throw new Refusal("too_heavy")
  return ready
}

export async function shrinkImage(file, { maxSide }) {
  const url = URL.createObjectURL(file)
  try {
    const image = new Image()
    image.src = url
    const decoded = await image.decode().then(() => true, () => false)
    if (!decoded) return file
    if (!image.naturalWidth || !image.naturalHeight) throw new EmptyImage()
    return await encode(draw(image, maxSide), file.name)
  } finally {
    URL.revokeObjectURL(url)
  }
}

// XMLHttpRequest: the only way to follow the progress of an upload. 201 { public_id, sgid, url, width, height }.
// A network error, no answer within timeout (ms) or an aborted request is a failure.
export function uploadImage(file, { url, onProgress = () => {}, timeout = UPLOAD_TIMEOUT }) {
  return new Promise((resolve, reject) => {
    const request = new XMLHttpRequest()
    request.open("POST", url)
    request.timeout = timeout
    request.responseType = "json"
    request.setRequestHeader("Accept", "application/json")
    request.setRequestHeader("X-CSRF-Token", document.querySelector("meta[name=csrf-token]")?.content || "")
    request.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) onProgress(Math.round((event.loaded / event.total) * 100))
    })
    request.addEventListener("load", () => {
      const body = request.response || {}
      if (request.status === 201) resolve(body)
      else if (request.status === 422 && body.error) reject(new Refusal("server", body.error))
      else reject(new Refusal(request.status === 403 ? "forbidden" : "failed"))
    })
    for (const type of ["error", "timeout", "abort"]) request.addEventListener(type, () => reject(new Refusal("failed")))
    const data = new FormData()
    data.append("article_image[file]", file)
    request.send(data)
  })
}

// Never cropped, never enlarged. The canvas copies neither the Exif nor the GPS position of the photo.
function draw(image, maxSide) {
  const scale = Math.min(1, maxSide / Math.max(image.naturalWidth, image.naturalHeight))
  const width = Math.max(1, Math.round(image.naturalWidth * scale))
  const height = Math.max(1, Math.round(image.naturalHeight * scale))
  const canvas = Object.assign(document.createElement("canvas"), { width, height })
  const context = canvas.getContext("2d", { willReadFrequently: true })
  context.drawImage(image, 0, 0, width, height)
  if (!visible(context, width, height)) throw new EmptyImage()

  // The white token under the transparent parts: without it, the JPEG would make them black.
  context.globalCompositeOperation = "destination-over"
  context.fillStyle = getComputedStyle(document.documentElement).getPropertyValue("--color-white")
  context.fillRect(0, 0, width, height)
  return canvas
}

function visible(context, width, height) {
  const pixels = context.getImageData(0, 0, width, height).data
  for (let alpha = 3; alpha < pixels.length; alpha += 4) {
    if (pixels[alpha]) return true
  }
  return false
}

// WebP first; a browser that cannot write it returns a PNG: JPEG then.
async function encode(canvas, name) {
  const base = name.replace(/\.[^.]*$/, "") || "image"
  const webp = await toBlob(canvas, "image/webp")
  if (webp.type === "image/webp") return new File([webp], `${base}.webp`, { type: webp.type })

  const jpeg = await toBlob(canvas, "image/jpeg")
  return new File([jpeg], `${base}.jpg`, { type: "image/jpeg" })
}

function toBlob(canvas, type) {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Refusal("failed"))), type, QUALITY)
  })
}
