# Journal — La vie de la classe

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Le périmètre se réduit à CL-02, CL-14 et la dette des sous-pages archivées | L'inventaire du code montre livrés depuis la feuille de route : l'archivage (ADR-0088), le lien remplaçable (ADR-0085), le retrait d'un élève, le choix de classe par l'élève, la page d'une classe et ses listes | Non (memo) |
| 2026-10-16 | Recommander le préfixe du barème fixe et un suffixe libre | La cascade de l'élève et le « + » restent vrais ; un nom libre les casse | ADR-0098 (proposé) |
| 2026-10-16 | Recommander l'équipe et la direction, pas l'enseignant | Même policy que « + », « − » et l'archivage ; l'enseignant se déclare sans validation (ADR-0085 §5) | ADR-0098 (proposé) |
| 2026-10-16 | Ne pas renommer `shared/_classroom_archive_menu` en y ajoutant « Modifier » | Le renommage toucherait locales et appelants sans rien changer pour l'utilisateur | Non (UDR-0111) |
| 2026-10-16 | Réponses du porteur : recommandations acceptées sauf Q6 ; Lot B retiré, Lot C en correctif séparé | « pas de moyenne de classe » ; la dette des sous-pages archivées part tout de suite sur `fix/classe-archivee-sous-pages` | ADR-0098, UDR-0110, UDR-0111 acceptés ; UDR-0112 abandonnée |
| 2026-10-16 | Lot 0 : le DTO ne porte que `suffix` et `max_students` | L'établissement et la classe sont des arguments du use case, comme `ArchiveClassroom` ; les répéter dans le DTO ferait deux sources | Non |
| 2026-10-16 | Lot 0 : la longueur du nom complet n'est pas validée par le DTO | Elle dépend du préfixe, que seul le use case connaît (niveau et série de la classe lue) | Non (ADR-0098 §4) |

## Ce qui a dérapé

- La feuille de route (2026-09-28) rangeait ici le code régénérable, le retrait d'un élève, le changement de classe et l'archivage : tous livrés ailleurs entre le 2026-10-07 et le 2026-10-10. Un cadrage écrit sur la seule feuille de route aurait planifié du travail fait.

## Ce qu'on a appris sur la codebase

- `classrooms` a déjà tout ce qu'il faut : `name` (15), `max_students` (1 à 150, `CHECK`), index unique `(school_id, school_year, name)` qui couvre les archivées. Aucune migration.
- `ClassroomNumbering.last` range un nom sans numéro avant « 1 » ; `next_name` ignore les noms sans numéro : un renommage en lettres ne casse ni « + » ni « − ».
- Le verrou de ligne de la classe est pris par `RegisterStudent`, `JoinAsStudent` et `delete_if_unused` : le contrôle du plafond doit le prendre aussi.
- Trois sous-pages lisent `ClassroomHeaderQuery`, les jours de séance lisent l'entité du repository ; les deux exposent déjà `status` : le refus d'une classe archivée ne demande aucune requête de plus.
- Seule la page de la direction a les trois chiffres de la classe (`StudentWorkQuery#classroom`) ; la page de l'enseignant n'en a aucun.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Archivage de l'année écoulée et passage des élèves à la rentrée | Hors périmètre (memo Q7) ; échéance le 2027-09-01 | `rentree-scolaire`, à ouvrir avant juin 2027 |
| Gestes de l'enseignant non confirmé sur sa classe (lien, retrait) | Hors périmètre ; coût consigné dans l'ADR-0085 §5 | à ouvrir |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | ADR-0098 *(proposé)* |
| **UDR produits** | UDR-0110, UDR-0111, UDR-0112 *(proposées)* |
