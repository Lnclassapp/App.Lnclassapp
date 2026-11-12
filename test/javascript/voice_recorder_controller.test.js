// UDR-XXXX (assistants du suivi, « Compte rendu dicté ») : le contrôleur voice-recorder enregistre avec MediaRecorder, affiche le minuteur
// et s'arrête à la durée maximale, refuse un fichier trop gros, gère le refus du micro et l'absence de MediaRecorder.
// Lancer : node --test test/javascript/voice_recorder_controller.test.js (aucun navigateur : MediaRecorder, le micro et le DOM sont simulés).
import { test, mock, afterEach, beforeEach } from "node:test"
import assert from "node:assert/strict"
import VoiceRecorderController from "../../app/javascript/controllers/voice_recorder_controller.js"

const MAX_BYTES = 10 * 1024 * 1024
const supported = new Set(["audio/webm;codecs=opus", "audio/mp4", "audio/ogg"])
let recorders
let micError
let revoked

class FakeRecorder {
  static isTypeSupported(type) { return supported.has(type) }
  constructor(stream, options) { this.stream = stream; this.options = options; this.state = "inactive"; this.mimeType = options?.mimeType ?? ""; recorders.push(this) }
  start() { this.state = "recording" }
  stop() {
    this.state = "inactive"
    this.ondataavailable?.({ data: new Blob(["voix"], { type: this.mimeType }) })
    this.onstop?.()
  }
}

function define(name, value) { Object.defineProperty(globalThis, name, { value, configurable: true, writable: true }) }

beforeEach(() => {
  recorders = []
  micError = null
  revoked = []
  supported.clear()
  ;["audio/webm;codecs=opus", "audio/mp4", "audio/ogg"].forEach((type) => supported.add(type))
  define("MediaRecorder", FakeRecorder)
  define("navigator", { mediaDevices: { getUserMedia: async () => { if (micError) throw micError; return { getTracks: () => [{ stop() { this.stopped = true } }] } } } })
  define("DataTransfer", class { constructor() { this.items = { add: (file) => { this.files = [file] } } } })
  define("URL", Object.assign(URL, { createObjectURL: () => "blob:fake", revokeObjectURL: (url) => revoked.push(url) }))
})

afterEach(() => mock.timers.reset())

function group() { return { hidden: true } }

function build({ maxSeconds = 180, maxBytes = MAX_BYTES } = {}) {
  const t = {
    idle: group(), live: group(), done: group(), fallback: group(), error: { hidden: true, textContent: "" },
    timer: { textContent: "00:00" }, preview: { src: "" }, input: { files: [], value: "x" },
  }
  t.idle.hidden = false
  const controller = Object.create(VoiceRecorderController.prototype)
  Object.defineProperties(controller, {
    idleTarget: { value: t.idle }, liveTarget: { value: t.live }, doneTarget: { value: t.done }, fallbackTarget: { value: t.fallback },
    errorTarget: { value: t.error }, timerTarget: { value: t.timer }, previewTarget: { value: t.preview }, inputTarget: { value: t.input },
    maxSecondsValue: { value: maxSeconds }, maxBytesValue: { value: maxBytes },
    deniedMessageValue: { value: "Autorisez le micro" }, tooBigMessageValue: { value: "Trop gros" }, unsupportedMessageValue: { value: "Format non pris en charge" },
  })
  return { controller, t }
}

test("with MediaRecorder available, the recorder is ready and the file fallback stays hidden", () => {
  const { controller, t } = build()
  controller.connect()
  assert.equal(t.idle.hidden, false)
  assert.equal(t.fallback.hidden, true)
})

test("without MediaRecorder, the file fallback is shown and the recorder is hidden", () => {
  define("MediaRecorder", undefined)
  const { controller, t } = build()
  controller.connect()
  assert.equal(t.fallback.hidden, false)
  assert.equal(t.idle.hidden, true)
})

test("a refused microphone shows the message and the file fallback", async () => {
  micError = new Error("NotAllowedError")
  const { controller, t } = build()
  controller.connect()
  await controller.start()
  assert.equal(t.error.hidden, false)
  assert.equal(t.error.textContent, "Autorisez le micro")
  assert.equal(t.fallback.hidden, false)
  assert.equal(recorders.length, 0)
})

