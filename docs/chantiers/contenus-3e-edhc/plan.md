# Plan d'exécution — Les 10 premières leçons d'EDHC de 3ème

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
(vague 1 fusionnée : contrôle et consigne)    (vague 2 fusionnée : diagram, map, courbe)
                    ↓                                        ↓
Lot ED — rédaction des 10 leçons (6 rédacteurs en parallèle au plus) ─→ fusion de Develop → contrôle → relecture IA indépendante → contrôle
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

---

## Lot ED — Les 10 leçons d'EDHC

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/edhc/*.json` (10, dont les 3 v1 remplacés) · `docs/contenus/README.md` (tableau « Leçons traitées »)
- **Dépend de**    : vague 1 (contrôle et consigne, fusionnée) ; vague 2 (sortes `diagram`, `map`, `stat_chart` `line`) pour le contrôle et la livraison
- **Test associé** : `ruby script/contenus/valider.rb` sur les 10 fichiers ; relecture IA indépendante (Opus) ; challenger.
- **Done quand**   : les 10 fichiers passent le contrôle sans erreur ni avertissement après relecture, leurs figures sont de l'inventaire, et ils sont envoyés au porteur.

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `docs/contenus/lecons-traitees/3eme/edhc/*`, ligne EDHC du README des contenus | Lot ED |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît — sans objet
- [x] UDR écrite pour **chaque** vue créée ou modifiée — sans objet
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle — sans objet
- [ ] Chaque critère d'acceptation a son test (contrôle, relecture, challenger)
- [x] En-tête HITL sur chaque fichier créé dans `app/` — sans objet
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
