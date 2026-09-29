# UDR-0042 : Actions de ligne dans un menu ⋮ — modifier, désactiver et supprimer un objet

| | |
|---|---|
| **Statut** | Accepté *(décision du porteur du 2026-09-28)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/actions-en-menu`](../../chantiers/actions-en-menu/prd.md) — critères AM-01 à AM-06 |
| **ADR lié** | — · [UDR-0005](0005-design-system-fondateur.md) (menu déroulant, modale) · [UDR-0006](0006-shell-applicatif-par-role.md) (CRUD en modale) |
| **Remplacé par** | — |

---

## 1. Contexte

Les écrans de l'équipe rangeaient les gestes sur un objet chacun à sa façon : trois boutons texte par ligne (DRENA, séries, niveaux, matières), trois icônes à libellé caché (établissements), un bouton « Modifier » seul dans l'en-tête d'une fiche essentielle ou d'un exercice, alors que la page d'un cours les regroupait déjà dans un menu ⋮. « Supprimer » était à un clic distrait de « Modifier », et la colonne d'actions élargissait les tableaux. Le porteur veut les modifications et suppressions dans un menu ouvert par l'icône `ellipsis-vertical`.

## 2. Décision

**Toute action de modification, de désactivation ou de suppression d'un objet vit dans le menu ⋮ de cet objet, même quand elle est seule.** Le menu est le `ui_dropdown` existant, sans `trigger:` (bouton icône `ellipsis-vertical`), nommé « Actions pour <nom de l'objet> ». Ses entrées gardent un libellé visible, contrairement aux icônes à libellé caché qu'elles remplacent.

Les confirmations ne changent pas : ce sont toujours les `<dialog>` de la ligne ou de l'en-tête (UDR-0006, jamais `confirm()`), rendues **sans** déclencheur. Une entrée de menu les ouvre.

Restent **hors** du menu, parce qu'ils ne sont pas une action sur un objet existant : les créations et imports (« Nouvelle DRENA », « Nouvel exercice », « Importer des exercices », « Ajouter une classe »), le panneau de statut du contenu (publier, archiver), les bascules (matrice niveaux × séries, déclaration des classes), les liens de navigation (« Modifier mes classes » de l'accueil enseignant) et les boutons de la page « Mon profil », qui modifient chacun un champ de la carte.

Un menu plutôt qu'une rangée d'icônes : le libellé reste lisible, la destruction s'éloigne du geste courant, et la colonne d'actions tient dans 48 px quel que soit le nombre d'actions.

## 3. Règles d'implémentation

**Structure**
- Composant de référence : `app/views/components/_dropdown.html.erb` via `ComponentsHelper`.
- Cellule d'actions d'une ligne : `<td class="px-4 py-3">` → `div.flex.justify-end` → `ui_dropdown(label: t(".actions", name:), id: "<objet>-actions-<clé>", fixed: true)` ; puis, frères du menu dans la même cellule, les `ui_modal` de confirmation **sans `trigger:`**, avec leurs ids inchangés (`delete-drena-<public_id>`, `deactivate-school-<public_id>`, `delete-school-<public_id>`, `delete-series-<slug>`, `delete-level-<slug>`, `delete-material-<slug>`).
- Ordre des entrées : « Modifier » (`pencil-square`), « Désactiver » (`no-symbol`, seulement si l'action existe pour l'objet), « Supprimer » (`trash`, tonalité `:danger`, toujours en dernier).
- En-tête d'une page d'objet : le menu ⋮ vient **après** les boutons de création/import et le panneau de statut. Ids : `school-header-actions` (fiche établissement : Modifier, Désactiver si actif ; confirmation `deactivate-school-header`), `essential-actions-menu` (fiche essentielle : Modifier), `exercise-actions-menu` (exercice : Modifier).

**API**
- `ui_dropdown(label:, icon: "ellipsis-vertical", trigger: nil, align: :end, id: nil, fixed: false)` — `fixed: true` pour tout menu dans un conteneur qui défile (`overflow-x-auto`) ou dans un en-tête qui se replie au téléphone.
- `ui_dropdown_item(label, href: nil, icon: nil, method: nil, tone: :default, frame: nil, dialog: nil)` :
  - `frame: "modal"` → `<a role="menuitem" data-turbo-frame="modal" data-action="dropdown#dismiss">` : ferme le menu, rend le focus au ⋮, puis la modale d'édition se charge dans le frame ;
  - `dialog: "<id>"` → `<button type="button" role="menuitem" aria-haspopup="dialog" aria-controls="<id>" data-action="dropdown#openDialog" data-dropdown-dialog-param="<id>">` : ferme le menu, rend le focus au ⋮, puis `showModal()` sur la `<dialog>` ;
  - `tone: :danger` → `text-error`, survol et focus `bg-error-soft`.

**Tokens**
- Aucune couleur en dur : `text-ink`/`text-error`, `bg-mist`/`bg-error-soft`, `rounded-ln`, `shadow-pop`, `border-line` (UDR-0005).
- Menu fixe en `z-50`, au-dessus de l'en-tête collant et de la barre basse (`z-40`) ; menu ordinaire en `z-30`, inchangé.

**Comportement**
- `dropdown_controller.js` : `dismiss()` (ferme, focus au bouton), `openDialog({ params: { dialog } })` (dismiss puis `showModal()`), `place()` (menu `fixed`) : position fixe sous le bouton, aligné à son bord droit (`align: :end`), ou au-dessus s'il manque de place en bas ; jamais à moins de 8 px du bord de l'écran ; recalculée au défilement de n'importe quel conteneur (`scroll@window…:capture`) et au redimensionnement.
- Turbo : inchangé. « Modifier » vise le frame `modal` ; les confirmations envoient leur formulaire, la réponse Turbo Stream remplace ou retire la ligne (et le menu qu'elle contient). Aucun rechargement.
- Sans JS : le menu ne s'ouvre pas (comme tout `ui_dropdown`) ; hors périmètre, l'application exige JS pour ses modales (UDR-0006).

**États obligatoires**
- Vide : pas de ligne, pas de menu (états vides des écrans inchangés).
- Chargement : la modale d'édition se charge dans le frame `modal` (inchangé).
- Erreur : suppression refusée → toast `error` avec la raison, la ligne et son menu restent.
- Succès : toast, ligne remplacée ou retirée par Turbo Stream.

**Accessibilité**
- Bouton ⋮ : `aria-haspopup="menu"`, `aria-expanded`, `aria-controls`, `aria-label="Actions pour <nom>"` ; cible `size-tap` (48 px).
- Entrées `role="menuitem"`, `tabindex="-1"`, `min-h-tap` (48 px), libellé visible ; flèches, Début, Fin, Échap et Tab (UDR-0005).
- Focus : le menu rend le focus au ⋮ avant d'ouvrir une modale ; à la fermeture de la `<dialog>`, le navigateur le rend au ⋮.
- Preuve : `test/system/teams/row_actions_menu_test.rb` (suppression depuis le menu de la dernière ligne, parcours clavier, téléphone 390 px) ; `test/helpers/components_helper_test.rb`.

## 4. Conséquences

- Un nouvel écran qui liste des objets modifiables ou supprimables met leurs actions dans un menu ⋮ par ligne, selon le §3. Une action seule n'y échappe pas.
- Interdit désormais : un bouton « Modifier », « Désactiver » ou « Supprimer » en ligne dans un tableau ou dans l'en-tête d'un objet ; une icône d'action à libellé caché (`sr-only`) ; une place vide pour aligner des icônes ; un `link_to role="menuitem"` écrit à la main à la place d'`ui_dropdown_item`.
- Les clés `edit_label` des lignes et des pages converties disparaissent : c'est le bouton ⋮ qui nomme l'objet (clé `actions`).
- Les UDR 0005, 0015, 0021, 0032, 0033, 0034, 0035 et 0036 portent un amendement du 2026-09-28 qui renvoie ici.

## Amendement du 2026-09-28

*Chantier [`docs/chantiers/finitions-generation-menu`](../../chantiers/finitions-generation-menu/memo.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Colonne d'actions collante.** À 390 px, les tableaux de l'équipe sont plus larges que l'écran : le ⋮, en dernière colonne, n'était atteignable qu'en faisant défiler le tableau. L'en-tête (`<th>`) et chaque cellule (`<td>`) de la colonne d'actions portent désormais l'utilitaire maison `sticky-actions` : `position: sticky; right: 0`, fond `--color-white` qui masque les colonnes qui passent dessous. Le ⋮ de chaque ligne est à l'écran au chargement ; les autres colonnes défilent sous lui. Au bureau, où le tableau tient dans sa carte, rien ne change.
- Structure du §3 : `<td class="sticky-actions px-4 py-3">` → `div.flex.justify-end` → `ui_dropdown(…, fixed: true)`, puis les `ui_modal` de confirmation. Écrans : DRENA, établissements, séries, niveaux, matières.
- **Empilement.** `position: sticky` crée un contexte d'empilement qui enfermerait le menu fixe (`z-50`) sous la barre basse (`z-40`) : tant que son menu est ouvert (`:has([aria-expanded="true"])`), la cellule passe en `z-index: 50`. `ui_dropdown(fixed: true)` et son placement sont inchangés.
- Tout nouveau tableau qui défile en largeur et porte un ⋮ par ligne applique `sticky-actions` à sa colonne d'actions.
- Preuve : `test/system/teams/row_actions_menu_test.rb`, « on a phone, the ⋮ of the first row of every team table is on screen at load, and opens its menu » (rectangle du ⋮ dans l'écran sans défilement horizontal, puis menu ouvert) ; le test « menu … opens whole inside the screen » reste vert.

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Proposé`. Le texte ci-dessus reste tel qu'accepté ; une fois l'UDR-0054 acceptée, cette section fait foi en cas d'écart.*

- **Focus des confirmations** : une `<dialog>` de confirmation ouverte depuis un menu ⋮ place le focus sur « Annuler » (premier bouton de fermeture de son pied), jamais sur la croix (UDR-0054 §3.3). À la fermeture, le focus revient au bouton ⋮ (inchangé).
