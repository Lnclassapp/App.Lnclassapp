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
| 2026-10-16 | Réponses du porteur : recommandations acceptées sauf Q6 ; Lot B retiré, Lot C en correctif séparé | « pas de moyenne de classe » ; la dette des sous-pages archivées part tout de suite sur `fix/classe-archivee-sous-pages` | ADR-0098, UDR-0110, UDR-0111 acceptés ; UDR-0112 abandonnée |
| 2026-10-16 | Lot 0 : le DTO ne porte que `suffix` et `max_students` | L'établissement et la classe sont des arguments du use case, comme `ArchiveClassroom` ; les répéter dans le DTO ferait deux sources | Non |
| 2026-10-16 | Lot 0 : la longueur du nom complet n'est pas validée par le DTO | Elle dépend du préfixe, que seul le use case connaît (niveau et série de la classe lue) | Non (ADR-0098 §4) |
| 2026-10-16 | Lot A : une query `ClassroomSettingsQuery` pour la modale (préfixe, suffixe, effectif), absente du plan | La modale doit montrer le préfixe et l'effectif avant tout envoi ; le use case ne sert pas la lecture | Non |
| 2026-10-16 | Lot A : un concern `ClassroomSettingsActions` porte `edit` et `update` des deux espaces | Les deux contrôleurs ne diffèrent que par l'établissement et le retour sans JavaScript ; la policy des gestes de structure garde aussi la lecture de la modale | Non |
| 2026-10-16 | Lot A : le succès re-demande la page par morphing au lieu de remplacer la carte | Comme « Ajouter une classe » : la carte peut changer de place (« 6ème A » passe avant « 6ème 1 ») | UDR-0110 précisée |
| 2026-10-16 | Lot A : le champ du suffixe est écrit à la main, pas par `ui_field` | Le préfixe doit se glisser entre le libellé et le champ, sur la même ligne ; mêmes classes, même aide, même erreur reliée | Non |
| 2026-10-16 | Lot A : un refus « classe archivée » répond 422 en Turbo Stream (toast neutre, page rafraîchie) | Comme les autres conflits de l'archivage (UDR-0083) | Non |
| 2026-10-16 | Lot C : refus d'une classe archivée en delivery, avant la policy, sur les six pages `GET` sous `/classrooms/:id/…` (modale des jours d'une assignation comprise, absente du plan) | Les policies de lecture servent aussi la page principale et l'élève ; `FollowAssignmentPolicy` accepte l'archivée par décision (ADR-0072 §4.5). Le contrôle ne coûte aucune requête | Non (PRD §2) |
| 2026-10-16 | Lot C : les écritures sous `/classrooms/:id/…` gardent leur refus 403 au motif « classe archivée » | Déjà refusées par leurs use cases, avec le toast voulu par l'UDR-0081 §3.7 (amendée le 2026-10-08) ; rien n'y est lu | Non |

## Ce qui a dérapé

- **Les boutons « Copier le lien » disparaissaient de la fiche après tout `turbo_stream.refresh`** (« + », « − », archivage, et ici « Modifier la classe ») : le morphing reportait l'attribut `hidden` du serveur sur un bouton déjà montré, sans rappeler `connect()`. Constaté sur la capture après enregistrement ; corrigé dans `clipboard_controller` (`keepShown` sur `turbo:before-morph-attribute`, comme `password-reveal`) et vérifié par le test système de ce chantier.
- L'ADR-0098 §6 rend `headcount` dans les `errors` du refus « plafond sous l'effectif » : `RendersResult#add_errors` l'aurait pris pour un champ. Le contrôleur l'écarte et s'en sert pour le message (`count`), avec le préfixe et la place du suffixe pour « trop long ».
- Le premier `bin/ci-quiet` a relevé trois tests existants que le Lot A cassait (lien de modification dans la carte de la direction, partiel du menu sans `edit_path`, liste fermée des routes d'écriture de la direction) et deux branches jamais prises dans le contrôleur (refus du use case doublé par un `before_action`). L'écriture est désormais jugée par le seul use case ; la lecture de la modale garde son `before_action`.
- Une modification scriptée du journal l'avait tronqué au commit du Lot A ; il est reconstruit à la fusion de `Develop` (Lot C).
- La feuille de route (2026-09-28) rangeait ici le code régénérable, le retrait d'un élève, le changement de classe et l'archivage : tous livrés ailleurs entre le 2026-10-07 et le 2026-10-10. Un cadrage écrit sur la seule feuille de route aurait planifié du travail fait.

## Ce qu'on a appris sur la codebase

- `classrooms` a déjà tout ce qu'il faut : `name` (15), `max_students` (1 à 150, `CHECK`), index unique `(school_id, school_year, name)` qui couvre les archivées. Aucune migration.
- `ClassroomNumbering.last` range un nom sans numéro avant « 1 » ; `next_name` ignore les noms sans numéro : un renommage en lettres ne casse ni « + » ni « − ».
- Le verrou de ligne de la classe est pris par `RegisterStudent`, `JoinAsStudent` et `delete_if_unused` : le contrôle du plafond doit le prendre aussi.
- Trois sous-pages lisent `ClassroomHeaderQuery`, les jours de séance lisent l'entité du repository ; les deux exposent déjà `status` : le refus d'une classe archivée ne demande aucune requête de plus.
- Seule la page de la direction a les trois chiffres de la classe (`StudentWorkQuery#classroom`) ; la page de l'enseignant n'en a aucun.
- `ClassroomInput#max_students` et `ClassroomSettingsInput#max_students` sont des attributs entiers : « 12.5 » devient 12 avant la validation. Le navigateur borne déjà le champ (`step: 1`).
- Le refus « plafond sous l'effectif » passe avant « nom pris » : le repository juge l'effectif sous verrou avant d'écrire, et seule l'écriture révèle l'index unique.
- Lot C : la connexion de l'équipe (second facteur) est limitée à 5 par minute et par adresse ; un test qui connecte l'équipe plus de cinq fois tombe en 302. Une session par rôle (`open_session`) suffit.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Archivage de l'année écoulée et passage des élèves à la rentrée | Hors périmètre (memo Q7) ; échéance le 2027-09-01 | `rentree-scolaire`, à ouvrir avant juin 2027 |
| Gestes de l'enseignant non confirmé sur sa classe (lien, retrait) | Hors périmètre ; coût consigné dans l'ADR-0085 §5 | à ouvrir |
| ~~Avis « classe archivée » des vues d'un cours et d'un essentiel (`archived_notice`), devenus inaccessibles avec le Lot C~~ | Retirés à la clôture, vue et clé ensemble | fait (clôture, 2026-10-19) |
| ~~Rayer la dette des sous-pages archivées du journal d'`archivage-classes`~~ | Prévu à la clôture (plan, Lot C) | fait (clôture, 2026-10-19) |

## Clôture

| | |
|---|---|
| **Livré le** | Lot C : PR #251 (2026-10-16) ; Lots 0 et A : PR `feature/vie-de-la-classe` → `Develop` (2026-10-19). Lot B retiré (Q6) |
| **PR** | #251 (Lot C) ; `feature/vie-de-la-classe` (Lots 0 et A) |
| **ADR produits** | ADR-0098 *(accepté)* |
| **UDR produits** | UDR-0110, UDR-0111 *(acceptées)* ; UDR-0112 *(abandonnée)* |
