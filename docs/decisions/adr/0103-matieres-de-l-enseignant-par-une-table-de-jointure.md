# ADR-0103 : Les matières d'un enseignant vivent dans `teacher_school_materials`, une liste par rattachement enseignant-établissement, 1 à 3, modifiées par lui seul
<!-- index
titre: Matières de l'enseignant — une liste par rattachement enseignant-établissement, 1 à 3, sans principale
statut: Accepté *(porteur, 2026-10-16 ; Q1 et Q7 : matières par établissement)* — *amende 0083 (§ inscription), 0101 (§4.4) ; complète 0094 (§10)*
problematique: `teacher_profiles.material_id` n'admet qu'une matière ; un enseignant bivalent (PC et SVT, Maths et PC) n'a pas sa seconde matière dans le catalogue, la page de classe, l'accueil. Table `teacher_school_materials(teacher_id, school_id, material_id)`, clé du rattachement `teacher_schools`, copiée depuis `material_id` pour chaque rattachement puis colonne retirée ; 1 à 3, ordre d'ajout, pas de principale ; port `TeacherMaterialRepositoryPort` (`replace`, `inherit`) ; remplacement complet de la liste de l'établissement courant.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16) — Q1 et Q7 amendées : matières par rattachement enseignant-établissement |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/enseignant-plusieurs-matieres`](../../chantiers/enseignant-plusieurs-matieres/memo.md) · programme `refonte-application`, hors vague |
| **Remplace** | — |
| **Complète** | [ADR-0094](0094-enseignant-multi-etablissements-et-etablissement-courant.md) §10 (point d'extension `teacher_schools`) |
| **Amende** | [ADR-0083](0083-inscription-enseignant-en-deux-voies.md) (champ « Matière » de l'inscription) · [ADR-0101](0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md) §4.4 (« matière » → « matières ») |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ancienne application stockait `teachers.material_id` : **une** matière par enseignant. La refonte l'a reconduite dans `teacher_profiles.material_id` (ADR-0027), non nulle, écrite une fois par l'inscription (ADR-0083) et jamais modifiée ensuite.

Le porteur demande, le 2026-10-16, qu'un enseignant puisse avoir « plusieurs disciplines au sein de l'établissement ». C'est le cas courant au collège et dans le privé : Physique-Chimie et SVT, Mathématiques et Physique-Chimie, Histoire-Géographie et EDHC.

L'inventaire du memo compte, sur `Develop` :

- **7 lectures qui filtrent** par la matière (`TeacherAudienceQuery`, `CourseCatalogQuery` via le contrôleur, `ClassroomOverviewQuery#courses`, `TeacherHomeQuery` ×2, `TeacherFollowUpsQuery`, et `ClassroomGapsQuery` cadrée par l'ADR-0101) ;
- **9 lectures qui l'affichent** à côté d'un nom (en-tête, profil, signature d'annonce, listes de la direction et de l'équipe, comptes par matière) ;
- **une seule écriture** (`RegistrationRepository#create_teacher`) ;
- **aucune policy** : la matière restreint ce que l'enseignant **voit**, jamais ce qu'il **peut** faire.

Deux faits pèsent sur le modèle :

1. `teacher_classrooms` admet déjà plusieurs enseignants par classe (index unique `(teacher_id, classroom_id)`), sans dire qui enseigne quoi.
2. `multi-etablissements-enseignant` (ADR-0094, livré avant ce chantier) introduit un **établissement courant** de session qui cloisonne tout l'espace enseignant (§10, MET-4), et désigne la ligne `teacher_schools` comme point d'extension des matières.

## 2. Moteurs de décision

