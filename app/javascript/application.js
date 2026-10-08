// 🌐 UI · application.js — point d'entrée unique du JavaScript (esbuild)
// Rôle : Turbo, les contrôleurs Stimulus et l'enregistrement du programme d'arrière-plan ; rien d'autre (budget ADR-0051)
// ADR  : 0051, 0082 · Trix reviendra en import dynamique, sur les seules pages qui éditent du texte riche
import "@hotwired/turbo-rails"
import "./controllers"
import "./pwa"
