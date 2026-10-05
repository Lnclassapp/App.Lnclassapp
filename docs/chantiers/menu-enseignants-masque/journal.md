# Journal — Menu ⋮ des enseignants masqué par la ligne suivante

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Pas d'UDR : le chantier n'a que `memo.md`, `plan.md` et `journal.md` | Cycle bugfix : le comportement attendu existe déjà (UDR-0042, amendement du 2026-09-28) et la correction ne change pas ce que l'UDR décrit | Non |
| 2026-10-04 | Le chantier n'a pas de `prd.md` : copié du gabarit avec `pr-faq.md`, il est retiré comme lui | Cycle bugfix, « Pas de PRD » (`docs/workflows/bugfix.md`, phase 2) : un PRD vide aurait laissé croire à une spec manquante | Non |
| 2026-10-04 | Test de reproduction au niveau système, au bureau | L'empilement CSS n'existe que dans un vrai navigateur. Au téléphone, le centre de l'entrée n'est pas recouvert (voir plus bas) : un test au téléphone qui vise le centre passerait sur le code fautif | Non |

## Ce qui a dérapé

- **Un test au téléphone n'aurait rien prouvé.** Premier essai de reproduction à 390 px : le test passait sur le code fautif, parce que le centre de l'entrée échappe à la cellule collante (voir plus bas). La capture montrait pourtant le défaut. D'où le test au bureau, où le centre est recouvert.
- **Bannière Puma et durée perdue.** Pour `script/ci/record_timings`, la bannière de Capybara (« Capybara starting Puma... » et les lignes `* …`) coupe la ligne verbeuse du premier test. Un premier `sed` qui retirait aussi l'espace avant « Capybara » cassait le motif `… = ` de la ligne : la durée du premier test (3,54 s, démarrage de Puma compris) n'était pas comptée (6,7 s enregistrées au lieu de 10,2). Il faut retirer « Capybara starting Puma... » **en gardant l'espace qui suit le `=`**, puis les lignes `* …`.
- **Durée enregistrée gonflée par la machine.** `teachers_test.rb` passe de 4,5 s à 10,2 s : le nouveau test pèse 1,98 s, les trois anciens 8,2 s ici contre 4,5 s enregistrées. La garde compte + 5,7 s, dans le budget de 15 s, mais l'écart vient surtout de la machine de session. Un réenregistrement depuis la CI rétablira une valeur comparable aux autres fichiers.

## Ce qu'on a appris sur la codebase

### Rapport de root cause (2026-10-04)

**Cause, en une phrase** : la cellule d'actions est collante (`position: sticky`) sans l'utilitaire `sticky-actions`, donc sans la règle qui la fait passer au-dessus des autres cellules quand son menu est ouvert.

**Chaîne de rendu** : `SchoolAdmin::TeachersController#index` → `app/views/school_admin/teachers/index.html.erb`, colonne d'actions : `<th class="sticky right-0 bg-white …">` (ligne 22) et `<td class="sticky right-0 bg-white px-4 py-3 text-right">` (ligne 41) → `ui_dropdown(…, fixed: true)` (`app/views/components/_dropdown.html.erb`), dont le menu est en `z-50` et que `dropdown_controller.js#place` passe en `position: fixed` sous le bouton.

**Pourquoi le menu passe dessous** : `position: sticky` crée un contexte d'empilement. Le `z-50` du menu ne vaut qu'à l'intérieur de sa cellule. Toutes les cellules collantes sont au même niveau (`z-index: auto`) dans le contexte de la page, peintes dans l'ordre du document : la cellule de la ligne suivante est peinte après, donc par-dessus la cellule de la ligne courante et tout ce qu'elle contient, menu compris. Son fond blanc (`bg-white`) masque la partie du menu qui la chevauche et prend les clics. L'utilitaire `sticky-actions` (`app/assets/stylesheets/application.tailwind.css`) ajoute `&:has([aria-expanded="true"]) { z-index: 50 }` : menu ouvert, la cellule monte au-dessus de ses voisines.

**Point fautif** : `app/views/school_admin/teachers/index.html.erb:22` et `:41`, introduits par `e0dac4ac` (2026-10-01). Ce commit a recopié la moitié visible de `sticky-actions` (collé à droite, fond blanc) sans sa règle d'empilement.

**Pourquoi aucun test ne l'a vu** : les tests système de l'écran (`test/system/school_admin/teachers_test.rb`) n'ont que deux enseignants et ouvrent le menu d'Awa Koné, la dernière ligne (tri par nom : Brou, Koné). Le menu de la dernière ligne ne chevauche aucune cellule. Le test ajouté par `e0dac4ac` mesure seulement la position du ⋮ à 390 px, menu fermé. Les tests de l'équipe (`test/system/teams/row_actions_menu_test.rb`) ouvrent aussi la dernière ligne. Le test de reproduction comble ce trou : trois enseignants, menu de la ligne du milieu.

### Étendue (2026-10-04)

`grep -rn "sticky right-0" app/views` : deux occurrences, toutes deux dans `school_admin/teachers/index.html.erb` (l'en-tête et la cellule de la colonne d'actions), donc le bug signalé lui-même. Aucun autre tableau n'a ce défaut :

