# Journal — Page Cours de l'élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Une ligne par fiche ouverte (`essential_reads`) plutôt qu'une progression par cours | « Tout lu » reste juste quand un cours gagne ou perd une fiche | ADR-0090 |
| 2026-10-15 | `materials.position` remplace `SUBJECT_ORDER` | Une seule source d'ordre pour l'accueil, l'exercice du jour et Cours | ADR-0090 |
| 2026-10-15 | « Commencer » et « Revoir » ouvrent la page du cours, « Reprendre » la dernière fiche ouverte | Confirmé par le porteur le 2026-10-15 | UDR-0085 §3.3 |
| 2026-10-15 | Le code attend la fusion de la PR `accueil-eleve` | En-tête, menu de l'avatar et fin de la barre du bas y sont livrés ; confirmé par le porteur | Non |
| 2026-10-15 | Ouvrir une fiche suffit à la compter comme lue | Confirmé par le porteur ; pas de mesure de lecture réelle | ADR-0090 §5 |
| 2026-10-15 | Lot 0 : `RecordEssentialRead` reçoit `ReadPublishedPolicy` et la rejoue | `test/architecture/use_case_policies_test.rb` (ADR-0028) refuse un use case sans `policy:` ; le contrôleur la passe déjà, le second appel ne lit pas la base | Non |
| 2026-10-15 | Lot 0 : `essential_reads` rejoint la liste fermée des cascades de `schema_constraints_test` | ADR-0090 §4.1 décide `on_delete: cascade` vers `essentials` ; une fiche n'est jamais supprimée par l'application | ADR-0090 |
| 2026-10-15 | Lot 0 : la fabrique de test `create_material` pose le rang du programme par slug | Les tests existants de l'accueil et de l'exercice du jour gardent leur ordre sans réécriture | Non |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- Aucune donnée ne dit qu'un élève a ouvert une fiche : seules les sessions d'exercice sont suivies.
- `materials` n'a pas de rang ; l'ordre du programme ne vivait que dans `StudentHomeQuery::SUBJECT_ORDER`, le catalogue triait par nom.
- Les bulles « Mes matières » de l'accueil ouvrent déjà `/courses?material=<slug>` : la vue de la matière est la liste filtrée, il n'y a pas de page dédiée.
- `courses#index` est partagé par tous les rôles ; la branche élève se reconnaît à `student_audience` (`ReadsOwnLevel`).

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Suivi de lecture des fiches côté enseignant | Non demandé ; la donnée existe désormais | — |
| Ordre des matières pour l'enseignant, la direction et l'équipe | Hors périmètre (memo) | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0090 |
| **UDR produits** | UDR-0085 |
