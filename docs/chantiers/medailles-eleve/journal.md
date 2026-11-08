# Journal — Médailles : écrans de l'élève

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-08 | `badge_for` et `class_badge_for` : Bronze pour tout exercice traité | Décision du porteur | Non (UDR médailles) |
| 2026-11-08 | Résultat : titre d'appréciation gardé (des mots), tuiles note/score/maîtrise/justes et points notés retirés pour l'élève | La médaille est la seule mesure | Non |
| 2026-11-08 | « Refaire » à l'accueil sous l'Argent (équivaut à l'ancien 10/20 → Bronze partout, il fallait un nouveau seuil) | Bronze est désormais le plancher, donc ancien seuil caduc | Non |

## À trancher

- [ ] 2026-11-08 · medailles-eleve · Remédiation : le code lève une lacune dès 75 % (15/20). Consigne élève « vise l'Or » — appliqué : seuil du code inchangé, consigne qui reste vraie ; autres : aligner le seuil sur le Bronze (la fiche serait levée dès le premier exercice traité, ce qui la vide de sens), ou sur l'Argent (68 %) ; recommandé : Argent, dans un chantier code
- [ ] 2026-11-08 · medailles-eleve · Statut « Réussi / À revoir » des questions d'une feuille du catalogue (vérification en direct, JavaScript) — appliqué : inchangé, ce n'est pas une note ; autres : le remplacer par la médaille de la copie ; recommandé : inchangé
- [ ] 2026-11-08 · medailles-eleve · Page d'un exercice : le barème (« · barème : N points ») reste sur la feuille de sujet, vue aussi par l'enseignant — appliqué : inchangé ; autres : le retirer pour l'élève ; recommandé : le retirer au chantier enseignant

- [ ] 2026-11-08 · medailles-eleve · Page de suivi enseignant : la phrase « N élèves n'ont pas encore de médaille » (`comprehension_next_step`) compte les « Pas encore », presque toujours 0 depuis Bronze-plancher — appliqué : inchangé, test assoupli ; autres : compter les élèves sous l'Argent ; recommandé : le corriger dans `medailles-enseignant`

## Ce qui a dérapé

- Assets non compilés en début de session : `yarn build` et `yarn build:css`.
