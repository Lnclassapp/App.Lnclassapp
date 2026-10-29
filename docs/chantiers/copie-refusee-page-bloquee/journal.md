# Journal — Copie refusée : la page ne répond plus

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

### Rapport root cause (2026-10-29)

**Cause en une phrase** : quand Turbo re-rend une page par morphing, il remplace le `<div data-controller="modal">` (sans id) mais garde la `<dialog>` (avec id) toujours dans la couche supérieure ; le nouveau contrôleur ne vérifie pas l'état de sa boîte en se connectant, et l'ancien, déconnecté, n'observe plus la perte de l'attribut `open`.

**Chaîne d'appels** : clic « Vérifier quand même » (`show.html.erb:105`, `form: "copy-form"`) avec `#copy-confirm` ouverte par `showModal()` → POST `/sessions/:id/copy` → `Assessment::ExerciseCopiesController#refuse_copy` rend `exercise_sessions/show` en 422 → Turbo rend la réponse d'un formulaire échoué ; le layout déclare `turbo_refreshes_with method: :morph` (`app/views/layouts/application.html.erb:23`), donc rendu par morphing → idiomorph remplace l'enveloppe de `components/_modal.html.erb:8` et déplace la `<dialog id="copy-confirm">`, puis retire son `open` (absent du HTML serveur) → la boîte reste `:modal`, invisible, toute la page inerte.

**Fichier et ligne** :
- `app/javascript/controllers/modal_controller.js:12-17` (`connect`) : n'appelle pas `syncOpen()` ; le garde-fou `syncOpen` (l. 36-42) ne tient que si le même contrôleur observe la boîte pendant tout le morphing.
- `app/javascript/lib/assessment/copy_sheet.js` : aucune écoute de `turbo:morph` ; le morphing garde le contrôleur de la copie connecté et réécrit `#copy-counter` avec le « 0 » du serveur (`show.html.erb:22`), d'où « 0/5 répondues ».

**Preuve** (test système jetable, journal des événements dans le navigateur) : `attr open → morph → disconnect (ancienne enveloppe) → connect (nouvelle enveloppe) → attr open open=false modal=true`, aucun `syncOpen` ni `close()`. Avec `this.syncOpen()` en tête de `connect` : `close()` appelé, `modal=false`, le clic suivant passe, compteur recalé après saisie.

**Pourquoi aucun test ne l'a vu** : `test/system/assessment/exercise_copy_test.rb` ne joue que le rendu accepté (303) et l'annulation ; le 422 n'est testé qu'en contrôleur (`exercise_copies_controller_test.rb:74`), qui lit le HTML sans navigateur, donc sans `showModal()` ni morphing. Le test de reproduction va en **système**, dans `exercise_copy_test.rb`.

**Effet de bord à surveiller** : toute autre `ui_modal` ouverte lors d'un rendu par morphing (formulaire en 422 soumis depuis une boîte hors frame `modal`) avait le même risque ; le correctif dans `connect` les couvre toutes.

### Correctif et test (Lot A)

- **Test comblé** : `exercise_copy_test.rb`, « copie refusée après la confirmation… » (système : `showModal()` et morphing réels). Rouge d'abord : `la confirmation reste dans la couche supérieure : la page est inerte` (`#copy-confirm` toujours `:modal`). Vert après correctif.
- **Correctif** : `modal_controller#connect` appelle `syncOpen()` ; `copy_sheet` écoute `turbo:morph` (`update()`, retiré dans `destroy`). Les réponses réaffichées par le serveur restent cochées : aucun `restore()` rejoué au morphing.
- **Effets de bord écartés** : suites `test/system/assessment/` et tous les tests système mentionnant une modale relancés, voir verdict dans le rapport de lot.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
