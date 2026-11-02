# Memo — Leçons de 1ère en Histoire-Géographie au format v3

| | |
|---|---|
| **Type de cycle** | feature (contenu, aucun code) |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-02 |
| **Branche** | `feature/contenus-1ere-histoire-geographie` |
| **Programme** | `contenus-v3-tous-niveaux` (vague P9) |

## Le problème

Les 10 premières leçons d'Histoire-Géographie de 1ère sont des fiches vides ; 3 anciennes leçons v1 existent dans un format retiré (`lecons-traitees/1ere/histoire-geographie/`).

## Pour qui

Élève de 1ère (toutes séries : la progression est commune), enseignant qui donne les exercices, équipe qui importe, relit et publie.

## Hors périmètre

- Les autres matières et niveaux ; les leçons au-delà des 10 premières.
- Tout code : les figures réutilisent les sortes existantes (ADR-0116, ADR-0117, UDR-0142).
- L'import et la publication (faits par l'équipe, leçons en brouillon).

## Décisions reprises

D4 du programme : le fichier v3 remplace le fichier v1 du même intitulé. Pas de `series_name` : un seul fichier par leçon dans `docs/contenus/lecons-traitees/1ere/histoire-geographie/`. Le modèle de la Tle n'est pas encore fusionné dans `Develop` : le modèle de forme est celui de la 3ème (`contenus-3e-histoire-geographie`).

## Questions encore ouvertes

- Aucune.
