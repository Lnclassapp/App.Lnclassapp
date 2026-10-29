// ⚡ FRONT · lib/assessment/copy_sheet — la logique de la copie de l'élève, chargée à la demande par assessment/copy_controller
// Rôle : brouillon dans `localStorage[key]`, compteur des questions répondues, confirmation « Vérifier ta copie ? » des questions vides
// UDR  : 0138 §3.2 · ADR : 0051 (import dynamique), 0112 §4.5 · le contrôleur Stimulus lui prête ses cibles et ses valeurs
const ANSWER_FIELDS = /^copy\[answers\]/

export class CopySheet {
  constructor(controller) {
    this.c = controller
    this.confirmed = false
    this.restore()
    this.update()
    if (this.c.hasErrorsTarget) this.c.errorsTarget.focus()
    this.dialog = this.c.element.querySelector("#copy-confirm")
    this.resume = () => this.focusFirstEmpty()
    this.dialog?.addEventListener("close", this.resume)
    // Un 422 re-rend la copie par morphing : le serveur réécrit le compteur (« 0 »), on le recale sur les réponses réaffichées.
    this.refresh = () => this.update()
    document.addEventListener("turbo:morph", this.refresh)
  }

  destroy() {
    document.removeEventListener("turbo:morph", this.refresh)
    this.dialog?.removeEventListener("close", this.resume)
  }

  // Les champs de réponse, dans l'ordre du formulaire.
  fields() {
    return [...this.c.element.querySelectorAll("input, select, textarea")].filter((field) => ANSWER_FIELDS.test(field.name))
  }

  storage() {
    try {
      return window.localStorage
    } catch {
      return null
    }
  }

  // { nom: [valeurs] } : les valeurs cochées d'une case ou d'un bouton radio, la valeur de chaque autre champ du même nom, dans l'ordre.
  save() {
    this.update()
    const draft = {}
    this.fields().forEach((field) => {
      draft[field.name] ??= []
      if (["checkbox", "radio"].includes(field.type)) {
        if (field.checked) draft[field.name].push(field.value)
      } else {
        draft[field.name].push(field.value)
      }
    })
    try {
      this.storage()?.setItem(this.c.keyValue, JSON.stringify(draft))
    } catch {
      // Stockage plein ou refusé : la copie se remplit quand même, sans brouillon.
    }
  }

  restore() {
    let draft
    try {
      draft = JSON.parse(this.storage()?.getItem(this.c.keyValue) ?? "null")
    } catch {
      return
    }
    if (!draft || typeof draft !== "object") return

    const seen = {}
    this.fields().forEach((field) => {
      const values = draft[field.name]
      if (!Array.isArray(values)) return

      if (["checkbox", "radio"].includes(field.type)) {
        field.checked = values.includes(field.value)
      } else {
        const rank = (seen[field.name] = (seen[field.name] ?? -1) + 1)
        if (typeof values[rank] === "string") field.value = values[rank]
      }
      // Les contrôleurs par type (nombre, ordre, relier) se recalent sur ce qui vient d'être remis.
      field.dispatchEvent(new Event("input", { bubbles: true }))
      field.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }

  // Une question est répondue quand sa saisie est complète (UDR-0087 §3.4) ; l'ordre l'est toujours.
  answered(question) {
    const expected = question.querySelector("[data-expected-count]")
    if (expected) {
      return question.querySelectorAll("input[type=checkbox]:checked").length === Number(expected.dataset.expectedCount)
    }
    const fields = [...question.querySelectorAll("input, select")].filter((field) => ANSWER_FIELDS.test(field.name))
    if (fields.some((field) => field.type === "radio")) return fields.some((field) => field.checked)

    return fields.length > 0 && fields.every((field) => field.value.trim() !== "" && field.checkValidity())
  }

  emptyQuestions() {
    return this.c.questionTargets.filter((question) => !this.answered(question))
  }

  update() {
    if (!this.c.hasCounterTarget) return

    const answered = this.c.questionTargets.length - this.emptyQuestions().length
    this.c.counterTarget.textContent = this.c.counterValue.replace("%{answered}", answered).replace("%{total}", this.c.totalValue)
  }

  submit(event) {
    const empty = this.emptyQuestions()
    if (this.confirmed || empty.length === 0 || !this.dialog) return

    event.preventDefault()
    const text = empty.length === 1 ? this.c.missingOneValue : this.c.missingOtherValue.replace("%{count}", empty.length)
    this.c.missingTarget.textContent = text
    this.dialog.showModal()
  }

  // « Rendre quand même » : le formulaire repart sans redemander.
  confirm() {
    this.confirmed = true
  }

  // « Continuer ma copie » ou Échap : le focus va à la première question vide.
  focusFirstEmpty() {
    if (this.confirmed) return

    this.emptyQuestions()[0]?.querySelector("input:not([type=hidden]), select, button")?.focus()
  }

  // Rendu accepté ou refusé par le serveur : un succès efface le brouillon ; le réseau absent le garde et le dit.
  done(event) {
    this.confirmed = false
    if (event.detail.success) {
      try {
        this.storage()?.removeItem(this.c.keyValue)
      } catch {
        // Rien à effacer si le stockage est refusé.
      }
    } else if (!event.detail.fetchResponse && this.c.hasOfflineTarget) {
      document.getElementById("toasts")?.append(this.c.offlineTarget.content.cloneNode(true))
    }
  }
}
