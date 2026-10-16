# Memo — Un enseignant qui enseigne plusieurs matières

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — questions au porteur ouvertes (voir « Ce que le grill a révélé ») |
| **Ouvert le** | 2026-10-16 (demande du porteur : « et enseignant avec plusieurs disciplines au sein de l'établissement ») |
| **Branche** | `docs/cadrage-enseignant-plusieurs-matieres` (cadrage), puis `feature/enseignant-plusieurs-matieres` |
| **Programme** | `refonte-application` — chantier hors vague, né de la question 9 de [`multi-etablissements-enseignant`](../multi-etablissements-enseignant/memo.md#ce-que-le-grill-a-révélé) |

---

## Le problème

Un enseignant n'a qu'**une** matière : `teacher_profiles.material_id`, non nulle, choisie à l'inscription et jamais modifiable ensuite. Tout ce qu'il voit en dépend : son catalogue, les cours de la page de classe, le score moyen de son accueil, ses « Activités », la signature de ses annonces.

Or beaucoup d'enseignants ivoiriens en ont deux, surtout au collège et dans le privé : Physique-Chimie et SVT, Mathématiques et Physique-Chimie, Histoire-Géographie et EDHC, Français et Histoire-Géographie. Aujourd'hui, un tel enseignant :

- ne trouve pas sa seconde matière dans son catalogue (filtré par lecture sur la première) ;
- ne voit pas les cours de sa seconde matière sur la page de sa classe, donc n'a aucun chemin pour en assigner les exercices depuis la classe ;
- voit un score moyen et des « Activités » qui ignorent sa seconde matière ;
- n'a qu'un recours : un second compte, avec un autre numéro.

## Pour qui

- **L'enseignant** (Teacher) qui enseigne deux ou trois disciplines, dans un ou plusieurs établissements. Moments : l'inscription, puis « Mon profil » (ajouter ou retirer une matière), puis tous ses écrans de travail (accueil, catalogue, page de classe, suivi).
- **La direction** (SchoolStaff) : la liste « Enseignants » dit toutes les matières de chacun.
- **L'élève** : la signature des annonces nomme les matières de l'enseignant.
- **L'équipe** (Team) : le compte d'enseignants par matière reste juste ; une matière portée par un enseignant ne peut pas être supprimée.

## Pourquoi maintenant

- Le porteur le demande (2026-10-16), au moment où `multi-etablissements-enseignant` est cadré : les deux chantiers relisent les **mêmes écrans** de l'enseignant (accueil, catalogue, profil, en-tête). Les cadrer ensemble évite de réécrire deux fois `TeacherHomeQuery` et `TeacherAudienceQuery`.
- Le coût d'attendre grandit : chaque nouvelle lecture « matière de l'enseignant » (la dernière : `ClassroomGapsQuery`, ADR-0101 §4.4, cadrée le même jour) ajoute un endroit à migrer.

## Inventaire — où la matière unique est lue

État de `Develop` au 2026-10-16 (commit `dee185e8`). Vérifié dans le code.

### 1. Le stockage

| Élément | État |
|---|---|
| Colonne | `teacher_profiles.material_id bigint NOT NULL`, index `index_teacher_profiles_on_material_id`, FK `materials` (`db/schema.rb`) |
| ORM | `Orm::TeacherProfile belongs_to :material` ; `Orm::Material has_many :teacher_profiles, dependent: :restrict_with_error` |
| Entité | `Entities::Identity::TeacherProfile = Data.define(:user_id, :material_id, :onboarding_completed_at)` |
| Port | `Ports::Identity::TeacherProfileRepositoryPort#find_by_user_id` ; un seul consommateur, l'onboarding (`Classroom::TeacherOnboardingsController`), qui ne lit **pas** la matière |
| Écriture | **une seule** : `RegistrationRepository#create_teacher(user:, pin:, material_id:, joined_via:)`, appelée par `UseCases::Identity::RegisterTeacher` (les deux voies, ADR-0083). Aucun chemin ne la modifie ensuite |
| Profil | `teacher_profiles` porte aussi `referral_token` (parrainage, ADR-0063), `joined_via` et `onboarding_completed_at` : la table reste |
| Plusieurs enseignants dans une classe | **Oui, déjà prévu** : `teacher_classrooms` a un index unique `(teacher_id, classroom_id)`, pas `(classroom_id)`. `TeachPolicy` et `ReadClassroomPolicy` autorisent par la liaison. Rien ne relie une liaison à une matière |

### 2. Les lectures « sa matière » (le filtre)

| Où | Ce qui est filtré |
|---|---|
| `Queries::Catalog::TeacherAudienceQuery` → `Scope(audience:, material_id:)` | portée du catalogue (`pick(:material_id)`) |
| `Catalog::CoursesController#index` → `CourseCatalogQuery#call(material_id:)` | cartes du catalogue : `scope.where(material_id:)` |
| `app/views/catalog/courses/index.html.erb` | sous-titre « %{material} à vos niveaux » ; **pas de liste « Matière »** pour l'enseignant (UDR-0077 §3.2) |
| `Queries::Classroom::ClassroomOverviewQuery#courses` | bloc « Cours » de la page de classe : `where(material_id: TeacherProfile…select(:material_id))` ; l'équipe voit tout |
| `Queries::Classroom::TeacherHomeQuery` | badge de matière de l'en-tête de l'accueil, illustration et lien des bulles « Cours » (`material_slug`), **score moyen** par classe (`courses: { material_id: }`) |
| `Queries::Classroom::TeacherFollowUpsQuery` | « Activités » de l'accueil : assignations d'un exercice de sa matière |
| ADR-0101 §4.4 `ClassroomGapsQuery#summary` (cadrée, **pas encore codée**) | fiches à revoir : celles des cours de `ClassroomOverviewQuery#courses`, donc sa matière |

### 3. Les lectures « nom + matière » (l'étiquette)

| Où | Affichage |
|---|---|
| `Queries::Identity::ShellUserQuery#teacher_detail` | ligne de détail de l'en-tête : « Physique-Chimie · Lycée X » |
| `Queries::Identity::ProfileQuery#material_name` → `identity/profiles/_information.html.erb` | ligne « Matière » de « Mon profil », **en lecture seule** |
| `Queries::Communication::InboxQuery` (`left_joins(author: { teacher_profile: :material })`) → `Communication::MessagesHelper#announcement_signature` | signature d'annonce « M. Kouassi · SVT » (UDR-0071 §3.2) |
| `Queries::School::SchoolTeachersQuery` → `school_admin/teachers/index.html.erb` | colonne « Matière » de « Enseignants » (direction) |
| `Queries::School::DepartedTeachersQuery` → `school_admin/departed_teachers/index.html.erb` | « Enseignants retirés » |
| `Queries::School::JoinRequestsQuery` → `teams/schools/_join_requests.html.erb`, `classroom/teacher_homes/_pending_colleagues.html.erb` | demandes en attente (en pause, ADR-0073) |
| `Queries::School::SchoolDetailQuery` → `teams/schools/show.html.erb` | fiche d'un établissement côté équipe |
| `Queries::Catalog::MaterialsQuery` | « N enseignants » par matière (équipe) |
| `Repositories::Catalog::TaxonomyRepository#delete_material` | refuse de supprimer une matière portée par un `teacher_profiles` |

### 4. Ce qui ne lit **pas** la matière de l'enseignant

- **Aucune policy.** `AssignPolicy`, `TeachPolicy`, `ReadClassroomPolicy`, `ReadPublishedPolicy` ignorent la matière : le catalogue est restreint **par lecture**, un cours d'une autre matière reste ouvert et assignable par son adresse (UDR-0077, « Le catalogue de l'enseignant est restreint par lecture, pas par policy »).
- **Les exercices assignés de la page de classe** (`ClassroomOverviewQuery#assignments`) : toutes les assignations actives de la classe, toutes matières, avec un badge de matière par ligne. Deux enseignants d'une même classe y voient déjà le travail l'un de l'autre.
- **Le suivi d'un exercice assigné** (`AssignmentFollowUpQuery`) et la **fiche d'un élève** (ADR-0097 : « toutes les matières »).
- **Le nombre d'exercices actifs** par classe de l'accueil (`TeacherHomeQuery#classrooms`, toutes matières).
- **Parrainage et invitations** (`ReferralRepository`, `InviteLinkRepository`, `ReferralQuery`) : ils lisent `teacher_profiles.referral_token` et l'établissement principal, jamais la matière. L'invité choisit sa propre matière.
- **L'onboarding** (`TeachingSelectionQuery`, `HomeDestinationQuery`) : seulement `onboarding_completed_at`.
- `classroom_assignments.assigned_by_id` existe : on sait qui a assigné, pas « pour quelle matière ».

### 5. Le badge de matière

L'audit `audit-ux-roles` recommandait de masquer le badge des cartes du catalogue « pour un prof d'une seule matière » ; l'UDR-0077 §3.2 (R6) l'a fait, puis son **amendement du 2026-10-06 (bis)** l'a rétabli. **Aujourd'hui le badge est affiché partout** (cartes du catalogue, cours et exercices de la page de classe, suivi). Seul l'en-tête de l'accueil n'en porte qu'un, celui de la matière unique. Avec plusieurs matières, ces badges deviennent utiles : rien à démasquer.

### 6. Les décisions qui supposent une seule matière

| Décision | Ce qu'elle dit |
|---|---|
| Inventaire [`identity-communication.md`](../refonte-application/inventaire/identity-communication.md) (ancienne application) | « **Une seule matière par enseignant** (colonne `teachers.material_id`) » — reconduit tel quel par l'ADR-0027 (table `teacher_profiles`) |
| [ADR-0083](../../decisions/adr/0083-inscription-enseignant-en-deux-voies.md) · [UDR-0079](../../decisions/udr/0079-inscription-enseignant-en-deux-voies.md) | le formulaire porte **une** liste « Matière » |
| [UDR-0041](../../decisions/udr/0041-page-profil.md) | ligne « Matière » en lecture, sans « Modifier » |
| [UDR-0026](../../decisions/udr/0026-accueil-enseignant.md) | score moyen « sur les exercices **de la matière de l'enseignant** » |
| [UDR-0069](../../decisions/udr/0069-accueil-enseignant-par-niveau-et-assignation-depuis-le-catalogue.md) §3.3 | bulles « Cours » à l'illustration **de la** matière, lien filtré par **la** matière |
| [UDR-0077](../../decisions/udr/0077-organisation-des-ecrans-enseignant.md) §3.1, §3.2 | « Activités » et catalogue réduits à **sa** matière ; pas de filtre « Matière » |
| [UDR-0027](../../decisions/udr/0027-page-classe.md) · [UDR-0062](../../decisions/udr/0062-echeances.md) | « Cours » de la page de classe : « de la matière de l'enseignant (`teacher_profiles.material_id`) » |
| [ADR-0101](../../decisions/adr/0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md) §4.4 · [UDR-0121](../../decisions/udr/0121-fiches-a-revoir-de-la-classe-pour-l-enseignant.md) | fiches à revoir limitées à la matière de l'enseignant |
| [UDR-0071](../../decisions/udr/0071-annonces.md) §3.2 | signature « M. Kouassi · SVT » |
| Memo [`multi-etablissements-enseignant`](../multi-etablissements-enseignant/memo.md) (Q9, hors périmètre) | « la matière de l'enseignant vaut pour tous ses établissements » ; renvoie ici. L'ADR-0094 ne dit rien de la matière |
| Feuille de route `refonte-application` | ne tranche rien sur la matière de l'enseignant (aucune ligne) |

Conclusion : le changement tient en **une table de jointure** et en la réécriture d'une **quinzaine de lectures**. Aucune policy n'est à défaire.

## Hors périmètre

- **Une matière par classe** (« je fais Maths en 6ème 1 et PC en 3ème 2 ») : écarté par la recommandation de la question 1. L'ADR-0103 garde la porte ouverte (colonne facultative sur `teacher_classrooms`, plus tard).
- **Une matière par établissement** (« Maths dans A, PC dans B ») : les matières valent pour tous les établissements, comme le prévoit déjà `multi-etablissements-enseignant` (Q9).
- **Une « matière courante »** qui filtrerait tout l'espace, sur le modèle de l'établissement courant (ADR-0094) : écartée (question 5).
- **Interdire d'assigner un exercice hors de ses matières** : le catalogue reste restreint par lecture ; aucune policy nouvelle sur l'assignation.
- **Validation d'une matière par la direction** et toute preuve de qualification (question 3).
- **L'équipe qui modifie les matières d'un enseignant** depuis ses écrans de comptes.
- **Les sujets d'examen** (`exam_subjects`) de l'ancienne application, non repris.
- **Les rapports par matière** de la direction ou de l'équipe : aucun n'existe ; on n'en crée pas (question 8).

## Ce que le grill a révélé

> Questions posées au porteur le 2026-10-16. **Aucune n'est encore répondue** : la colonne « Réponse » porte la recommandation de l'architecte, qui ne vaut pas décision. Le PRD, l'ADR-0103, les UDR-0125 à 0127 et le plan sont écrits sur ces recommandations ; une réponse différente les amende avant le Lot 0.

| # | Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|---|
| 1 | **La matière est-elle attachée à l'enseignant, ou à chaque classe qu'il suit ?** | *À trancher.* **Recommandation : à l'enseignant** (une liste de 1 à 3 matières), pas à la classe. C'est ce que dit la demande (« plusieurs disciplines au sein de l'établissement ») ; l'inscription et « Mes classes » ne gagnent aucune étape ; la migration est une copie. Le coût : sur la page d'une classe, l'enseignant voit les cours de **toutes** ses matières au niveau de la classe, même celle qu'il n'y enseigne pas | Table `teacher_materials(teacher_id, material_id)` (ADR-0103). `teacher_classrooms` inchangée. Si le bruit gêne à l'usage, une colonne facultative `teacher_classrooms.material_id` viendra **s'ajouter** sans rien casser |
| 2 | Combien de matières au plus ? | *À trancher.* **Recommandation : 3.** Les bivalences ivoiriennes en font 2 ; 3 couvre « HG + EDHC + une autre ». Au-delà, l'accueil et la page de classe deviennent un catalogue | Constante `Entities::Identity::TeacherMaterials::MAX = 3` ; au moins 1 |
| 3 | Qui ajoute une matière ? L'enseignant seul, au profil, ou la direction valide ? | *À trancher.* **Recommandation : l'enseignant seul**, dans « Mon profil », sans validation : l'inscription choisit déjà la matière sans preuve (ADR-0083), et une matière ne donne **aucun droit** (aucune policy ne la lit). Le changement est écrit au journal d'audit | Nouveau use case `UpdateTeacherMaterials`, policy `ManageOwnMaterialsPolicy` (l'enseignant, sur lui-même). La direction voit le résultat dans « Enseignants », sans geste |
| 4 | Une matière « principale » ? | *À trancher.* **Recommandation : non, pas de drapeau.** L'ordre d'ajout fait l'ordre d'affichage (badges, signature) ; la première est celle de l'inscription. Un drapeau `primary` demanderait un geste « Définir comme principale » sans usage | `teacher_materials` sans colonne `primary` ; tri `(created_at, id)`. La migration crée la ligne de la matière actuelle en premier |
| 5 | Les écrans filtrés par « sa matière » : toutes ses matières ensemble, ou une à la fois ? | *À trancher.* **Recommandation : toutes ensemble par défaut, rangées par matière ; un filtre « Matière » seulement dans le catalogue**, limité à ses matières. Pas de « matière courante » de session : un enseignant de PC et SVT dans la même classe changerait de matière à chaque geste | UDR-0126 (catalogue, accueil) et UDR-0127 (page de classe). Avec une seule matière, **aucun écran ne change** |
| 6 | Le score moyen de l'accueil : sur quelles matières ? | *À trancher.* **Recommandation : sur toutes ses matières**, un seul chiffre par classe, comme aujourd'hui | `TeacherHomeQuery#average_scores` prend `material_ids`. UDR-0026 amendée en une phrase |
| 7 | Un enseignant dans plusieurs établissements (`multi-etablissements-enseignant`) : ses matières changent-elles d'un établissement à l'autre ? | *À trancher.* **Recommandation : non, ses matières valent pour tous ses établissements**, comme le dit déjà le memo de ce chantier (Q9). L'établissement courant borne les **classes** ; les matières bornent les **cours**. Les deux filtres se composent | Aucune colonne `school_id` dans `teacher_materials`. **Ordre** : les deux chantiers réécrivent `TeacherHomeQuery`, `TeacherFollowUpsQuery`, `TeacherAudienceQuery`, `CoursesController`, `ShellUserQuery`, `ProfileQuery` et `teacher_homes/show` : leurs lots ne tournent **jamais** en même temps sur ces fichiers (plan, « Articulation ») |
| 8 | La remédiation (ADR-0101) et les rapports | *À trancher.* **Recommandation : la remédiation suit la page de classe** (fiches des cours de **toutes** ses matières ; la règle de l'ADR-0101 §4.4 ne change que d'un pluriel). **Aucun rapport par matière** n'est créé ; les comptes de l'équipe (« N enseignants » par matière) comptent un enseignant dans **chacune** de ses matières | Amendement d'une ligne de l'ADR-0101 §4.4 ; `MaterialsQuery` compte `teacher_materials`. Si `remediation-ciblee` livre avant, son test « autre matière » gagne un cas « seconde matière de l'enseignant » |
| 9 | Retirer une matière : que deviennent les exercices déjà assignés dans cette matière ? | *À trancher.* **Recommandation : ils restent** (actifs, visibles sur la page de classe et dans le suivi, qui ne filtrent pas par matière) ; ils sortent seulement des « Activités » de l'accueil et du score moyen | Pas de cascade ; message d'aide dans la modale (UDR-0125) |
| 10 | La signature d'annonce d'un enseignant de deux matières | *À trancher.* **Recommandation : les noms courts, dans l'ordre** : « M. Kouassi · PC, SVT ». Une seule matière : inchangé (« M. Kouassi · SVT ») | `InboxQuery` agrège les matières ; `MessagesHelper` choisit nom ou noms courts |
| 11 | L'inscription : une ou plusieurs matières ? | *À trancher.* **Recommandation : la matière obligatoire, plus une seconde facultative** (« Autre matière (facultatif) »), deux listes simples ; la troisième s'ajoute au profil. Une liste de cases à cocher allongerait un formulaire déjà long sur téléphone | DTO `second_material_slug` ; UDR-0125 §3.1 amende UDR-0079 |

## Cas limites identifiés

- **Même matière choisie deux fois** à l'inscription : dédoublonnée, une seule ligne.
- **Retirer toutes ses matières** dans la modale : refus « Gardez au moins une matière. », rien n'est écrit.
- **Quatre matières cochées** (formulaire forgé, ou JavaScript absent) : refus « 3 matières au plus. », rien n'est écrit.
- **Deux onglets** qui enregistrent chacun une liste : la dernière gagne ; le plafond tient car chaque enregistrement **remplace** toute la liste dans une transaction (pas d'ajout incrémental).
- **Slug de matière inconnu ou supprimé entre l'affichage et l'envoi** : refus `:inclusion` sur le champ, rien n'est écrit.
- **L'équipe supprime une matière** portée par un enseignant : refusée (« matière utilisée »), comme aujourd'hui.
- **Catalogue `?material=` hors de ses matières** (lien partagé par un collègue) : aucun cours, avec « Tout voir » (comportement actuel d'un filtre sans résultat).
- **Deux enseignants de la même classe**, PC et SVT : chacun voit les cours de ses matières ; les exercices assignés restent tous visibles, chacun avec son badge (inchangé).
- **Enseignant anonymisé** (ADR-0036) : ses lignes `teacher_materials` restent, comme `teacher_profiles` ; la signature garde les matières (UDR-0071, « un auteur anonymisé ne garde que sa fonction »).
- **Enseignant de trois matières au même niveau** : la page de classe montre trois bandes de cours ; c'est la limite haute assumée par le plafond.

## Questions encore ouvertes

- Les questions 1 à 11 ci-dessus, **à faire répondre par le porteur avant le Lot 0**.
- Ordre avec `multi-etablissements-enseignant` : le premier des deux chantiers dont le Lot A (lectures de l'enseignant) fusionne fixe la forme de `TeacherHomeQuery::Row` ; l'autre s'y rebase (plan, « Articulation »).
- Compter en production les enseignants (`SELECT COUNT(*) FROM teacher_profiles`) avant le Lot 0 : la migration copie une ligne par profil, le nombre doit être retrouvé à l'identique dans `teacher_materials`.
