# Plan d'exécution — La feuille remplit l'écran du téléphone

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — la feuille bord à bord sous 640 px (seul)
```

Pas de Lot 0 : aucune migration, entité, port ni route. Vague 1 : Lot A → 1 agent (`executant-lot`), worktree `/home/user/lnclass-feuille-pleine-largeur`, branche `feature/feuille-pleine-largeur`.

---

## Lot A — Sur téléphone, la feuille occupe toute la largeur

- **Couche**       : ui
- **Fichiers**     : `app/assets/stylesheets/prepare_sheet.css`
                     `test/system/catalog/sheet_cards_test.rb` (assertions ajoutées au test 390 px existant, aucun nouveau fichier système)
- **Dépend de**    : —
- **Test associé** : `test/system/catalog/sheet_cards_test.rb` (à 390 px : `.ps-sheet` de l'épreuve et de la feuille à remplir de 0 à 390, pas de défilement en largeur)
- **Done quand**   : à 390 px, l'épreuve et la feuille à remplir du sujet 3 de Thalès touchent les deux bords ; à 1280 px, rien n'a changé

Règles d'interface : [UDR-XXXX-feuille-pleine-largeur-sur-telephone](../../decisions/udr/XXXX-feuille-pleine-largeur-sur-telephone.md) §3. PRD : [`prd.md`](prd.md).

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/assets/stylesheets/prepare_sheet.css` | Lot A |

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

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.**
>
> Ici : à 390 px, mesurer les 8 feuilles de Thalès (épreuve et feuille à remplir), un devoir de « Ma classe » et la page de l'enseignant (bords de `.ps-sheet`, début du texte, pas de débordement) ; à 1280 px, comparer avec l'avant. Captures à 390 px et sur ordinateur.
