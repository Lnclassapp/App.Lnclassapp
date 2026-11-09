# Memo — Médailles : écrans de l'enseignant

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-09 |
| **Branche** | `feature/medailles-enseignant` |
| **Programme** | — (suite de `medailles-eleve`, voir `medailles-vocabulaire/plan.md`) |

---

## Le problème

L'enseignant lit encore « Moyenne 15/20 », « Dernier score 80 % », des notes par copie, une moyenne de classe sur 20 à l'accueil et des seuils sur 20 dans les infobulles, à côté des médailles. La page d'une classe porte 5 données par ligne d'élève (audit E-002).

## Pour qui

L'enseignant : accueil, page de classe, fiche élève, suivi d'un devoir (rapport de compréhension), listes et filtres par palier.

## Pourquoi maintenant

Le porteur a tranché (UDR médailles, 2026-11-08) : la médaille remplace notes, % et moyennes partout où l'enseignant les lit. `Queries::Assessment::Medals` (lecture par classe) et `medailles-eleve` sont en place.

## Hors périmètre

- Direction, équipe, parent : chantiers `medailles-direction`, `medailles-equipe`. Les écrans qu'ils partagent avec l'enseignant (fiches à revoir) ne changent que de mots.
- Chiffres en base, seuils 48/68/78 %, noms du code (`badge`).
- Menu « Gérer la classe » (lien d'inscription, jours de séance) de E-002 : écran différent, voir `journal.md` § Dette.

## Ce que le grill a révélé

| Question / attaque | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelle règle de classe ? | Par exercice (porteur) : répartition de médailles, jamais de moyenne ni de classement | Historique d'accueil : « 8 Bronze · 6 Argent · 3 Or » par devoir ; plus de moyenne /20 |
| Que lit l'enseignant sur la ligne d'élève ? | Une médaille (celle de la liste de classe, déjà calculée) | « Moyenne n/20 », « Dernier score », « Voir le résultat », « Fait seul » quittent la ligne (E-002) ; « Fait seul » reste sur la fiche |
| Le rapport d'un devoir classe-t-il les élèves ? | Non | Tri alphabétique dans chaque case ; « Copies rendues » (première/meilleure note) supprimé |
| Un élève médaillé dans une autre classe ? | Non lisible (ADR-0097 §4.5, `Medals`) | Rien de nouveau : toutes les médailles viennent de `Medals` |

## Cas limites identifiés

- Aucun élève n'a fait le devoir : pas de répartition (pas de « 0 Bronze »), le compteur « faits » seul.
- Élève sans médaille dans la classe : « Pas encore », jamais en rouge.
- Fait seul : la médaille de la session vient de `Grading.session_medal` (copie vide : rien).

## Questions encore ouvertes

Voir `journal.md` § À trancher.
