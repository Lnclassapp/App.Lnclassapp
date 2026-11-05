# Plan d'exécution — Le sujet se lit comme une vraie épreuve

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — l'épreuve sur les trois pages de lecture (seul)
```

Pas de Lot 0 : aucune migration, aucune entité, aucun port, aucune route. Le seul fichier partagé (`config/locales/catalog/courses.fr.yml`) appartient au Lot A, seul lot.

Dispatch : **vague 1 : Lot A → 1 agent** (`executant-lot`), dans le worktree du chantier `/home/user/lnclass-sujet-comme-une-epreuve`, branche `feature/sujet-comme-une-epreuve`.

---

## Lot A — L'élève, « Ma classe » et l'enseignant lisent le sujet comme une épreuve

- **Couche**       : infrastructure (lecture) + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/prepare_sheets_query.rb` (`Question` gagne `points`)
                     `app/views/catalog/courses/sheets/_paper.html.erb` (nouveau)
                     `app/views/catalog/courses/sheets/_sheet.html.erb` (rend `_paper` en `:reading`, `:teacher`, `:team`)
                     `app/assets/stylesheets/prepare_sheet.css`
                     `config/locales/catalog/courses.fr.yml` (`catalog.courses.sheets.paper.*`)
                     `test/infrastructure/queries/catalog/prepare_sheets_query_test.rb`
                     `test/integration/catalog/sheet_paper_test.rb` (nouveau)
                     tests existants qui lisent la page de lecture (À retenir, ps-exercise, progression) : `test/controllers/catalog/prepare_sheets_controller_test.rb`, `test/controllers/classroom/classroom_prepare_sheets_controller_test.rb`, `test/controllers/classroom/student_assigned_sheets_controller_test.rb`, `test/integration/catalog/prepare_interros_test.rb`, `test/integration/catalog/notion_anchors_test.rb`, `test/system/catalog/sheet_cards_test.rb`, `test/system/classroom/assigned_sheet_cards_test.rb`, `test/system/catalog/long_formulas_test.rb` — mis à jour seulement là où ils lisent la lecture, jamais affaiblis
- **Dépend de**    : —
- **Test associé** : `test/integration/catalog/sheet_paper_test.rb` (un test par critère du PRD §4 : cartouche et titre, tableau QCM, tableau V/F, liste lettrée, pas d'« À retenir » en lecture, somme des points, enseignant avec bascules) ; `test/infrastructure/queries/catalog/prepare_sheets_query_test.rb` (points) ; le critère « 390 px sans débordement » ajouté au test système existant `test/system/catalog/sheet_cards_test.rb` (aucun nouveau fichier système, budget ADR-0069 §9)
- **Done quand**   : l'élève qui clique une case « Prépare devoirs » de Thalès voit le cartouche, « ÉPREUVE DE MATHÉMATIQUES », « Exercice 1 (n points) », les affirmations en tableaux et les autres questions en liste, sans champ ni « À retenir », puis « Commencer » ; l'enseignant voit la même épreuve avec ses bascules ; à 390 px aucune page ne défile en largeur

Ordre intra-lot : tests rouges d'abord (intégration + query), puis la query, puis le partiel, `_sheet`, le CSS, les locales ; enfin les tests existants. La feuille à remplir (`fill`) ne change pas : ses tests ne bougent pas.

Règles d'interface : [UDR-0152](../../decisions/udr/0152-sujet-comme-une-epreuve.md) §3, à suivre à la lettre. PRD : [`prd.md`](prd.md).

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/locales/catalog/courses.fr.yml` | Lot A |
| `app/views/catalog/courses/sheets/_sheet.html.erb` | Lot A |
| `app/assets/stylesheets/prepare_sheet.css` | Lot A |

Un seul lot : aucune collision possible.

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

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : captures à 390 px et sur ordinateur des 8 feuilles de Thalès, de la page de l'enseignant et d'un devoir de « Ma classe », largeur de page mesurée ; chemin d'erreur : une feuille inconnue renvoie « Cette feuille n'existe plus. ».
