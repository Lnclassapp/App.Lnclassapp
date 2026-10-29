# Memo — Liste de la classe : le badge dit qu'il vient de la moyenne

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-29 |
| **Branche** | `fix/badge-liste-moyenne` |
| **Programme** | — |

---

## Symptôme

L'élève fête « Bronze » à la fin d'un exercice ; dans la liste de la classe, l'enseignant lit « Pas encore » pour lui. Rien ne dit que la pastille de la liste est le badge **de classe**, calculé sur la moyenne de ses exercices (UDR-0134 §3.2) : l'enseignant croit à une erreur. « Pas encore » n'affiche pas la moyenne, alors que la fiche de l'élève dit « Moyenne 7/20 · Pas encore ».

Attendu : la pastille de la liste se lit comme celle de la fiche.

## Reproduction

- **Acteur** : enseignant ; élève Daniel Tanoh (Develop, simulation des 45 élèves) : 13/20 à Thalès (Bronze), moyenne 7/20 sur ses exercices faits.
- **Étapes** : ouvrir la classe → liste des élèves → ligne de Daniel : « Pas encore ». Sa fiche : « Moyenne 7/20 · Pas encore » et « Bronze 1 ».

## Portée

- Toute ligne de la liste d'une classe (`classroom/classrooms/_roster`). Rien n'est calculé faux : seul le libellé trompe. Pas de données touchées.
- Multi-appartenance : la moyenne est déjà celle de la classe affichée.

## Décision (porteur, 2026-10-29 : « corrige les deux », option recommandée retenue)

UDR-0134 §3.5, ligne `_roster` : la pastille devient **« Moyenne 15/20 · Or »** (trophée du palier, pastille neutre) ; avec au moins un exercice fait sous le seuil : **« Moyenne 7/20 · Pas encore »** (`text-mute`) ; sans exercice fait : « Pas encore » seul. La règle du badge (§3.2) ne change pas.

## Hors périmètre

- Calcul du badge, filtres par badge, compteurs, fiche de l'élève, accueil : inchangés.

## Portes de sortie

- [x] Test rouge puis vert (ligne avec badge, ligne « Pas encore » avec moyenne, ligne sans exercice fait)
- [x] UDR-0134 amendée
- [ ] Captures 390 px et ordinateur envoyées au porteur
- [ ] `bin/ci-quiet` vert, ligne de preuve dans la PR
- [ ] Vérifié sur Develop après fusion
