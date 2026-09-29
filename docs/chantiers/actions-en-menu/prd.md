# PRD — Actions d'un objet dans un menu ⋮

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Les gestes qui modifient, désactivent ou suppriment un objet sont des boutons en ligne, rangés différemment d'un écran à l'autre ([memo](memo.md)). Ils passent dans un menu ⋮ par objet, comme sur la page d'un cours, y compris quand « Modifier » est seul. Aucune règle métier ne change : mêmes routes, mêmes confirmations, mêmes refus.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | ouvrir le menu ⋮ d'un objet et y choisir « Modifier », « Désactiver » ou « Supprimer » | — (inchangé) |
| Teacher, Student | — | voir ces menus : les écrans sont réservés à l'équipe, inchangé |

Règles d'autorisation inchangées (`Teams::BaseController`, policies des use cases).

## 3. Parcours utilisateur

### Chemin nominal

1. Sur « DRENA », l'équipe ouvre le menu ⋮ « Actions pour Abidjan 1 » de la ligne.
2. Le menu liste « Modifier » puis « Supprimer » (en rouge), libellés visibles, le focus sur la première entrée.
3. « Supprimer » ferme le menu et ouvre la confirmation de la ligne ; « Supprimer la DRENA » supprime, sans rechargement.
4. « Modifier » ferme le menu et ouvre la modale d'édition dans le frame `modal`.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Échap dans la confirmation | elle se ferme, le focus revient au bouton ⋮ de la ligne |
| Échap dans le menu | il se ferme, le focus revient au bouton ⋮ (inchangé, UDR-0005) |
| Suppression refusée (objet utilisé) | toast d'erreur avec la raison, la ligne reste |
| Établissement inactif | son menu n'a pas « Désactiver » |
| Dernière ligne, ou téléphone | le menu s'affiche entier dans l'écran, au-dessus des barres du shell, la page ne défile pas en largeur |

## 4. Critères d'acceptation

```gherkin
# AM-01
Étant donné une DRENA « Bouaké » en dernière ligne du tableau
Quand l'équipe ouvre son menu ⋮ puis choisit « Supprimer »
Alors le menu se ferme et la confirmation « Supprimer la DRENA « Bouaké » ? » s'ouvre
Et « Supprimer la DRENA » la supprime sans rechargement
Et le menu n'était rogné ni par le tableau ni par l'écran

# AM-02
Étant donné le menu ⋮ d'une ligne, ouvert au clavier
Quand l'équipe descend sur « Supprimer », valide, puis appuie sur Échap
Alors la confirmation se ferme, rien n'est supprimé, et le focus est sur le bouton ⋮

# AM-03
Étant donné un tableau de DRENA, d'établissements, de séries, de niveaux ou de matières
Quand l'équipe veut modifier, désactiver ou supprimer une ligne
Alors elle passe par le menu ⋮ de la ligne, et aucun bouton d'action n'est affiché en ligne

# AM-04
Étant donné la fiche d'un établissement actif
Quand l'équipe ouvre le menu ⋮ de l'en-tête
Alors il propose « Modifier » et « Désactiver »
Et après la désactivation, il ne propose plus que « Modifier »

# AM-05
Étant donné la page d'une fiche essentielle ou d'un exercice, vue par l'équipe
Quand elle veut modifier l'objet
Alors « Modifier » est l'unique entrée du menu ⋮ « Actions pour <nom> »
Et « Nouvel exercice » et « Importer des exercices » restent des boutons visibles

# AM-06
Étant donné un téléphone de 390 px
Quand l'équipe ouvre le menu ⋮ d'un établissement de la liste
Alors ses trois entrées sont visibles et cliquables, et la page ne défile pas en largeur
```

| Critère | Test |
|---|---|
| AM-01 | `test/system/teams/row_actions_menu_test.rb` — « Supprimer in the menu of the last row… » |
| AM-02 | `test/system/teams/row_actions_menu_test.rb` — « keyboard… » |
| AM-03 | `test/system/teams/{drenas,schools,series,levels,materials}_test.rb` (parcours par `click_menu_action`), `test/controllers/teams/levels_controller_test.rb` |
| AM-04 | `test/system/teams/schools_test.rb` — « SC-05, SC-06, SC-09… » |
| AM-05 | `test/controllers/catalog/essentials_controller_test.rb`, `test/controllers/assessment/exercises_controller_test.rb`, `test/system/catalog/essential_page_test.rb` |
| AM-06 | `test/system/teams/row_actions_menu_test.rb` — « on a phone… » |
| API | `test/helpers/components_helper_test.rb` — `frame:`, `dialog:`, tonalité, `fixed:` |

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | aucun |
| Infrastructure | aucun |
| Delivery | aucun (routes et contrôleurs inchangés) |
| UI | `ComponentsHelper#ui_dropdown` (`fixed:`), `#ui_dropdown_item` (`frame:`, `dialog:`), `components/_dropdown`, `dropdown_controller.js` (`dismiss`, `openDialog`, `place`) ; lignes et en-têtes des écrans listés en AM-03 à AM-05 ; locales (`actions`) |

## 6. Décisions rattachées

- UDR-0042 — Actions d'un objet dans un menu ⋮
- Amendements du 2026-09-28 : UDR-0005, 0015, 0021, 0032, 0033, 0034, 0035, 0036
