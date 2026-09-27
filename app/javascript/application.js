// 🌐 UI · application.js — point d'entrée unique du JavaScript (esbuild)
// Rôle : Turbo et les contrôleurs Stimulus ; rien d'autre, pour tenir le budget de l'ADR-0051
// ADR  : 0051 · Trix reviendra en import dynamique, sur les seules pages qui éditent du texte riche
import "@hotwired/turbo-rails"
import "./controllers"
