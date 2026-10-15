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

- Une mesure de requêtes à zéro : un abonné `->(*, payload)` reçoit l'événement entier ; on compte avec `->(*args)` et `args.last`, sur une seule requête (le cache de requêtes du test marque `cached` celles d'une requête précédente).
- Le test système cherchait « Exercice 4 » et trouvait « Exercice 40 » d'une fabrique : titres renommés « Devoir N ».
- Une échéance de test hors contrainte `classroom_assignments_due_on_within_a_week` (1 à 7 jours après l'assignation) : `assigned_at` reculé.
- Budget de la suite système (ADR-0069 §9) : la branche part d'`accueil-eleve`, pas encore sur `Develop` ; leurs croissances s'additionnent (14,3 s + 0,7 s = 15,0 s pour 15 s). La durée de `student_classroom_test.rb` (4,4 s) est l'ancienne (3,7 s) mise à l'échelle par le rapport nouveau / ancien mesuré sur la même machine (28,6 s / 23,9 s).
- `bin/ci-quiet` (2026-10-15, avant l'alignement sur UDR-0090 §4) : rouge par les seuls tests système ; tout le reste vert (pureté, HITL, budget système, style, audits, Brakeman, Rails à 100 %, seeds, performance, assets). Cinq échecs, tous sur le numéro reformaté de `session[contact]` ou le texte « 4 chiffres », hors du périmètre : `sign_in_test.rb:114`, `team_invitation_test.rb:62`, `public_pages_test.rb:89` et `:100` (les :79 et :97 de Develop), et `teams/staff_invitation_test.rb:50`, de la même cause.
- Relecture des tests : `has_teacher` comptait un enseignant anonymisé (`users.anonymized_at`), qui masquait à tort « Inviter mon enseignant ». L'`EXISTS` joint maintenant `users` avec `anonymized_at IS NULL` ; le test a été écrit rouge d'abord. La relecture a aussi épinglé 6 requêtes pour la query (le même nombre avec et sans enseignant, côté contrôleur aussi) et ajouté les cas « 13/20 à l'encre », « aucune classe rouge », « pas d'effectif », « pas de lien WhatsApp avec enseignant » et « classe secondaire seule à avoir un enseignant ».
- `image_header_test.rb:500` (moins de 0,5 s) échoue sous la charge de la suite complète (0,54 s, 0,66 s), vert seul : sans lien avec le chantier.

## Ce qu'on a appris sur la codebase

- « Classe sans enseignant » se lit dans `teacher_classrooms` (unique `teacher_id, classroom_id`, index sur `classroom_id`).
- `StudentClassroomQuery` lit les exercices assignés depuis les `ExerciseRow` de `StudentHomeQuery` : l'ordre reste celui de « À faire ».
- Sous 640 px, une `rounded-card shadow-card` sous `[data-bleed]` va bord à bord, sauf dans une bande `snap-x`, une carte ou une grille à plusieurs colonnes.
- La note verte suit la règle de l'historique (UDR-0090 §4) : `Grading.grade_on_20(score) >= 14`, sur la note affichée (68 % s'affiche 14/20, en vert) ; `PASS_THRESHOLD` (50 %) colorait jusque-là 10/20 en vert.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `_invite_teacher` rendu sur deux pages, dans `classroom/student_homes/` | UDR-0086 §4 : il passe dans `shared/` au troisième usage | — |
| Contraste AA du dégradé en sombre (texte sur `brand-strong` clair) | Même carte que l'accueil, jugée par `accueil-eleve` ; pas de test de contraste propre au dégradé | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-15, fusionné dans `Develop` |
| **PR** | [#244](https://github.com/Lnclassapp/App.Lnclassapp/pull/244) |
| **ADR produits** | — |
| **UDR produits** | UDR-0086 |
