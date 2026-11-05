# Plan d'exécution — Calcul littéral préparé comme Thalès

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — Calcul littéral : 2e exercice par notion, 4 sujets, figures (seul)
```

Il n'y a pas de Lot 0 : aucune migration, aucune entité, aucun port, aucune route.

Vague 1 : Lot A → 1 agent (`executant-lot`), worktree `/home/user/lnclass-calcul-litteral`, branche `feature/calcul-litteral-comme-thales`.

---

## Lot A — Calcul littéral préparé comme Thalès

- **Couche**       : contenu
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/mathematiques/calcul-litteral.json`
                     `docs/contenus/README.md` (si la liste des leçons à sujets y est tenue, comme pour Thalès)
- **Dépend de**    : —
- **Test associé** : `test/integration/catalog/pilot_lessons_test.rb` (déjà générique : compte les exercices de notion, les sujets et leurs figures) ; rendu des leçons changées `test/system/catalog/lesson_rendering_test.rb` (`LECONS=` le fichier) ; script de vérification des calculs (hors dépôt)
- **Done quand**   : l'import du fichier donne 2 exercices par notion et 4 sujets de 4 exercices ; la page de Calcul littéral montre 8 feuilles « Prépare interros » et 4 « Prépare devoirs » ; chaque bonne réponse est juste et chaque mauvaise est fausse, vérifiées par calcul

Modèle : `proprietes-de-thales-dans-un-triangle.json` (structure, style des énoncés, des indices et des corrections). PRD : [`prd.md`](prd.md).

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `docs/contenus/lecons-traitees/3eme/mathematiques/calcul-litteral.json` | Lot A |

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

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le contenu** importe le fichier dans la base de démonstration, ouvre la leçon, compte les feuilles, fait un sujet avec une bonne et une mauvaise réponse et lit la correction en bloc. Il relance le script de vérification des calculs. Captures à 390 px et sur ordinateur.
