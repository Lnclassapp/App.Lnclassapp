# Memo — Les leçons de Physique-Chimie de 1ère A (A1 et A2) au format v3

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-02 |
| **Branche** | `feature/contenus-1ere-a-physique-chimie` |
| **Programme** | `contenus-v3-tous-niveaux` (vague P4) |

## Le problème

Un élève de 1ère A1 ou A2 n'a aucune leçon de Physique-Chimie au format en vigueur : les 3 premières sont en v1 (non importables), les 7 suivantes sont des fiches vides.

## Pour qui

- **Student** de 1ère A1 ou A2, qui révise avant un devoir.
- **Teacher**, qui donne les exercices. **Team**, qui importe en brouillon, relit, publie.

## Hors périmètre

- Tout code : les sortes de figures existantes suffisent.
- Les leçons au-delà de la 10e, les autres matières et niveaux, les séries C et D.

## Décisions

- Le référentiel n'a pas de série « A » en 1ère (A1, A2, C, D) : chaque leçon est écrite une fois, puis déclinée en deux fichiers (`series_name` « A1 » dans `1ere-a1/`, « A2 » dans `1ere-a2/`), même rang. Pas de dossier `1ere-a/`.
- Les leçons 9 et 10 partent des versions 1ère C/D (PR #432), allégées en formalisme pour la série A.
- Les fichiers v3 remplacent les v1 des leçons 1 à 3 (D4).
- Chiffres et données : vérifiés par un sous-agent Opus, distinct de l'auteur.
