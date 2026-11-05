# Plan d'exécution — Les sujets d'interrogation en cahier noir et blanc

## Graphe

```
Lot A — feuille exam_sheet.css + trois vues + tests (un seul lot, séquentiel)
```

Pas de Lot 0 : ni port, ni table, ni route.

---

## Lot A — Sujet, copie et résultat en noir et blanc

- **Couche**       : ui
- **Fichiers**     : `app/assets/stylesheets/exam_sheet.css` (nouveau)
                     `app/views/assessment/exercises/show.html.erb`
                     `app/views/assessment/exercise_sessions/show.html.erb`
                     `app/views/assessment/session_results/show.html.erb`
                     `config/locales/assessment/*.fr.yml` (cartouche, consigne)
                     `test/design/design_tokens_test.rb`
                     `test/system/assessment/exam_sheet_test.rb` (nouveau) · tests de contrôleur existants des trois vues
- **Dépend de**    : —
- **Test associé** : CA-1 à CA-7 du PRD
- **Done quand**   : les trois pages, à 375 px et 1280 px, n'ont ni bleu, ni vert, ni rouge dans la feuille ; la fiche de révision inchangée

---

## Décisions ouvertes

Tranchées par l'orchestrateur (2026-11-05) ; le reste dans `journal.md` § À trancher.

## Vérification de collision

Un seul lot. Hors chantier : #484 (`db/seeds/standard/jeu.yml`, `docs/contenus/`) et #340 (page de la leçon) ne touchent aucun de ces fichiers.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît (aucun)
- [x] UDR écrite pour **chaque** vue créée ou modifiée
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle (sans objet)
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
