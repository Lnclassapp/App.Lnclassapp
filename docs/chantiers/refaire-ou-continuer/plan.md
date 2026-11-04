# Plan d'exécution — Refaire ou continuer depuis la correction

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — refaire ou continuer depuis la correction (seul)
```

Pas de Lot 0 : aucune migration, aucune entité, aucun port, aucune route. Vague 1 : Lot A → 1 agent (`executant-lot`), worktree `/home/user/lnclass-refaire-ou-continuer`, branche `feature/refaire-ou-continuer`.

---

## Lot A — Depuis la correction, l'élève refait l'exercice ou continue sa feuille

- **Couche**       : infrastructure (lecture) + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/prepare_sheets_query.rb` (`Sheet#next_open`)
                     `app/infrastructure/queries/classroom/student_assigned_sheets_query.rb` (`Sheet#next_open`)
                     `app/controllers/assessment/session_results_controller.rb`
                     `app/views/assessment/session_results/show.html.erb`
                     `config/locales/assessment/session_results.fr.yml`
                     `app/controllers/catalog/prepare_sheets_controller.rb` (`@redo`)
                     `app/controllers/classroom/student_assigned_sheets_controller.rb` (`@redo`)
                     `app/views/catalog/prepare_sheets/fill.html.erb` · `app/views/classroom/student_assigned_sheets/fill.html.erb` (local `redo:` transmis)
                     `app/views/catalog/prepare_sheets/_sheet.html.erb` · `app/views/classroom/student_assigned_sheets/_sheet.html.erb` · `app/views/catalog/courses/sheets/_sheet.html.erb` (local `redo:` → `data-prepare-sheet-redo-value`)
                     `app/javascript/controllers/prepare_sheet_controller.js`
                     `test/infrastructure/queries/catalog/prepare_sheets_query_test.rb` · `test/infrastructure/queries/classroom/student_assigned_sheets_query_test.rb`
                     `test/controllers/assessment/session_results_controller_test.rb`
                     `test/controllers/catalog/prepare_sheets_controller_test.rb` · `test/controllers/classroom/student_assigned_sheets_controller_test.rb`
                     `test/system/assessment/sheet_check_test.rb` (scénario « Refaire » ajouté au fichier existant, aucun nouveau fichier système)
                     tests existants qui lisent « Retour à la leçon » / « Reprendre le devoir » sur la correction (`test/system/catalog/sheet_cards_test.rb`, `test/system/classroom/assigned_sheet_cards_test.rb`) : mis à jour, jamais affaiblis
- **Dépend de**    : —
- **Test associé** : `test/controllers/assessment/session_results_controller_test.rb` (continuer : suivant, premier non fait, tout fait, devoir, feuille introuvable, sans feuille ; lien « Refaire » vers la feuille avec `redo`) ; tests de query pour `next_open` ; tests contrôleur de `fill` (`redo` connu → `data-prepare-sheet-redo-value`, inconnu → absent) ; `test/system/assessment/sheet_check_test.rb` (Refaire : l'exercice revient vide, l'autre garde ses réponses)
- **Done quand**   : depuis la correction d'un exercice de « Prépare devoirs n°1 », « Continuer les exercices » ouvre la feuille sur l'exercice suivant non fait avec les réponses du premier visibles, et « Refaire l'exercice » ouvre la feuille avec cet exercice vide ; tout fait → « Retour à la leçon »

Ordre intra-lot : tests rouges → queries → contrôleurs → vues et JS. Règles d'interface : [UDR-XXXX-refaire-ou-continuer](../../decisions/udr/XXXX-refaire-ou-continuer.md) §3. PRD : [`prd.md`](prd.md).

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/locales/assessment/session_results.fr.yml` | Lot A |
| `app/views/catalog/courses/sheets/_sheet.html.erb` | Lot A (⚠️ aussi modifié par le chantier `sujet-comme-une-epreuve` : celui fusionné en second fusionne Develop avant sa PR) |

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.**
>
> Ici : sur Thalès, vérifier l'exercice 1 de « Prépare devoirs n°1 », « Continuer les exercices » → exercice 2 ; rater l'exercice 2, « Refaire » → exercice 2 vide, exercice 1 intact ; tout faire → « Retour à la leçon » ; chemin d'erreur : `redo` inconnu dans l'adresse, rien n'est remis à blanc. Captures à 390 px et sur ordinateur.
