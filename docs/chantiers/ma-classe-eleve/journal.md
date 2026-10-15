# Journal — Page Ma classe de l'élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Pas d'ADR | `has_teacher` lit `teacher_classrooms`, qui existe ; ni port, ni table, ni dépendance | Non |
| 2026-10-15 | « Inviter mon enseignant » réutilise le partial et le message de l'accueil | Un seul message, une seule clé (ADR-0089 §4.3) | Non |
| 2026-10-15 | Palier 700 px formalisé pour les écrans élève redessinés | UDR-0057 ne prévoyait que `lg` ; l'accueil, Cours et Ma classe centrent à 720 px dès 700 px ; confirmé par le porteur | UDR-0086 §3.5 |
| 2026-10-15 | Code après la PR `accueil-eleve`, possible dans la même session que `cours-eleve`, PR distincte | Confirmé par le porteur | Non |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- « Classe sans enseignant » se lit dans `teacher_classrooms` (unique `teacher_id, classroom_id`, index sur `classroom_id`).
- `StudentClassroomQuery` lit les exercices assignés depuis les `ExerciseRow` de `StudentHomeQuery` : l'ordre reste celui de « À faire ».

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | UDR-0086 |
