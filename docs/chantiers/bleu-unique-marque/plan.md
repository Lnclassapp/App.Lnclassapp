# Plan d'exécution — Bleu unique de marque

> Un seul lot : chaque fichier touché l'est pour la même règle, et les tests de conception lisent la feuille entière. Pas de parallélisme utile.

## Graphe

```
Lot A — bleu unique (séquentiel, seul)
```

---

## Lot A — Bleu unique

- **Couche**       : ui + delivery (config) + ressources statiques
- **Fichiers**     : `app/assets/stylesheets/application.tailwind.css`, `exam_sheet.css` · `app/helpers/{components,navigation}_helper.rb` · vues et contrôleurs Stimulus qui posent un fond bleu · `config/application.rb` · `public/*.html`, `public/offline.css`, icônes `public/` · `app/views/pwa/service-worker.js` · `app/assets/images/{logo,lnclass}/*` · `android/{shell,student}/src/main/res/**` · tests de conception, de helpers, de vues, de contrôleurs et système
- **Dépend de**    : —
- **Test associé** : `test/design/brand_blue_test.rb` (nouveau) et les tests de conception existants
- **Done quand**   : un seul bleu #0861E1 visible sur les captures des quatre rôles, en clair et en sombre, à 390 px et sur ordinateur

## Décisions ouvertes

- [ ] Afficher le « L » du SVG d'origine au lieu du baobab — options : garder le baobab recoloré, passer au « L » ; recommandé : baobab (voir journal)

## Vérification de collision

Un seul lot : sans objet.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît — aucun (prd §6)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle — sans objet
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord — tests écrits avec le code, pas avant (journal, « Ce qui a dérapé »)
- [x] En-tête HITL sur chaque fichier créé dans `app/` — aucun fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
