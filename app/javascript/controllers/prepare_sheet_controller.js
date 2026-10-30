// ⚡ FRONT · prepare_sheet_controller — une feuille « Prépare interros » / « Prépare devoirs » : brouillon, indice, refaire, recommencer
// Rôle : garde dans localStorage les réponses non vérifiées de chaque exercice (clé lnclass-prepare-<exercise_public_id>), montre ou cache l'indice, remet à blanc un exercice ou toute la feuille, sans requête
// ADR  : XXXX-sujets-de-devoir-et-verification-sur-la-feuille · UDR : XXXX-feuilles-prepare-interros-et-devoirs §3 (Comportement) · lecture et écriture du stockage sous try/catch : un navigateur qui le refuse ne casse rien
import { Controller } from "@hotwired/stimulus"

const PREFIX = "lnclass-prepare-"

export default class extends Controller {
  static targets = ["exercise"]

  connect() {
    // Un turbo_stream.refresh fusionne la page : le serveur rend l'état corrigé ou vierge, le navigateur remet son brouillon.
    this.restoreAll = this.restoreAll.bind(this)
    document.addEventListener("turbo:morph", this.restoreAll)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.restoreAll)
  }

  // Un exercice arrive (page, ou réponse de la vérification qui remplace le frame) : on lui rend son état.
  exerciseTargetConnected(exercise) {
    this.restore(exercise)
  }

  restoreAll() {
    this.exerciseTargets.forEach((exercise) => this.restore(exercise))
  }

  // Une proposition cochée (QCM, vrai ou faux). Un exercice corrigé ne se modifie plus.
  pick(event) {
    const button = event.currentTarget
    const exercise = this.exerciseOf(button)
    if (this.checked(exercise)) return

    const group = button.parentElement
    if (button.getAttribute("role") === "checkbox") {
      this.mark(button, button.getAttribute("aria-checked") !== "true")
    } else {
      group.querySelectorAll("[data-ps-choice]").forEach((other) => this.mark(other, other === button))
    }
    this.save({ currentTarget: exercise })
  }

  // Un champ rempli prend le trait épais de la maquette ; le brouillon suit chaque frappe.
  save(event) {
    const exercise = event.currentTarget.closest ? this.exerciseOf(event.currentTarget) : event.currentTarget
    if (!exercise || this.checked(exercise)) return

    exercise.querySelectorAll("[data-ps-field]").forEach((input) => input.classList.toggle("ps-input--filled", input.value.trim() !== ""))
    const state = this.read(exercise)
    state.c = [...exercise.querySelectorAll("[data-ps-choice][aria-checked='true']")].map((button) => this.keyOf(button))
    state.t = Object.fromEntries([...exercise.querySelectorAll("[data-ps-field]")].filter((input) => input.value !== "").map((input) => [input.name, input.value]))
    this.write(exercise, state)
  }

  // « Indice » montre ou cache l'encadré pointillé.
  hint(event) {
    const button = event.currentTarget
    const hint = this.exerciseOf(button).querySelector("[data-ps='hint']")
    if (!hint) return

    hint.hidden = !hint.hidden
    button.setAttribute("aria-expanded", String(!hint.hidden))
    button.textContent = hint.hidden ? button.dataset.labelShow : button.dataset.labelHide
  }

  // « Refaire l'exercice » : à blanc dans le navigateur ; la prochaine vérification ouvrira une nouvelle copie.
  redo(event) {
    this.blank(this.exerciseOf(event.currentTarget))
  }

  // « Recommencer cette notion / ce sujet » : tous les exercices de la feuille.
  resetAll() {
    this.exerciseTargets.forEach((exercise) => this.blank(exercise))
  }

  // ---- États ----

  blank(exercise) {
    const copy = exercise.dataset.copy
    this.clear(exercise)
    // Un exercice corrigé par le serveur se souvient de la copie qu'on a remise à blanc : au rechargement, il revient à blanc.
    if (this.checked(exercise)) exercise.dataset.checked = "false"
    this.write(exercise, copy ? { redone: copy } : {})
    this.show(exercise, false)
  }

  restore(exercise) {
    const state = this.read(exercise)
    const copy = exercise.dataset.copy
    if (exercise.dataset.checked === "true") {
      if (copy && state.redone === copy) {
        this.clear(exercise)
        exercise.dataset.checked = "false"
        this.show(exercise, false)
        this.apply(exercise, state)
      } else if (Object.keys(state).length > 0) {
        // Une copie plus récente que le brouillon : celui-ci est périmé.
        this.write(exercise, {})
      }
      return
    }
    this.apply(exercise, state)
  }

  apply(exercise, state) {
    const keys = new Set(state.c || [])
    exercise.querySelectorAll("[data-ps-choice]").forEach((button) => this.mark(button, keys.has(this.keyOf(button))))
    exercise.querySelectorAll("[data-ps-field]").forEach((input) => {
      const value = (state.t || {})[input.name]
      if (value !== undefined) input.value = value
      input.classList.toggle("ps-input--filled", input.value.trim() !== "")
    })
  }

  // Tout ce que la correction avait montré se cache, ce que l'élève fait de nouveau se montre.
  show(exercise, checked) {
    exercise.querySelectorAll("[data-ps='done']").forEach((element) => { element.hidden = !checked })
    exercise.querySelectorAll("[data-ps='blank']").forEach((element) => { element.hidden = checked })
    exercise.querySelectorAll("[data-ps-field]").forEach((input) => { input.readOnly = checked })
    const hint = exercise.querySelector("[data-ps='hint']")
    if (hint) hint.hidden = true
    const button = exercise.querySelector("[data-action='prepare-sheet#hint']")
    if (button) {
      button.setAttribute("aria-expanded", "false")
      button.textContent = button.dataset.labelShow
    }
  }

  clear(exercise) {
    exercise.querySelectorAll("[data-ps-choice]").forEach((button) => this.mark(button, false))
    exercise.querySelectorAll("[data-ps-field]").forEach((input) => {
      input.value = ""
      input.classList.remove("ps-input--filled")
    })
  }

  // La proposition cochée porte aria-checked, et son champ caché part avec le formulaire.
  mark(button, on) {
    button.setAttribute("aria-checked", String(on))
    const hidden = button.querySelector("input[type='hidden']")
    if (hidden) hidden.disabled = !on
  }

  // ---- Aides ----

  exerciseOf(element) {
    return element.closest("[data-prepare-sheet-target='exercise']")
  }

  checked(exercise) {
    return exercise.dataset.checked === "true"
  }

  keyOf(button) {
    return button.querySelector("input[type='hidden']").name + "#" + button.querySelector("input[type='hidden']").value
  }

  storageKey(exercise) {
    return PREFIX + exercise.dataset.exerciseId
  }

  read(exercise) {
    try {
      return JSON.parse(localStorage.getItem(this.storageKey(exercise)) || "{}") || {}
    } catch (_error) {
      return {}
    }
  }

  write(exercise, state) {
    try {
      if (Object.keys(state).length === 0) localStorage.removeItem(this.storageKey(exercise))
      else localStorage.setItem(this.storageKey(exercise), JSON.stringify(state))
    } catch (_error) {
      // Stockage plein ou refusé : l'élève garde ses réponses à l'écran, sans brouillon.
    }
  }
}
