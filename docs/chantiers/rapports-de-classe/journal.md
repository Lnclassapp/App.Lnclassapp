# Journal — Rapports de classe : la fiche d'un élève et ce qui reste du suivi enseignant

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Le chantier ne garde que ce qui manque : fiche élève (CL-13, AS-24), liens vers elle (fin d'AS-22), pagination (CL-15), prochain geste (AS-23) | Inventaire du code : AS-21, AS-25 et l'essentiel d'AS-22 livrés par `rapports-exercices` ; « Activités » de l'accueil par `interface-enseignant-organisation` ; aucun cache par ADR-0079 | Non (memo, Q1) |
| 2026-10-16 | Aucune policy nouvelle : la fiche suit `ReadClassroomPolicy` avec `show_roster` | Ceux qui lisent la liste lisent la fiche | ADR-0097 §4.2 |
| 2026-10-16 | « Fait », retard, catégorie et signe de la fiche viennent des mêmes queries que la page de suivi | Un seul chiffre par fait | ADR-0097 §4.3 |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- `ClassroomHeaderQuery::Row` n'expose pas l'`id` de la classe : une query qui en part prend le `public_id`.
- `ClassroomStudentsController` admet aussi la direction (`school_admin`) pour le retrait ; `#show` doit la refuser par la policy, pas par `allow_roles`.
- La liste d'une catégorie vit dans le Turbo Frame `comprehension_frame` : tout lien vers une autre page y demande `data-turbo-frame="_top"`.
- La fenêtre de retrait de chaque ligne de la liste est rendue même fermée : elle pèse sur chaque ligne de la page de la classe.
- `exercise_badges` garde le record d'un élève toutes classes confondues (index unique `student_id, exercise_id`) : il ne peut pas servir une lecture par classe.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Lacunes et remédiations d'un élève sur sa fiche | V5 (AS-17) | `remediation` |
| Retour de la page de résultat vers la fiche | La page de résultat a un seul lien de retour (UDR-0023) | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0097 (Proposé) |
| **UDR produits** | UDR-0107, UDR-0108, UDR-0109 (Proposé) |
