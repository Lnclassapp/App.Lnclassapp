# Plan d'exécution — Accueil élève : « Inviter » et « Plus » dans la grille

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

**Préalable** : la retouche #688 (marges et tuiles de la grille, `_subjects`, `_invite_tile`, `show`) est fusionnée dans `Develop` et la branche du chantier en part ; sinon le Lot A entre en conflit avec elle.

## Graphe

```
Lot 0 — SOCLE (séquentiel) : la liste des entrées, les libellés, les tokens, le contrôleur « soon »
  ↓
  ├─► Lot A — téléphone : grille + feuille « Plus »   ┐ en parallèle
  └─► Lot B — ordinateur : entrées dans le menu de gauche ┘
```

---

## Lot 0 — Socle

- **Couche**       : ui (fichiers partagés)
- **Fichiers**     : `app/helpers/navigation_helper.rb` (constante `STUDENT_MORE`, contrat gelé : clé, route ou `nil`, pictogramme, teinte)
                     `config/locales/shared/navigation.fr.yml` (`shared.navigation.more.*`, `shared.navigation.sidebar.secondary_label.student`)
                     `app/assets/stylesheets/application.tailwind.css` (`--spacing-sheet-quarter`, `--spacing-sheet-half`)
                     `app/javascript/controllers/soon_controller.js` (message « Bientôt disponible » dans une cible `status`, effacé après 4 s)
- **Dépend de**    : — (après fusion de #688)
- **Test associé** : `test/helpers/navigation_helper_test.rb` (ordre et forme de `STUDENT_MORE`, chaque pictogramme existe, chaque clé a son libellé) ; `test/design/design_tokens_test.rb` (tokens déclarés)
- **Done quand**   : la liste et ses libellés existent, les deux lots peuvent la lire sans la toucher

---

## Lot A — Téléphone : « Inviter » et « Plus » dans la grille, feuille « Plus »

- **Couche**       : ui
- **Fichiers**     : `app/views/classroom/student_homes/_subjects.html.erb` (cases « Inviter » et « Plus »)
                     `app/views/classroom/student_homes/_more_sheet.html.erb` (nouveau : la feuille)
                     `app/views/classroom/student_homes/show.html.erb` (plus de section « Invite tes camarades », feuille rendue une fois)
                     `app/views/classroom/student_homes/_invite_tile.html.erb` (supprimé, sa tuile passe dans `_subjects`)
                     `test/design/design_tokens_test.rb` (`WAVE_WEIGHT_SCREENS` : `_invite_tile` → `_more_sheet`)
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/classroom/student_homes_controller_test.rb` (CA-1, CA-2, CA-3 structure, CA-4 lien, CA-8) ; `test/system/classroom/student_home_more_test.rb` (CA-3 ouverture et hauteur ≥ 25 %, CA-5 message lu sans changer d'adresse, CA-6 Échap et focus)
- **Done quand**   : à 390 px, la grille se termine par « Inviter » et « Plus », la feuille s'ouvre, « S'abonner » mène à l'abonnement, « Salle d'étude » dit « Bientôt disponible »

---

## Lot B — Ordinateur : les entrées dans le menu de gauche

- **Couche**       : ui
- **Fichiers**     : `app/views/shared/navigation/_sidebar.html.erb` (2e carte de l'élève, lue de `STUDENT_MORE`)
- **Dépend de**    : Lot 0
- **Test associé** : `test/integration/identity/student_header_test.rb` ou un test de la barre latérale (CA-7 : entrées, ordre, « Bientôt disponible », pas de « Plus » dans la grille dès lg) ; CA-8 (même liste)
- **Done quand**   : à 1440 px, le menu de gauche de l'élève liste les cinq entrées sous ses trois destinations

---

## Collisions

| Fichier | Lot 0 | Lot A | Lot B |
|---|---|---|---|
| `navigation_helper.rb` | écrit | lit | lit |
| `navigation.fr.yml` | écrit | lit | lit |
| `soon_controller.js` | écrit | lit | lit |
| `student_homes/*` | — | écrit | — |
| `_sidebar.html.erb` | — | — | écrit |
| `design_tokens_test.rb` | écrit (tokens) | écrit (liste des écrans) | — |

`design_tokens_test.rb` est touché par le Lot 0 et le Lot A : le Lot A part après la fusion du Lot 0, il n'y a pas de conflit.

## Dispatch

1. Lot 0 seul (`executant-lot`, Sonnet).
2. Lots A et B en parallèle (`executant-lot`, Sonnet).
3. Captures 390 px et ordinateur, clair et sombre ; challenger empirique (rôle distinct) : parcours nominal (CA-3 → CA-4) et un chemin d'erreur (CA-5 entrée sans écran, CA-2 sans classe).
4. Une PR vers `Develop`.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture) — sans objet, écrit au PRD §6
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