test("recording shows the timer, then stopping hands the audio to the form and shows the preview", async () => {
  mock.timers.enable({ apis: ["setInterval"] })
  const { controller, t } = build()
  controller.connect()
  await controller.start()
  assert.equal(t.live.hidden, false)
  assert.equal(t.idle.hidden, true)
  assert.equal(recorders[0].options.mimeType, "audio/webm;codecs=opus")

  mock.timers.tick(65000)
  assert.equal(t.timer.textContent, "01:05")

  controller.stop()
  assert.equal(t.done.hidden, false)
  assert.equal(t.live.hidden, true)
  assert.equal(t.preview.src, "blob:fake")
  assert.equal(t.input.files.length, 1)
  assert.match(t.input.files[0].name, /\.webm$/)
  assert.equal(t.input.files[0].type, "audio/webm;codecs=opus")
})

test("Safari: falls back to audio/mp4, then audio/ogg, then the browser default", async () => {
  mock.timers.enable({ apis: ["setInterval"] })
  supported.delete("audio/webm;codecs=opus")
  let { controller } = build()
  await controller.start()
  assert.equal(recorders.at(-1).options.mimeType, "audio/mp4")
  controller.stop()

  supported.delete("audio/mp4")
  ;({ controller } = build())
  await controller.start()
  assert.equal(recorders.at(-1).options.mimeType, "audio/ogg")
  controller.stop()

  supported.clear()
  ;({ controller } = build())
  await controller.start()
  assert.equal(recorders.at(-1).options, undefined)
  controller.stop()
  assert.match(controller.inputTarget.files[0].name, /\.webm$/)
})

test("stops by itself at the maximum duration", async () => {
  mock.timers.enable({ apis: ["setInterval"] })
  const { controller, t } = build({ maxSeconds: 180 })
  await controller.start()
  mock.timers.tick(179000)
  assert.equal(recorders[0].state, "recording")
  mock.timers.tick(1000)
  assert.equal(recorders[0].state, "inactive")
  assert.equal(t.timer.textContent, "03:00")
  assert.equal(t.done.hidden, false)
})

test("a recording above the size limit is refused and the recorder comes back", async () => {
  mock.timers.enable({ apis: ["setInterval"] })
  const { controller, t } = build({ maxBytes: 2 })
  await controller.start()
  controller.stop()
  assert.equal(t.error.textContent, "Trop gros")
  assert.equal(t.error.hidden, false)
  assert.equal(t.done.hidden, true)
  assert.equal(t.idle.hidden, false)
})

test("retry clears the recording and returns to the ready state", async () => {
  mock.timers.enable({ apis: ["setInterval"] })
  const { controller, t } = build()
  await controller.start()
  controller.stop()
  controller.retry()
  assert.equal(t.idle.hidden, false)
  assert.equal(t.done.hidden, true)
  assert.equal(t.input.value, "")
  assert.deepEqual(revoked, ["blob:fake"])
  assert.equal(t.timer.textContent, "00:00")
})

test("an imported file above the limit or that is not audio is refused, a good one is previewed", () => {
  const { controller, t } = build({ maxBytes: 10 })
  t.input.files = [{ size: 11, type: "audio/webm" }]
  controller.picked()
  assert.equal(t.error.textContent, "Trop gros")
  assert.equal(t.input.value, "")

  t.input.files = [{ size: 5, type: "image/png" }]
  controller.picked()
  assert.equal(t.error.textContent, "Format non pris en charge")

  t.input.files = [{ size: 5, type: "audio/ogg" }]
  controller.picked()
  assert.equal(t.error.hidden, true)
  assert.equal(t.done.hidden, false)
  assert.equal(t.preview.src, "blob:fake")

  t.input.files = []
  controller.picked()
  assert.equal(t.done.hidden, false)
})

test("disconnecting during a recording stops the timer and the microphone", async () => {
  mock.timers.enable({ apis: ["setInterval"] })
  const { controller } = build()
  await controller.start()
  controller.disconnect()
  assert.equal(recorders[0].state, "inactive")
  mock.timers.tick(5000)
  assert.equal(controller.elapsed, 0)
})
