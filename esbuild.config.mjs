// esbuild — bundle of app/javascript/application.js (jsbundling-rails)
// Stimulus controllers are imported by glob (esbuild-rails): no manifest to edit.
// KaTeX is split into an on-demand chunk (ADR-0051 budget); its fonts are copied
// next to the CSS so Propshaft resolves the url(fonts/…) of katex.min.css.
import * as esbuild from "esbuild"
import rails from "esbuild-rails"
import { cpSync } from "node:fs"

const watch = process.argv.includes("--watch")

cpSync("node_modules/katex/dist/fonts", "app/assets/builds/fonts", { recursive: true })

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
