# Journal — Page Ma classe de l'élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Pas d'ADR | `has_teacher` lit `teacher_classrooms`, qui existe ; ni port, ni table, ni dépendance | Non |
| 2026-10-15 | « Inviter mon enseignant » réutilise le partial et le message de l'accueil | Un seul message, une seule clé (ADR-0089 §4.3) | Non |
| 2026-10-15 | Palier 700 px formalisé pour les écrans élève redessinés | UDR-0057 ne prévoyait que `lg` ; l'accueil, Cours et Ma classe centrent à 720 px dès 700 px ; confirmé par le porteur | UDR-0086 §3.5 |
| 2026-10-15 | Code après la PR `accueil-eleve`, possible dans la même session que `cours-eleve`, PR distincte | Confirmé par le porteur | Non |
| 2026-10-15 | `has_teacher` lu dans la requête de l'en-tête (sous-requête `EXISTS`) | Aucune requête de plus : 19 avant, 19 après (ADR-0067) | Non |
| 2026-10-15 | `TreatedRow` gagne `material_slug` (Lot A, fichier du Lot 0) | La pastille de la matière des exercices traités, comme sur la maquette ; une colonne de plus dans le même `pluck` | Non |
| 2026-10-15 | `_invite_teacher` prend `standalone:` (bouton `brand` seul, nom « … sur WhatsApp ») ; l'accueil garde son rendu | Un seul partial et un seul message (UDR-0086 §3.3) | Non |
| 2026-10-15 | « Cours assignés » : titre et bande posés sur la page, sans carte ; les deux listes dans des `ui_card` | Maquette : la bande de cartes blanches ne se met pas dans une carte | Non |
| 2026-10-15 | Sous 640 px, les cartes (listes, « Aucun enseignant ») vont bord à bord | Règle `data-bleed` du design system, déjà appliquée à l'accueil ; la maquette les montrait dans la marge | Non |
| 2026-10-15 | Bande à 4 cartes : `lg:basis-1/4` et `lg:px-1.5` au lieu d'un `calc()` | Les valeurs arbitraires sont refusées (UDR-0005, `design_tokens_test`) | Non |

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
