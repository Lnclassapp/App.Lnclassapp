# Journal — Menu ⋮ des enseignants masqué par la ligne suivante

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Pas de PRD, pas d'UDR : le chantier n'a que `memo.md`, `plan.md` et `journal.md` | Cycle bugfix : le comportement attendu existe déjà (UDR-0042, amendement du 2026-09-28) et la correction ne change pas ce que l'UDR décrit | Non |
| 2026-10-04 | Test de reproduction au niveau système, au bureau | L'empilement CSS n'existe que dans un vrai navigateur. Au téléphone, le centre de l'entrée n'est pas recouvert (voir plus bas) : un test au téléphone qui vise le centre passerait sur le code fautif | Non |

## Ce qui a dérapé

- …

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

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | — |
