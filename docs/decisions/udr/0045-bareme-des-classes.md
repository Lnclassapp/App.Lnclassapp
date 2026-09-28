# UDR-0045 : Barème des classes — un tableau par ligne du référentiel, public et privé côte à côte, totaux par établissement, modification en modale

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/bareme-classes`](../../chantiers/bareme-classes/prd.md) — critères BC-01 à BC-10 |
| **ADR lié** | [ADR-0058](../adr/0058-bareme-des-classes-en-base.md) · [ADR-0030](../adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md) · [UDR-0006](0006-shell-applicatif-par-role.md) (CRUD Hotwire) · [UDR-0042](0042-actions-de-ligne-dans-un-menu.md) (menu ⋮) · [UDR-0032](0032-gestion-des-niveaux.md), [UDR-0033](0033-gestion-des-series.md) (référentiel) |
| **Remplacé par** | — |

> Numérotation : UDR-0044 est laissée libre à dessein (chantiers parallèles du 2026-09-28, voir ADR-0058).

---

## 1. Contexte

Le nombre de classes créées à l'import d'un établissement ou par la génération des classes manquantes devient modifiable par l'équipe (ADR-0058). Avant d'importer, l'équipe veut voir **ce que recevra un établissement** (« un lycée public aura 89 classes ») et corriger un nombre sans livraison. Deux pièges : croire qu'un changement corrige les établissements déjà dotés, et oublier une ligne nouvelle (une série liée après coup), qui ne donne alors aucune classe.

## 2. Décision

1. **Un écran du référentiel, `/teams/classroom-plan`**, à côté des niveaux, des séries et des matières : tuile de la section « Référentiel » de l'accueil, lien depuis l'aide de l'écran Niveaux.
2. **Un seul tableau, public et privé côte à côte** : une ligne par niveau du premier cycle, une par couple niveau × série liée du second cycle, dans l'ordre des positions puis des noms de série. Deux colonnes de nombres plutôt que deux tableaux : l'équipe compare public et privé d'un coup d'œil, et une ligne se modifie en une fois.
3. **Quatre totaux en tête** : collège public, lycée public, collège privé ou mixte, lycée privé ou mixte — ce que l'équipe vérifie avant un import.
4. **Le garde-fou est écrit** : un bandeau permanent dit que le barème s'applique aux prochains imports et générations et que les classes déjà créées ne changent pas ; la modale le rappelle.
5. **« Non défini » se voit** : badge d'avertissement dans la cellule, et un bandeau qui compte les lignes à renseigner.
6. **Modification en modale**, ouverte par « Modifier » dans le menu ⋮ de la ligne (UDR-0042, UDR-0006) ; la modale porte les deux nombres de la ligne. Pas de saisie en ligne : 30 champs dans un tableau sont illisibles au téléphone.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Routes : `GET /teams/classroom-plan` (`classroom_plan_path`), `GET /teams/classroom-plan/:level_slug(/:series_slug)/edit` (`edit_classroom_plan_line_path`), `PATCH /teams/classroom-plan/:level_slug(/:series_slug)` (`classroom_plan_line_path`) → `Teams::ClassroomPlansController#show`, `#edit`, `#update`.
- `app/views/teams/classroom_plans/show.html.erb`, dans l'ordre :
  1. `ui_page_header` (titre « Barème des classes », sous-titre), sans action ;
  2. `p#classroom-plan-notice` : icône `information-circle` (`mini`, `text-info`) + `.notice` (prochains imports et générations ; classes existantes inchangées ; 0 = aucune classe) ;
  3. `_undefined` : `div#classroom_plan_undefined` (toujours présent, cible Turbo) : vide, ou un `div role="status"` `bg-warning-soft text-ink` avec l'icône `exclamation-triangle` (`text-warning`) et `.undefined` (compte) ;
  4. `_totals` : `ul#classroom_plan_totals` (`grid grid-cols-2 gap-3 lg:grid-cols-4`), `li#classroom_plan_total_<public|private>_<first|both>` : grand nombre (`font-display text-3xl font-extrabold tabular-nums`), libellé (« Collège public », « Lycée public », « Collège privé ou mixte », « Lycée privé ou mixte ») et « classes » ;
  5. conteneur `relative overflow-x-auto rounded-card border border-line bg-white shadow-card` → `table.w-full` (sans largeur minimale ; à 390 px le tableau défile dans son conteneur, jamais la page) : `thead` (Niveau, Série, Public, Privé et mixte, en-tête d'actions `sr-only`) ; `tbody#classroom_plan_lines` ; sans niveau, `#classroom_plan_empty` (`ui_empty_state`, action vers `levels_path`) à la place du tableau.
- `_line_row` : `tr#classroom_plan_line_<level_slug>` ou `tr#classroom_plan_line_<level_slug>_<series_slug>` :
  - niveau (`font-medium text-ink`) ; série (`ui_badge`, ou « — » au premier cycle) ;
  - nombre : `span.tabular-nums` ; `0` en `text-mute` suivi de « aucune classe » (`sr-only`) ; absent : `ui_badge "Non défini", tone: :warning, size: :sm, icon: "exclamation-triangle"` avec `data-plan="undefined"` ;
  - actions : `div.flex.justify-end` → `ui_dropdown(label: "Actions pour <ligne>", id: "classroom-plan-actions-<clé>", fixed: true)` → `ui_dropdown_item "Modifier", href: edit_classroom_plan_line_path, icon: "pencil-square", frame: "modal"`.
  - niveau du second cycle sans série liée : `tr#classroom_plan_line_<level_slug>` dont la cellule (colspan 3) dit « Aucune série liée : aucune classe » avec un lien « Lier des séries » (`series_index_path`) ; **pas de menu**.
- `edit` : `turbo_frame_tag "modal"` → `ui_modal(title: "Barème de « <ligne> »", id: "classroom-plan-line-modal", open: true)` → `form#classroom-plan-line-form` (`scope: :classroom_plan_line`, `PATCH`), `ui_field :public_count` et `:private_count` (`as: :number, min: 0, max: 30, step: 1, inputmode: "numeric", required: true`, indice « 0 à 30. 0 : aucune classe. »), puis `p` de rappel (`.untouched`) ; pied : « Annuler » (`modal#close`) puis « Enregistrer » (`type: :submit, form: "classroom-plan-line-form"`).

**Tokens**
- Aucun nouveau : `text-ink`, `text-mute`, `bg-warning-soft`/`text-warning`, `text-info`, `rounded-card`, `border-line`, `shadow-card`, `rounded-ln`, `bg-mist` (tuiles de totaux), `ui_badge` `:warning`. Icônes `information-circle`, `exclamation-triangle`, `pencil-square`, `calculator` (tuile de l'accueil).

**Comportement**
- `update` succès : Turbo Stream → `turbo_stream_toast` « Barème de « <ligne> » enregistré. » (`success`), `replace` de la ligne, `replace "classroom_plan_totals"`, `replace "classroom_plan_undefined"`. La modale se ferme sur `turbo:submit-end` réussi. Jamais de redirection depuis la modale.
- Saisie invalide : le navigateur refuse d'abord hors de `min`/`max` ; côté serveur, `render :edit, status: :unprocessable_entity` ; erreur sous le champ, valeurs saisies gardées.
- Ligne inconnue : 404 (`render_not_found`) à l'ouverture comme à l'envoi.
- Repli sans Turbo : `update` redirige vers `classroom_plan_path` en 303 avec `notice`.
- Non-équipe : 403 (`render_result`).

**États obligatoires**
- Vide : aucun niveau → `ui_empty_state` « Aucun niveau pour l'instant » + « Créez d'abord les niveaux et les séries : le barème en découle. », action « Ouvrir les niveaux » ; totaux à 0.
- Chargement : sans objet (page rendue côté serveur ; modale chargée dans le frame `modal`, `aria-busy` pendant l'envoi).
- Erreur : 422 dans la modale (« doit être un nombre entier de 0 à 30 ») ; 404 ; 403.
- Succès : toast, ligne et totaux mis à jour sans rechargement.

**Accessibilité**
- Tableau : `th scope="col"` ; niveau en `th scope="row"`. En-tête d'actions `sr-only`, contenu par le `relative` du conteneur (pas de défilement horizontal de la page à 390 px ; le tableau défile dans son conteneur).
- Bouton ⋮ : `aria-label` « Actions pour 6ème » / « Actions pour Tle D », cible 48 px (UDR-0042).
- « Non défini » est un texte, jamais la seule couleur ; « 0 » est complété de « aucune classe » pour les lecteurs d'écran.
- Champs numériques : `label` visible, indice lié par `aria-describedby`, erreur par `aria-invalid` (`ui_field`).

## 4. Conséquences

- Accueil équipe (UDR-0018) : la section « Référentiel » gagne une cinquième tuile, « Barème des classes » (icône `calculator`), dont le nombre est le total d'un lycée public ; grille `grid-cols-2 sm:grid-cols-3 xl:grid-cols-5`.
- Écran Niveaux (UDR-0032) : le badge « Hors génération des classes » (code inconnu de l'ancienne constante) devient « Hors barème » : aucun nombre positif au barème, public ou privé. L'aide de l'écran renvoie vers « Barème des classes » ; la modale de modification ne parle plus de code reconnu.
- Interdit désormais : afficher ou documenter un nombre de classes par défaut en dur (« lycée public 77 ») ailleurs que dans cet écran ; l'aide du format d'import renvoie vers le barème.
- Preuve : `test/system/teams/classroom_plan_test.rb` (modifier un nombre au menu ⋮, totaux, pas de rechargement, puis générer ; erreur 422 ; téléphone 390 px sans défilement latéral), `test/controllers/teams/classroom_plans_controller_test.rb`.

## Amendement du 2026-09-28 — accès depuis l'écran Établissements

*Demande du porteur du 2026-09-28, même chantier. En cas d'écart avec ce qui précède, cette section fait foi.*

- L'écran Établissements donne aussi accès au barème : entrée « Barème des classes » (icône `calculator`) du menu **« Classes »** de son en-tête, à droite de « Importer des établissements », à côté de « Générer les classes manquantes » (UDR-0043, amendement du même jour). Menu libellé avec chevron plutôt qu'un ⋮ : ce sont des actions de page, pas d'objet (UDR-0042) ; `fixed: true`, parce que l'en-tête se replie au téléphone.
- Preuve : `test/system/teams/classroom_plan_test.rb` (« the « Classes » menu of the schools screen leads to the barème ») et `test/system/school/generate_classrooms_test.rb` (390 px).
