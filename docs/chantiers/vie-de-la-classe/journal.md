# Journal — La vie de la classe

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Lot C — menace écrite d'abord (2026-10-16)

Inventaire des adresses qui chargent une classe par son identifiant public, sur `origin/Develop` (f8dfce89). L'archivage (ADR-0088) ne ferme ni adhésions, ni rattachements, ni assignations : un enseignant de la classe et l'équipe passent donc toujours les policies de lecture, et seule la page principale refusait la classe archivée.

| Adresse | Qui y entre (rôle admis) | Avant | Doit rendre (PRD §3, Q8) |
|---|---|---|---|
| `GET /classrooms/:id` | enseignant de la classe, équipe | 404 | 404 (inchangé) |
| `GET /classrooms/:id/courses/:course` | enseignant de la classe, équipe | **200** : cours, fiches, avis « archivée » | 404 |
| `GET /classrooms/:id/courses/:course/essentials/:essential` | enseignant de la classe, équipe | **200** : fiche, exercices, états d'assignation | 404 |
| `GET /classrooms/:id/assignments/:assignment` | enseignant de la classe, équipe | **200** : suivi nominatif (retards, compréhension) — la lecture la plus sensible | 404 |
| `GET /classrooms/:id/session_days/edit` | enseignant de la classe | 403 (motif « archivée ») | 404 |
| `GET /classrooms/:id/assignments/new` | enseignant de la classe | 403 (motif « archivée ») | 404 |
| `POST /classrooms/:id/assignments`, `PATCH /assignments/:id/archive`, `PATCH /classrooms/:id/session_days`, `PATCH /classrooms/:id/link`, `DELETE /classrooms/:id/students/:student` | enseignant, équipe (et direction pour lien et retrait) | refus 403 au motif « classe archivée » (use cases, UDR-0081 §3.7 amendée le 2026-10-08) | inchangé : écritures, rien n'est lu ni écrit |
| `GET /school-admin/classrooms/:id` | direction de l'établissement | 404 (la requête ne lit que les classes actives) | 404 (inchangé) |
| `GET /students/classroom`, accueils élève et enseignant | élève, enseignant | la classe archivée n'y figure plus (ADR-0088) | inchangé |
| `PATCH …/classroom-archivals/:id/restore` (équipe, direction) | équipe, direction de l'établissement | 200 | 200 : la restauration reste le seul geste sur une classe archivée, et rend les sous-pages |

L'élève et la direction n'entrent sur aucune sous-page (`allow_roles` : 403 avant toute lecture, quelle que soit la classe) : ils n'apprennent rien d'une classe archivée. Le refus se place en delivery, juste après la lecture de la classe et avant la policy (PRD §2) : `ReadClassroomPolicy` et `FollowAssignmentPolicy` restent « active ou archivée » (ADR-0072 §4.5), aucune requête de plus (`status` est déjà lu).

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Le périmètre se réduit à CL-02, CL-14 et la dette des sous-pages archivées | L'inventaire du code montre livrés depuis la feuille de route : l'archivage (ADR-0088), le lien remplaçable (ADR-0085), le retrait d'un élève, le choix de classe par l'élève, la page d'une classe et ses listes | Non (memo) |
| 2026-10-16 | Recommander le préfixe du barème fixe et un suffixe libre | La cascade de l'élève et le « + » restent vrais ; un nom libre les casse | ADR-0098 (proposé) |
| 2026-10-16 | Recommander l'équipe et la direction, pas l'enseignant | Même policy que « + », « − » et l'archivage ; l'enseignant se déclare sans validation (ADR-0085 §5) | ADR-0098 (proposé) |
| 2026-10-16 | Ne pas renommer `shared/_classroom_archive_menu` en y ajoutant « Modifier » | Le renommage toucherait locales et appelants sans rien changer pour l'utilisateur | Non (UDR-0111) |
| 2026-10-16 | Lot C : refus d'une classe archivée en delivery, avant la policy, sur les six pages `GET` sous `/classrooms/:id/…` (modale des jours d'une assignation comprise, absente du plan) | Les policies de lecture servent aussi la page principale et l'élève ; `FollowAssignmentPolicy` accepte l'archivée par décision (ADR-0072 §4.5). Le contrôle ne coûte aucune requête | Non (PRD §2) |
| 2026-10-16 | Lot C : les écritures sous `/classrooms/:id/…` gardent leur refus 403 au motif « classe archivée » | Déjà refusées par leurs use cases, avec le toast voulu par l'UDR-0081 §3.7 (amendée le 2026-10-08) ; rien n'y est lu | Non |

## Ce qui a dérapé

- La feuille de route (2026-09-28) rangeait ici le code régénérable, le retrait d'un élève, le changement de classe et l'archivage : tous livrés ailleurs entre le 2026-10-07 et le 2026-10-10. Un cadrage écrit sur la seule feuille de route aurait planifié du travail fait.

## Ce qu'on a appris sur la codebase

- `classrooms` a déjà tout ce qu'il faut : `name` (15), `max_students` (1 à 150, `CHECK`), index unique `(school_id, school_year, name)` qui couvre les archivées. Aucune migration.
- `ClassroomNumbering.last` range un nom sans numéro avant « 1 » ; `next_name` ignore les noms sans numéro : un renommage en lettres ne casse ni « + » ni « − ».
- Le verrou de ligne de la classe est pris par `RegisterStudent`, `JoinAsStudent` et `delete_if_unused` : le contrôle du plafond doit le prendre aussi.
- Trois sous-pages lisent `ClassroomHeaderQuery`, les jours de séance lisent l'entité du repository ; les deux exposent déjà `status` : le refus d'une classe archivée ne demande aucune requête de plus.
- Seule la page de la direction a les trois chiffres de la classe (`StudentWorkQuery#classroom`) ; la page de l'enseignant n'en a aucun.
- Lot C : la connexion de l'équipe (second facteur) est limitée à 5 par minute et par adresse ; un test qui connecte l'équipe plus de cinq fois tombe en 302. Une session par rôle (`open_session`) suffit.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Archivage de l'année écoulée et passage des élèves à la rentrée | Hors périmètre (memo Q7) ; échéance le 2027-09-01 | `rentree-scolaire`, à ouvrir avant juin 2027 |
| Gestes de l'enseignant non confirmé sur sa classe (lien, retrait) | Hors périmètre ; coût consigné dans l'ADR-0085 §5 | à ouvrir |
| Avis « classe archivée » des vues d'un cours et d'un essentiel (`archived_notice`), devenus inaccessibles avec le Lot C | Les locales appartiennent au Lot 0 ; vue et clé se retirent ensemble | clôture de ce chantier |
| Rayer la dette des sous-pages archivées du journal d'`archivage-classes` | Prévu à la clôture (plan, Lot C) | clôture de ce chantier |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | ADR-0098 *(proposé)* |
| **UDR produits** | UDR-0110, UDR-0111, UDR-0112 *(proposées)* |