1. **Dire ce que dit la demande** : « plusieurs disciplines **au sein de l'établissement** » — une discipline est un attribut de l'enseignant dans un établissement, pas d'une classe.
2. **Aucune étape de plus** pour l'enseignant qui n'a qu'une matière : son inscription, ses classes et ses écrans restent identiques.
3. **Une migration sans perte et rejouable**, en deux temps, pour que les lots parallèles ne cassent pas les lectures pas encore converties.
4. **Ne créer aucun droit** : la matière reste une lecture. Ajouter une matière ne demande donc ni preuve ni validation.
5. **Se composer avec l'établissement courant** (ADR-0094) sans second sélecteur : changer d'établissement change aussi de matières.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — **Table de jointure par enseignant** `teacher_materials(teacher_id, material_id)` | Le modèle de `teacher_schools` (ADR-0030), connu ; une copie suffit à migrer ; contraintes et FK en base ; « N enseignants » par matière en une jointure | Sur la page d'une classe, les cours de **toutes** ses matières au niveau de la classe, même celle qu'il n'y enseigne pas |
| B — Matière **par liaison** : `teacher_classrooms.material_id` (unique `teacher_id, classroom_id, material_id`) | Précis : chaque classe ne montre que la matière qu'il y enseigne ; deux enseignants d'une classe se distinguent | « Mes classes » demande une matière par classe (une étape de plus pour tous) ; `TeachingRepository#declare`/`withdraw` changent de clé ; le catalogue et l'accueil, sans classe, n'ont plus de matière de repli ; une migration qui devine |
| C — Colonne tableau `teacher_profiles.material_ids bigint[]` | Une colonne, pas de table | Pas de FK vers `materials` (la suppression d'une matière ne serait plus protégée) ; jointures en `ANY()` ; contraire aux tables de jointure du dépôt |
| D — A **et** B : la liste de l'enseignant, puis une matière facultative par liaison | Le plus précis | Les coûts de B, pour un bruit que personne n'a encore constaté |
| F — **Une liste par rattachement** `teacher_school_materials(teacher_id, school_id, material_id)` (**retenue**, réponse du porteur) | Ce que dit la demande ; l'établissement courant cloisonne déjà tout l'espace enseignant (ADR-0094 §10) ; PC dans l'un, SVT dans l'autre ; chaque lecture reçoit déjà `school_id:` | Un nouveau rattachement doit recevoir une liste (§4.4, `inherit`) ; une matière commune à deux établissements s'écrit deux fois |
| E — A plus une **matière courante** de session (comme `sessions.current_school_id`) | Écrans identiques à aujourd'hui, une matière à la fois | Un enseignant de PC et SVT dans la **même** classe changerait de matière à chaque geste ; un second sélecteur à côté de celui de l'établissement |

## 4. Décision

> **Réponse du porteur du 2026-10-16** ([memo](../../chantiers/enseignant-plusieurs-matieres/memo.md#réponses-du-porteur-2026-10-16)) : recommandations acceptées **sauf Q1 et Q7**. Les matières ne sont pas attachées au compte mais au **rattachement enseignant-établissement** (`teacher_schools`, point d'extension prévu par l'[ADR-0094 §10](0094-enseignant-multi-etablissements-et-etablissement-courant.md)) : PC dans l'un, SVT dans l'autre est possible. Le profil gère les matières de l'établissement courant. Cette version de l'ADR retient l'option F, et non plus l'option A.

> **Nous stockons les matières d'un enseignant dans `teacher_school_materials(teacher_id, school_id, material_id, created_at)`, une liste par rattachement enseignant-établissement, de 1 à 3 lignes, rangées par ordre d'ajout, sans matière principale. L'enseignant remplace lui-même, en entier, la liste de son établissement courant depuis son profil. Toutes les lectures « sa matière » deviennent « ses matières de l'établissement courant » ; `teacher_profiles.material_id` est copiée pour chaque rattachement, puis retirée au Lot Z.**

### 4.1 Schéma

- `teacher_school_materials` : `teacher_id` (FK `users`), `school_id` (FK `schools`), `material_id` (FK `materials`), toutes `on_delete: :restrict` ; `created_at`. Index unique `(teacher_id, school_id, material_id)` ; index `(school_id)`, `(material_id)`.
- **La clé du rattachement, sans FK vers `teacher_schools`** : `(teacher_id, school_id)` est la clé unique de `teacher_schools`. La liste **survit** au retrait d'un établissement (`DetachTeacher`, `LeaveSchool`) : « Enseignants retirés » montre encore ses matières, et une réintégration (`ReinstateTeacher`) ou un retour les retrouve. Une FK vers la ligne `teacher_schools` les aurait effacées à chaque retrait. `SchoolRepository#delete_if_unreferenced` efface les listes d'un établissement supprimé (ce ne sont pas un historique).
- **Pas de colonne `primary`** (memo Q4). L'ordre est `(created_at, id)` : la matière de l'inscription vient en premier.
- `teacher_classrooms` est **inchangée** (option B écartée). Si le bruit de la page de classe gêne à l'usage, une colonne facultative `teacher_classrooms.material_id` s'ajoutera (option D).
- `teacher_profiles` reste : elle porte `referral_token`, `joined_via`, `onboarding_completed_at`. `Entities::Identity::TeacherProfile` perd `material_id` au Lot Z et ne gagne pas de `material_ids` : les matières dépendent de l'établissement, pas du profil.

### 4.2 Règle de domaine

`Entities::Identity::TeacherMaterials` (valeur pure) : `MAX = 3`, `MIN = 1`. `TeacherMaterials.build(ids)` dédoublonne en gardant l'ordre, puis renvoie un `Shared::Result` : échec `:invalid` avec `errors: { material_slugs: [:blank] }` sous 1, `[:too_many]` au-delà de 3.

### 4.3 Contrats de ports (gelés au Lot 0)

| Port | Avant | Après |
|---|---|---|
| `Ports::Identity::TeacherMaterialRepositoryPort` (**nouveau**) | — | `#material_ids_for(teacher_id:, school_id:)` → `Array<Integer>` (ordre d'ajout, `[]` sans liste) · `#replace(teacher_id:, school_id:, material_ids:, at:)` → `true`, remplace **toute** la liste dans la transaction de l'appelant, les gardées conservent leur rang · `#inherit(teacher_id:, school_id:, from_school_id:, at:)` → `true` (§4.4) |
| `Ports::Identity::RegistrationRepositoryPort` | `#create_teacher(user:, pin:, material_id:, joined_via:)` | inchangé jusqu'au Lot Z (écriture double), puis `#create_teacher(user:, pin:, joined_via:)` |
| `Ports::Identity::TeacherProfileRepositoryPort` | `#find_by_user_id`, `#complete_onboarding` | inchangé ; l'entité perd `material_id` au Lot Z |
| `Ports::Catalog::TaxonomyRepositoryPort` | `#find_material(slug:)` | inchangé (au plus 3 appels) |

Lectures (queries, pas de port) : chaque lecture de l'enseignant reçoit déjà `school_id:` (l'établissement courant, ADR-0094 §4.6) ; elle lit `teacher_school_materials` par `(teacher_id, school_id)`. Chaque `material_name`/`material_category`/`material_slug` d'une ligne « enseignant » devient `materials: [MaterialTag(id, name, shortname, category, slug)]`, dans l'ordre d'ajout. `Queries::Identity::TeacherMaterialsQuery#tags_for(teacher_ids:, school_id:)` les lit en **une** requête ; les listes (« Enseignants », « Enseignants retirés », fiche de l'équipe, demandes, annonces) les lisent **dans leur propre requête**, par la colonne `TeacherMaterialsQuery.column` (un `json_agg` corrélé) : aucune requête de plus, quel que soit le nombre de lignes ; `#for_pairs` lit des couples (enseignant, établissement) — la signature d'annonces de plusieurs établissements — et, sans établissement, l'union de ses listes (une demande en attente).

### 4.4 Écriture

- **Inscription** (`RegisterTeacher`) : `material_slug` (obligatoire) et `second_material_slug` (facultatif) ; doublon ignoré ; slug inconnu → `:invalid` sur son champ (`:inclusion`). La liste est écrite pour l'établissement de l'inscription, juste après le rattachement.
- **Profil** : `UseCases::Identity::UpdateTeacherMaterials(actor:, dto:, ip:)` → `Policies::Identity::ManageOwnMaterialsPolicy` (un enseignant **avec un établissement courant**, sur son propre compte ; `:forbidden` pour tout autre rôle) → résolution des slugs (`:inclusion`) → `TeacherMaterials.build` → transaction : `replace(teacher_id: actor.user_id, school_id: actor.school_id, …)`, puis audit `profile.materials_changed` avec `metadata: { school_id:, from: [ids], to: [ids] }`. Une liste identique n'écrit rien et réussit.
- **Un nouveau rattachement** reçoit une liste (`inherit`) : celle déjà connue pour cet établissement (un retour), sinon celle de l'établissement d'où il l'ajoute (`JoinSchoolWithCode` : `actor.school_id`), sinon sa dernière liste écrite (`ReinstateTeacher`, validation d'une demande). Aucune liste connue : rien n'est écrit. Le catalogue et l'accueil montrent alors un état vide « Choisissez vos matières », avec un lien vers la modale « Mes matières » (jamais une liste vide ni un sous-titre « Les cours de , »).
- **Remplacer, pas ajouter** : chaque écriture pose une liste complète déjà bornée, mais deux écritures simultanées (deux onglets) pouvaient, sans verrou, s'ajouter l'une à l'autre et dépasser trois lignes. `replace` verrouille donc d'abord le rattachement (`teacher_schools` `FOR UPDATE`, par `(teacher_id, school_id)`) : les écritures se suivent. Sans rattachement (retiré entre-temps), rien n'est écrit, `replace` répond `false` et le use case répond `:forbidden`, sans audit.
- **Liste identique** : comparée comme un ensemble (`before.sort == after.sort`) ; un simple changement d'ordre n'écrit rien. L'audit journalise `to:` dans l'ordre réellement stocké : `(before & after) + (after - before)`.
- **Retirer une matière** ne touche à rien d'autre : les assignations faites dans cette matière restent actives (memo Q9).

### 4.5 Lectures

| Lecture | Règle |
|---|---|
| Catalogue (`TeacherAudienceQuery`, `CourseCatalogQuery`) | `Scope(audience:, materials:)` de l'établissement courant ; `where(material_id: ids)` ; le filtre `material=<slug>` restreint à l'intérieur |
| Page de classe (`ClassroomOverviewQuery#courses`) | cours du niveau et de la série de la classe, dans les matières de l'enseignant **dans l'établissement de la classe** ; tri : ordre de ses matières, puis nom du cours |
| Remédiation (`ClassroomGapsQuery#summary`, ADR-0101 §4.4) | inchangée dans son code : elle prend les slugs des cours de la page de classe, donc toutes ses matières |
| Accueil (`TeacherHomeQuery`, `TeacherFollowUpsQuery`) | `materials: [MaterialTag]` de l'établissement courant ; score moyen et « Activités » sur leurs ids |
| Étiquettes (en-tête, profil, signature, direction, équipe) | `MaterialTag` dans l'ordre ; le **nom** quand il n'y en a qu'une, les **noms courts** séparés par « , » au-delà (`TeacherMaterialsQuery.label`) ; la signature d'une annonce lit la liste de l'établissement de l'annonce (`messages.school_id`) |
| Comptes de l'équipe (`MaterialsQuery`) | « N enseignants » = enseignants **rattachés** qui l'ont dans au moins un de leurs établissements, chacun compté une fois par matière : un enseignant de deux matières compte dans chacune |
| Suppression d'une matière (`TaxonomyRepository#delete_material`) | refusée si une ligne `teacher_school_materials` la porte |

### 4.6 Migration des données (deux temps)

1. **Lot 0 — étendre.** Créer `teacher_school_materials` et y copier, dans la même migration, une ligne par **rattachement** `teacher_schools` (la matière du profil, le `created_at` du rattachement), puis une par **retrait encore ouvert** (`teacher_school_departures` non réintégré), pour qu'un enseignant retiré la retrouve, et une par **demande en attente** (`school_join_requests`, l'établissement demandé), pour qu'un enseignant sans rattachement ne la perde pas au Lot Z, et enfin, pour tout enseignant resté **sans aucune ligne** (demande refusée ou annulée), une copie sur l'établissement de sa dernière demande, quel que soit son statut : `inherit` la retrouve alors comme dernière liste écrite. Sans demande du tout : rien. `teacher_profiles.material_id` reste, **écrite en double** par `create_teacher` et `replace` (= la première matière), pour que les lectures non encore converties restent justes pendant les lots.
2. **Lot Z — contracter.** Quand plus aucune lecture ne la lit, retirer `teacher_profiles.material_id`, son index, sa FK et l'écriture double. Migration réversible : `down` rajoute la colonne nullable et la remplit avec la première matière de l'établissement principal.

