# UDR-0172 : Supprimer une leçon depuis sa page — entrée du menu ⋮, confirmation et refus en modale
<!-- index
titre: Supprimer une leçon depuis sa page
statut: Accepté
adr-lie: XXXX-suppression-d-une-lecon-sans-activite-eleve
problematique: l'équipe doit pouvoir supprimer une leçon sans activité d'élève, sans risque de clic malheureux, et savoir quoi faire quand c'est refusé.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-14 |
| **Chantier** | `docs/chantiers/suppression-lecon` |
| **ADR lié** | ADR-0136 |
| **Remplacé par** | — |

---

## 1. Contexte

Sur la page d'une leçon, le menu ⋮ de l'équipe propose « Modifier », « Corrigé », les transitions (« Publier », « Archiver ») et « Tout publier ». Une leçon à refaire ne peut pas être supprimée. La suppression est définitive : un clic malheureux ne doit pas suffire, et un refus doit dire quoi faire à la place.

## 2. Décision

Une entrée « Supprimer » en ton danger, **dernière** du menu (après « Tout publier »), ouvre une modale lue à la demande dans le frame `modal` (comme la suppression d'une DRENA ou d'un établissement). La modale vérifie l'activité **dès l'ouverture** : si la leçon a servi, elle n'affiche jamais de bouton « Supprimer » mais le refus et « Modifier la fiche de cours ». Une confirmation réussie quitte la page (qui n'existe plus) pour le catalogue. Pas de toast seul pour le refus : le lien « Modifier la fiche de cours » doit être sous les yeux.

## 3. Règles d'implémentation

**Structure**
- Entrée de menu : `app/views/catalog/courses/_role_actions.html.erb`, après « Tout publier » :
  `ui_dropdown_item t(".delete"), href: deletion_teams_course_path(course.slug), icon: "trash", tone: :danger, frame: "modal"`. Affichée pour tout statut.
- Modale : `app/views/teams/courses/deletion.html.erb`, rendue dans `turbo_frame_tag "modal"`, `ui_modal id: "delete-course-<slug>", size: :sm, open: true`. Corps commun aux deux états dans le partiel `teams/courses/_deletion_dialog.html.erb` (locals `course:`, `refused:`).
- Sans frame (sans JavaScript) : page complète avec le lien « Retour à la fiche de cours » (`course_path(slug)`) au-dessus, comme `teams/drenas/deletion`.

**États**
- **Confirmation** (aucune activité) — titre `Supprimer la fiche de cours « <nom> » ?` ; paragraphe `text-sm text-mute` : « La fiche de cours, ses fiches de révision, ses exercices, ses sujets et ses images seront supprimés définitivement. Vous pourrez la réimporter depuis Imports. » ; pied : `ui_button "Annuler", variant: :secondary, data: { action: "modal#close" }` puis formulaire `form_with url: teams_course_path(slug), method: :delete, data: { turbo_frame: "_top" }` contenant `ui_button "Supprimer définitivement", type: :submit, variant: :danger, icon: "trash"`.
- **Refus** (activité d'élève) — titre `Cette fiche de cours ne peut pas être supprimée` ; paragraphe : « Des élèves se sont déjà servis de « <nom> » (exercices, lectures, devoirs). Pour la corriger, modifiez-la. » ; pied : `ui_button "Fermer", variant: :secondary, data: { action: "modal#close" }` puis `ui_button "Modifier la fiche de cours", href: edit_teams_course_path(slug), variant: :primary, icon: "pencil-square", data: { turbo_frame: "modal" }`.
- **Succès** — `303` vers `courses_path` ; flash `notice` : « Fiche de cours « <nom> » supprimée. Vous pouvez la réimporter depuis Imports. »
- **Refus à la confirmation** (activité apparue entre-temps) — `422`, Turbo Stream : `turbo_stream.update "modal"` avec l'état Refus et un toast d'erreur « La fiche de cours « <nom> » a servi à des élèves : elle n'est pas supprimée. » ; en HTML : `303` vers `course_path(slug)` avec ce message en `alert`.
- **Erreur** — leçon introuvable : page 404 (`render_not_found`, qui quitte le frame `modal`). Vide et chargement : sans objet (la modale est une réponse serveur ; le frame `modal` garde son état de chargement commun).

**Tokens**
- Composants seulement (`ui_modal`, `ui_button`, `ui_dropdown_item`) ; aucune couleur en dur. Ton `danger` de l'entrée et du bouton, `text-mute` pour le corps.

**Accessibilité**
- La modale porte le titre visible comme nom accessible (`ui_modal`), focus sur le premier bouton du pied à l'ouverture (comportement du composant).
- Cibles ≥ 48 px (`ui_button` taille `md`). Le bouton destructif est le dernier du pied, jamais le focus initial.
- L'entrée de menu a `role="menuitem"` (composant).

## 4. Conséquences

- Le menu ⋮ de la leçon a une entrée destructive : toujours la dernière, en ton danger, jamais sans modale.
- Toute future suppression de contenu suit ce modèle : refus montré à l'ouverture, alternative proposée en bouton, succès qui quitte la page supprimée.

> Vocabulaire : les libellés à l'écran disent « fiche de cours » et « fiches de révision », jamais « leçon » ni « notion » (UDR-0007, UDR-0130, gardé par `test/i18n/locale_files_test.rb`). Ce document garde « leçon » pour le métier.
