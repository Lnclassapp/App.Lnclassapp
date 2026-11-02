# Memo — Les 10 premières leçons de Mathématiques de 1ère C et de 1ère D

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours (PR vers `Develop`, leçons en brouillon) |
| **Ouvert le** | 2026-11-01 |
| **Branche** | `feature/contenus-1ere-mathematiques-cd` |
| **Programme** | contenus-v3-tous-niveaux (vague P1) |

---

## Le problème

Un élève de 1ère C ou D n'a aucune leçon de Mathématiques à réviser au format v3 : les 10 premières leçons de chaque progression sont des fiches vides, et les 3 premières de chaque série sont au format v1, que l'import refuse.

## Pour qui

- **Student** de 1ère C et de 1ère D, qui révise et s'entraîne dans la fiche.
- **Teacher**, qui donne les exercices de la leçon à sa classe.
- **Team**, qui importe en brouillon, fait relire par un enseignant, publie.

## Pourquoi maintenant

Première vague du niveau 1ère du programme (Tle fusionnée). Modèle : les maths de Tle C/D (PR #420).

## Hors périmètre

- Les leçons au-delà du rang 10 ; la série A (vague P2, qui déclinera « Généralités sur les fonctions » et « Dénombrement » écrites ici).
- Toute sorte ou tout paramètre de figure nouveau (courbe de fonction, tableau de variations, arbre de probabilités, solide en perspective) : situations décrites dans l'énoncé, dette notée au journal.
- Le code, les tests et l'import : aucun changement.
- L'import en production, la relecture enseignante, la publication : faits par l'équipe ; les leçons restent en brouillon.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Combien de leçons distinctes ? | 13 (C : 10, D : 10, 7 communes), 20 fichiers (un cours = une série). | Bilan : 13 leçons, 20 fichiers. |
| Les rangs diffèrent entre C et D pour une leçon commune (Barycentre : C4, D8 ; Dérivation : C9, D6 ; Limites : C5, D4…). Quels acquis ? | L'intersection : une leçon commune ne s'appuie que sur les leçons qui la précèdent dans **les deux** progressions et ne traite rien de ce qui la suit dans l'une ou l'autre. | Le brief donne à chaque rédacteur ses acquis et ses leçons interdites. |
| « Généralités sur les fonctions » et « Dénombrement » seront déclinées en 1ère A (rangs 3 et 2, après « Équations et inéquations » seulement). | Elles ne s'appuient pas sur « Angles orientés » (Généralités) ni sur « Limites » (Dénombrement). | Contraintes de déclinabilité dans le brief. |
| Que deviennent les 6 fichiers v1 de 1ère C/D (Équations, Angles, Généralités) ? | Remplacés au même nom (décision D4). | Réécrits en v3 ; l'historique git garde les v1. |
| `valider.rb` ne contrôle pas `practice`. | Contrôle à part, mêmes règles que le test des mathématiques de 3e (script d'orchestrateur). | Chaque fichier passe les deux contrôles. |

## Questions encore ouvertes

- Aucune.