Aucune donnée n'est devinée : chaque rattachement existant a exactement la matière qu'avait l'enseignant. Requête de contrôle en production : [journal](../../chantiers/enseignant-plusieurs-matieres/journal.md).

## 5. Conséquences

### 🟢 Positives

- L'enseignant bivalent n'a plus besoin d'un second compte ; celui d'une seule matière ne voit **rien** changer.
- Aucune policy n'est réécrite ; aucune route existante ne change ; la sécurité ne dépend pas de la matière.
- Un modèle déjà connu du dépôt (`teacher_schools`), une migration par copie, rejouable.
- Le compte par matière de l'équipe devient juste pour les bivalents.
- `multi-etablissements-enseignant` et ce chantier se composent : changer d'établissement courant change aussi les matières, sans second sélecteur.

### 🔴 Coûts consentis

- **Le bruit de la page de classe** : un enseignant de Maths (6ème) et de PC (3ème) voit, en 3ème, les cours de Maths aussi. Assumé jusqu'à preuve du contraire (option D en réserve).
- **Les matières ne sont pas vérifiées** : un enseignant peut s'en déclarer trois qu'il n'enseigne pas. Sans droit attaché, le risque se limite à ses propres écrans et à sa signature.
- **Deux temps de migration** : la colonne vit en double le temps des lots, et le Lot Z est un lot à part entière, à ne pas oublier.
- **Quinze lectures à réécrire**, dont six partagées avec `multi-etablissements-enseignant` : ce chantier part de sa branche (PR #250) et fusionne après lui.
- **Une liste par établissement** : un enseignant de PC dans deux établissements la porte deux fois ; ajouter un établissement lui donne la liste de l'établissement d'où il l'ajoute, qu'il corrige ensuite dans son profil.
- La signature d'annonce mêle nom (une matière) et noms courts (plusieurs) : deux formes à tester.

## 6. Notes d'implémentation

- Migration : `db/migrate/20261016160000_create_teacher_school_materials.rb` (table, index, FK, deux `INSERT … SELECT … ON CONFLICT DO NOTHING`, `down` = `drop_table`).
- Entité : `app/domain/entities/identity/teacher_materials.rb` ; port : `app/domain/ports/identity/teacher_material_repository_port.rb` ; adaptateur : `app/infrastructure/repositories/identity/teacher_material_repository.rb` (`replace` : `delete_all` des retirées, `insert_all!` des ajoutées au même instant, l'id départage).
- Lecture des étiquettes : `app/infrastructure/queries/identity/teacher_materials_query.rb` ; rendu : `ui_subject_badges(tags, size:)`.

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/identity/teacher_materials_test.rb` : 0, 1, 3, 4 matières ; doublons ; ordre conservé.
- `test/domain/use_cases/identity/update_teacher_materials_test.rb` : refus pour élève, direction, équipe (`:forbidden`) ; slug inconnu (`:inclusion`) ; liste vide ; 4 matières ; liste identique sans audit ; audit `profile.materials_changed` sinon ; seule la liste de l'établissement courant change.
- `test/controllers/school/current_school_isolation_test.rb` : les matières d'un autre établissement n'apparaissent ni dans l'accueil, ni dans le catalogue, ni dans le profil.
- `test/db/create_teacher_school_materials_migration_test.rb` : une ligne par rattachement et par retrait ouvert, avec la matière du profil.
- `test/infrastructure/queries/**` : chaque query listée au §4.5 a un cas « enseignant de deux matières » et garde son cas « une matière » inchangé.
- Après le Lot Z : `grep -rn "teacher_profiles.material_id\|TeacherProfile.*material_id\|teacher_profile: :material" app db/seeds test/support` ne trouve rien, et `db/schema.rb` n'a plus `material_id` dans `teacher_profiles`.

## 8. Remplace, complète, amende

- **Amende** l'[ADR-0083](0083-inscription-enseignant-en-deux-voies.md) : l'inscription standard et l'inscription par lien demandent « Matière » **et** « Autre matière (facultatif) » ([UDR-0125](../udr/0125-matieres-de-l-enseignant-a-l-inscription-et-au-profil.md)).
- **Amende** l'[ADR-0101](0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md) §4.4, puce « Fiches » : « matière de l'enseignant » se lit « **matières** de l'enseignant ». Le code de `ClassroomGapsQuery` ne change pas (il lit les slugs des cours de la page).
- **Complète** l'[ADR-0027](0027-contextes-bornes-et-arborescence.md) : `teacher_school_materials` appartient au contexte `identity` (port et adaptateur), à côté de `teacher_profiles`.
- **Complète** l'[ADR-0094](0094-enseignant-multi-etablissements-et-etablissement-courant.md) §10 : le point d'extension « matières par établissement » est pris par `teacher_school_materials`.
- **S'appuie sur** l'[ADR-0030](0030-une-ecole-par-enseignant-et-creation-des-classes.md) (modèle de `teacher_schools`), l'[ADR-0094](0094-enseignant-multi-etablissements-et-etablissement-courant.md) (établissement courant, qui borne aussi les matières), l'[ADR-0034](0034-reprise-des-donnees-et-referentiel-seede.md) (matières du référentiel, suppression protégée).
- **Amende** les UDR-0026, 0027, 0041, 0062, 0069, 0071, 0077, 0079, 0121 et 0052 par les [UDR-0125](../udr/0125-matieres-de-l-enseignant-a-l-inscription-et-au-profil.md), [UDR-0126](../udr/0126-plusieurs-matieres-dans-le-catalogue-et-l-accueil-enseignant.md) et [UDR-0127](../udr/0127-plusieurs-matieres-sur-la-page-de-classe-et-dans-les-listes.md).
