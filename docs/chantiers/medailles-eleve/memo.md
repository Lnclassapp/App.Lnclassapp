# Memo — Médailles : écrans de l'élève

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `claude/medailles-eleve` |
| **Programme** | — (suite de `medailles-vocabulaire`, voir son `plan.md`) |

---

## Le problème

L'élève lit encore une note sur 20, un pourcentage, une « maîtrise », un barème et des points à côté de sa médaille. Quatre mesures pour la même chose. En plus, un exercice sous la moitié de bonnes réponses ne donnait aucune médaille.

## Pour qui

L'élève : résultat d'une session, accueil, Ma classe, Mon historique, page d'un exercice, copie en cours, questions fréquentes.

## Pourquoi maintenant

Le porteur a tranché le 2026-11-08 (UDR médailles) : la médaille remplace notes, % et moyennes partout où l'élève les lit. Les mots sont posés, il reste les écrans.

## Hors périmètre

- Enseignant, direction, équipe, parent : chantiers `medailles-enseignant`, `-direction`, `-equipe`.
- Fiches et feuilles du catalogue : le statut « Réussi / À revoir » d'une question vérifiée en direct n'est pas une note ; il reste (voir `journal.md` § À trancher).
- Chiffres en base, seuils (48/68/78 %), renommage du code.

## Ce que le grill a révélé

| Question / attaque | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que lit l'élève sous la moitié de bonnes réponses ? | Bronze : tout exercice traité donne au moins Bronze (porteur) | `Grading.badge_for` et `class_badge_for` ne renvoient plus nil ; « Pas encore » = rien fait |
| Le changement de règle touche-t-il l'enseignant ? | Oui, la règle de domaine est unique | Les tests et listes de classe suivent (Bronze au lieu de « Pas encore ») ; leur affichage est repris par `medailles-enseignant` |
| La remédiation (75 %, 15/20) se dit-elle en médaille ? | Le seuil du code ne bouge pas | Consigne « vise l'Or » (suffisant, jamais faux), seuil à trancher |
| L'enseignant qui ouvre la copie d'un élève voit-il aussi la médaille seule ? | Non, pas dans ce chantier | La page de résultat garde note, score et maîtrise pour les non-propriétaires |

## Cas limites identifiés

- Score 0 % : Bronze, jamais « Pas encore ».
- Première session : pas de phrase de progrès ; Diamant : pas de « prochaine médaille ».
- Plusieurs sessions : la médaille de la liste est celle de la meilleure copie.

## Questions encore ouvertes

Voir `journal.md` § À trancher.
