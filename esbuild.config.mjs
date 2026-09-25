// esbuild — bundle of app/javascript/application.js (jsbundling-rails)
// Stimulus controllers are imported by glob (esbuild-rails): no manifest to edit.
// KaTeX, Trix and Action Text are split into on-demand chunks (ADR-0051 budget). KaTeX fonts
// are copied next to the CSS so Propshaft resolves the url(fonts/…) of katex.min.css; the Trix
// editor CSS becomes builds/trix.css, linked by the edit pages only.
import * as esbuild from "esbuild"
import rails from "esbuild-rails"
import { cpSync } from "node:fs"

const watch = process.argv.includes("--watch")

cpSync("node_modules/katex/dist/fonts", "app/assets/builds/fonts", { recursive: true })
cpSync("node_modules/trix/dist/trix.css", "app/assets/builds/trix.css")

const options = {
  entryPoints: ["app/javascript/application.js"],
  bundle: true,
  minify: true,
  splitting: true,
  chunkNames: "[name]-[hash].digested",
  format: "esm",
  target: ["chrome111", "safari16.4", "firefox128"],
  sourcemap: true,
  outdir: "app/assets/builds",
  publicPath: "/assets",
  plugins: [rails()]
}

if (watch) {
  const context = await esbuild.context(options)
  await context.watch()
} else {
  await esbuild.build(options)
}
