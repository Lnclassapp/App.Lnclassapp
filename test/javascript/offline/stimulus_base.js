// Prête la classe Controller de Stimulus aux contrôleurs hors ligne, comme offline/lazy_controllers.js dans le navigateur ; à importer en premier.
import { Controller } from "@hotwired/stimulus"

globalThis.__lnclassStimulusController = Controller