- les tableaux de l'équipe (DRENA, établissements, séries, niveaux, matières, articles) portent déjà `sticky-actions` sur l'en-tête et les cellules ;
- `grep -rn "sticky" app` ne trouve, à part eux, que des en-têtes de page (`sticky top-0`) ;
- les autres menus `fixed: true` sans `sticky-actions` ne sont pas collants, donc sans contexte d'empilement : leur menu `z-50` passe au-dessus. Ce n'est pas le même défaut (voir « Dette laissée derrière » pour `teams/classroom_plans`).

Aucune occurrence identique à corriger en plus.

### Au téléphone, le centre de l'entrée n'est pas recouvert

À 390 px, la cellule collante de la ligne suivante fait la largeur du ⋮ et de ses marges, plus étroite que le menu (256 px) aligné sur le bord droit du bouton. Elle masque le tiers droit de l'entrée (« …issement »), pas son centre. Mesuré sur le code fautif : centre de l'entrée en x = 225, cellule à partir de x ≈ 265. Au bureau, la colonne d'actions s'élargit avec le tableau (`w-full`) et recouvre le centre. D'où un test de reproduction au bureau.

### Correctif et preuves (2026-10-04)

- **Rouge** (code d'avant, `c731adfa^`) : `bin/rails test test/system/school_admin/teachers_test.rb -i /middle/` → 1 échec, 0 erreur, ligne 60 : « « Retirer de l'établissement » est masqué par la ligne suivante ». Les cinq assertions précédentes passent : trois lignes, Awa Koné au milieu, menu ouvert, entrée trouvée. Capture : le menu coupé à « Retir », la cellule de « Fanta Touré » par-dessus.
- **Correctif** : `sticky-actions` sur le `<th>` et les `<td>` de la colonne d'actions (`text-right` gardé sur la cellule), commentaire de la vue complété. En-tête HITL inchangé : il cite déjà l'UDR-0042 et son rôle n'a pas bougé.
- **Vert** : les 4 tests de `teachers_test.rb` ; les tests système de la direction et `design_system_test.rb`, 48 tests, 0 échec ; suite complète, 3 983 tests, 0 échec, 0 erreur, 8 sauts (tests de performance sans `PERF=1`, déjà présents), couverture 100 % lignes (12 155/12 155) et 100 % branches (3 149/3 149) ; RuboCop, aucune remarque ; `COVERAGE=0 bin/rails test test/guards`, 25 tests, 0 échec.
- **Rejoué à 390 px** après correctif : menu de la ligne du milieu ouvert, `elementFromPoint` renvoie l'entrée à 10 %, 50 % et 90 % de sa largeur ; la capture montre l'entrée entière au-dessus de la ligne « Fanta Touré ».
- **Effets de bord écartés** : `sticky-actions` ne change que l'empilement menu ouvert ; position collante et fond blanc sont les mêmes que `sticky right-0 bg-white`. Le test « ⋮ à l'écran à 390 px » et les retraits depuis la dernière ligne restent verts. La CSS compilée contient déjà l'utilitaire, utilisé par les tableaux de l'équipe.

### Collision attendue avec `perf/ecrans-direction-lents`

Cette branche réécrit les lignes de la même vue (lignes sans indentation, confirmation chargée à la demande, levier 3b) et garde `sticky right-0 bg-white` sur la cellule. À la fusion de l'une après l'autre :

- garder `sticky-actions` sur le `<th>` et sur la ligne `<td …>` désindentée ;
- adapter le test de reproduction : la confirmation vit dans `turbo-frame#modal`, et ses clés deviennent `removal.title` et `removal.cancel` au lieu de `index.remove_title` et `index.cancel`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `teams/classroom_plans` (barème) : tableau dans un conteneur `overflow-x-auto`, menu ⋮ `fixed: true` par ligne, mais colonne d'actions **non collante**. Pas le défaut de ce chantier (aucune cellule collante, donc aucun menu masqué) ; mais l'amendement du 2026-09-28 de l'UDR-0042 veut `sticky-actions` sur tout tableau qui défile en largeur avec un ⋮ par ligne. Non vérifié à 390 px | Hors du bug signalé, et pas une correction identique en une classe : il faut d'abord mesurer si le ⋮ sort de l'écran | À ouvrir : `/bugfix bareme-menu-telephone` ou à joindre au prochain chantier sur le barème |
| Les tests des tableaux à menu ⋮ (`teams/row_actions_menu_test.rb`) ne vérifient la cible d'une entrée (`reachable?`) que sur la dernière ligne ; le test qui ouvre la première ligne à 390 px vérifie que le menu est visible, pas qu'aucune ligne suivante ne le recouvre. `sticky-actions` protège ces tableaux aujourd'hui, mais aucun test ne garde leur empilement | Un test par écran dépasserait le bug signalé et le budget système | À joindre au prochain chantier qui touche `row_actions_menu_test.rb` |
| Durée de `teachers_test.rb` mesurée sur la machine de session (10,2 s) | Aucune mesure CI disponible ici | Réenregistrer depuis les logs de la CI (`gh run view <id> --log \| script/ci/record_timings`) |

## Clôture

| | |
|---|---|
| **Livré le** | — *(commité le 2026-10-04 sur `fix/menu-enseignants-masque`, non poussé)* |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | — |
