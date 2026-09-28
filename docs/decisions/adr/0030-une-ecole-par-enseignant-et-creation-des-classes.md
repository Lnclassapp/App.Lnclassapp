# ADR-0030 : Une école visible par enseignant en V1, `teacher_schools` avec drapeau « principale », classes générées à la création de l'établissement puis gérées par l'équipe et la direction

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-06**, bloque la V1 (Lot D) |
| **Remplace** | [ADR-0004](./0004-autorisation-multi-etablissements-enseignants.md) §3.1 (plusieurs écoles) et §2 (création de classe par l'enseignant) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0004 autorise un enseignant dans plusieurs établissements, alors que le [plan V1](../../chantiers/refonte-application/plan.md) le limite à une école, « tranché par ADR », sans que l'ADR existe (**C-01**). L'ADR-0004 §2 laisse l'enseignant créer des classes ; le code réserve ce droit à `team` et à `school_admin` ; le plan V1 dit que « les écoles et les classes sont créées par l'équipe » (**C-27**). Le Lot D prévoit qu'un enseignant « s'inscrit, déclare les classes qu'il enseigne ». Dans l'ancien code, l'onboarding était déduit de `classrooms.empty?` et bouclait. Les classes par défaut d'une école étaient générées après coup, hors transaction, en devinant le collège par une regex sur le nom et le niveau par son libellé, avec 45 élèves de démonstration par classe.

## 2. Moteurs de décision

1. La V1 n'a qu'une école par enseignant, mais la V3 doit pouvoir en ajouter une sans migration.
2. Un enseignant ne voit que les classes de son école.
3. Une école naît avec ses classes : aucune école sans classe, aucune classe à moitié générée.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Colonne `teachers.school_id` | La plus simple en V1 | Migration de données en V3 |
| B — **`teacher_schools` + drapeau `primary`** | Aucune migration en V3 | Une table pour une seule ligne en V1 |

## 4. Décision

> **Nous gardons `teacher_schools` avec un drapeau `primary`, nous limitons l'enseignant à une seule ligne en V1, nous générons les classes par défaut dans la transaction qui crée l'établissement, et nous réservons la gestion des classes à l'équipe en V1 et à la direction à partir de la V2.**

**Établissements** (`schools`, contexte `school`), créés par l'équipe à l'écran ou par import (ADR-0039), policy `School::ManageSchoolPolicy` : `drena_id` (FK, `NOT NULL`), `name`, `sigle`, `status` `CHECK IN ('draft','active','inactive')`, `school_type` `CHECK IN ('public','private','mixed')` (libellés : Public, Privé, Mixte) et **`cycle` `CHECK IN ('first','both')`**. À l'import, `cycle` est déduit du nom : `first` s'il contient « collège » (accents et casse ignorés : « Collége », « COLLEGE »), sinon `both`. L'équipe peut le corriger.

**Table `teacher_schools`** (contexte `school`) :

| Colonne | Type | Contrainte |
|---|---|---|
| `teacher_id` | `bigint` | `NOT NULL`, FK `users` |
| `school_id` | `bigint` | `NOT NULL`, FK `schools` |
| `primary` | `boolean` | `NOT NULL DEFAULT false` |
| `created_at` | `datetime` | `NOT NULL` |

**Index** :

- unique `(teacher_id, school_id)` ;
- unique partiel `(teacher_id) WHERE primary`, qui garantit une seule école principale.

**En V1** :

- l'enseignant choisit son école pendant l'onboarding, et la ligne est créée avec `primary = true` ;
- `School::AttachTeacher` refuse une seconde ligne par `:conflict`. Seule l'équipe change l'école d'un enseignant.

L'école visible est toujours l'école principale ; elle alimente `actor.school_id` (ADR-0028).

**Enseignement** : `teacher_classrooms` (contexte `classroom`) porte `teacher_id` (FK `users`), `classroom_id`, `created_at` et un index unique `(teacher_id, classroom_id)`. En V1, l'enseignant **déclare** lui-même les classes qu'il enseigne (`Classroom::DeclareTeaching`). La policy `Classroom::DeclareTeachingPolicy` exige :

- le rôle `teacher` ;
- `classroom.school_id == actor.school_id` ;
- une classe `active`.

Il retire sa déclaration par `Classroom::WithdrawTeaching`, qui supprime la ligne : c'est une liaison, pas une production d'élève.

**Onboarding** : état persisté `teacher_profiles.onboarding_completed_at` (`datetime NULL`), posé à la fin du parcours et jamais recalculé à partir des classes.

**Génération des classes par défaut**, dans la transaction de `School::CreateSchool` ou dans l'élément racine de l'import :

- plan par `school_type` et par **slug** de niveau (ADR-0029), jamais par libellé ; un établissement `mixed` suit le barème `private`, comme dans l'ancien où tout type non public prenait la configuration « privée » ; une école `first` ne reçoit que les niveaux de `cycle = 'first'` (ADR-0034) ;
- « par série » : pour chaque série liée au niveau dans `level_series` ; série nommée : seulement si le couple existe ;
- un niveau ou une série absent du référentiel est sauté et compté (`details` du rapport, ADR-0039) ;
- nom `« <niveau> <n> »` ou `« <niveau> <série> <n> »`, toujours avec une espace : « 6ème 1 », « Tle D 3 », « Tle A1 2 » ;
- année `SchoolYear.current`, `max_students` 80, `join_code` unique en base et dans le lot en cours (ADR-0041) ;
- aucun élève de démonstration.

| Niveau (slug) | `public` | `private` et `mixed` |
|---|---|---|
| `6eme`, `5eme` | 4 chacun | 2 chacun |
| `4eme`, `3eme` | 10 chacun | 4 chacun |
| `2nde`, `1ere` | 6 par série | 3 par série |
| `tle` | C 2, D 6, A1 3, A2 2 | C 1, D 3, A1 2, A2 2 |

**Création et gestion d'une classe** : `Classroom::CreateClassroom` est autorisé par `Classroom::ManageClassroomPolicy` :

- en V1, `team` seul ;
- à partir de la V2, aussi le `school_admin` rattaché à l'école de la classe (ADR-0044).

L'enseignant ne crée jamais de classe.

## 5. Conséquences

### 🟢 Positives

- C-01 et C-27 sont fermées, et le Lot D a un modèle sans ambiguïté.
- Une école importée est utilisable tout de suite : ses classes existent, avec leur code d'adhésion.
- La V3 ajoute le sélecteur d'école en levant la règle « une ligne » dans le use case, sans toucher au schéma.
- La boucle d'onboarding de l'ancien ne peut plus se produire.

### 🔴 Coûts consentis

- Un enseignant peut se déclarer dans n'importe quelle classe de son école, et accède ainsi à la liste nominative. On accepte ce risque en V1 : les classes sont créées par l'équipe et la liste n'expose pas les contacts (ADR-0028). En V2, la direction peut retirer une déclaration.
- Un enseignant qui change d'établissement en cours d'année passe par l'équipe.
- Le plan de génération est dans le code : le changer demande une PR. Une école aux effectifs différents se corrige ensuite à l'écran.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Entities::Classroom::DefaultClassroomPlan
# Rôle : nombre de classes générées par niveau et série à la création d'un établissement
# ADR  : 0030
PLAN = {
  "public"  => { "6eme" => 4, "5eme" => 4, "4eme" => 10, "3eme" => 10, "2nde" => { per_series: 6 },
                 "1ere" => { per_series: 6 }, "tle" => { "c" => 2, "d" => 6, "a1" => 3, "a2" => 2 } },
  "private" => { "6eme" => 2, "5eme" => 2, "4eme" => 4, "3eme" => 4, "2nde" => { per_series: 3 },
                 "1ere" => { per_series: 3 }, "tle" => { "c" => 1, "d" => 3, "a1" => 2, "a2" => 2 } }
}.freeze

def self.for(school_type) = PLAN.fetch(school_type == "public" ? "public" : "private")
```

`teacher_schools` : index unique `(teacher_id, school_id)` et index unique partiel `(teacher_id) WHERE "primary"`.

## 7. Comment vérifier que la décision est respectée

- Test de repository : une seconde ligne `primary` lève `ActiveRecord::RecordNotUnique`.
- Tests de policy : `DeclareTeachingPolicy` refuse une classe d'une autre école et une classe archivée ; `ManageClassroomPolicy` refuse `teacher` en toute vague, et `school_admin` en V1.
- Test système : un enseignant dont on retire toutes les classes n'est pas renvoyé vers l'onboarding.
- Tests de use case : un établissement `mixed` reçoit le plan `private` ; un « Collège moderne » public reçoit 28 classes et aucune de second cycle ; un lycée public dont `1ere` n'a pas de série saute ce niveau et le compte ; un échec d'insertion d'une classe annule l'école.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0004 §3.1 (C-01) et §2 (C-27).
- La forme de la policy de l'ADR-0004 §3.3 est traitée par l'ADR-0028.

## 9. Arbitrage du porteur (2026-09-25)

- L'enseignant se déclare lui-même dans les classes de son école en V1 ; la direction gère les classes à partir de la V2.
- Les classes par niveau sont générées automatiquement à la création ou à l'import d'un établissement, avec le plan de l'ancien, corrigé : cycle en colonne, correspondance par slug, noms toujours espacés, aucun élève de démonstration.
- Le type `mixed` (Mixte) est conservé et suit le barème du privé.

## Amendement du 2026-09-25

*Chantier `docs/chantiers/boucle-pedagogique`, précision du porteur du 2026-09-25. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

**Pas de formulaire de création d'établissement.** Un établissement n'arrive que par l'**import JSON** (`School::ImportSchools`, lot S3 de la V1). L'écran Établissements n'a pas de bouton « Nouvel établissement » ; son action principale est « Importer des établissements ». `School::CreateSchool`, cité au §4 ci-dessus et dans le tableau de l'ADR-0034, n'existe pas en V1.

**Quand les classes par défaut sont générées.** Uniquement à l'**import d'un établissement**, dans le même élément racine : si la génération échoue, l'établissement n'est pas créé et figure en erreur dans le rapport.

**Jamais de classes pré-créées.** Aucune classe n'existe avant son établissement. Aucun seed ni aucune tâche ne crée de classes en avance, ni en production ni ailleurs : en développement et en test, les seeds et les fabriques créent des établissements par les mêmes repositories et la même génération. Modifier un établissement (type, cycle) ne régénère jamais ses classes. En dehors de la génération, une classe ne naît que par `Classroom::CreateClassroom` (équipe en V1).

**Totaux attendus**, avec le référentiel de l'ADR-0034 (2nde liée à A et C ; 1ère et Tle liées à A1, A2, C et D) :

| Établissement | Premier cycle | 2nde | 1ère | Tle | **Total** |
|---|---|---|---|---|---|
| Lycée public (`public`, `both`) | 4 + 4 + 10 + 10 = 28 | 2 séries × 6 = 12 | 4 séries × 6 = 24 | 2 + 6 + 3 + 2 = 13 | **77** |
| Lycée privé ou mixte (`private` ou `mixed`, `both`) | 2 + 2 + 4 + 4 = 12 | 2 × 3 = 6 | 4 × 3 = 12 | 1 + 3 + 2 + 2 = 8 | **38** |
| Collège public (`public`, `first`) | 28 | — | — | — | **28** |

Ces totaux dépendent des liaisons `level_series` en base : un niveau ou une série absent est sauté et compté (§4). Les 71 classes d'un lycée public dans l'ancienne application venaient d'un référentiel qui ne liait que C à la 2nde.

## Amendement du 2026-09-28 — génération après coup des classes manquantes

*Chantier [`docs/chantiers/generer-classes`](../../chantiers/generer-classes/prd.md), [ADR-0056](./0056-generation-des-classes-manquantes.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Les classes par défaut naissent à l'import, ou après coup pour un établissement qui n'en a aucune de l'année.** L'équipe peut lancer, depuis l'écran Établissements, la génération des classes manquantes : un job reprend le même barème (`DefaultClassroomPlan`) pour chaque établissement actif ou en brouillon sans aucune classe de l'année scolaire en cours.
- La règle « modifier un établissement ne régénère jamais ses classes » tient toujours : un établissement qui a au moins une classe de l'année n'est jamais touché.


## Amendement du 2026-09-28 — code d'établissement

*Chantier [`docs/chantiers/code-etablissement`](../../chantiers/code-etablissement/prd.md), [ADR-0057](./0057-code-d-etablissement.md) (défauts à confirmer par le porteur). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **L'enseignant ne choisit plus son école : il la désigne par son code d'établissement**, transmis par l'équipe (saisi, ou porté par le lien `/e/<code>`). Un code inconnu, remplacé, ou d'un établissement inactif ou en brouillon est refusé par le même message. Le rattachement reste une ligne `teacher_schools` principale, créée dans la transaction du compte.
- Le coût consenti « un enseignant peut se déclarer dans n'importe quelle classe de son école » est borné : « son école » est celle qui lui a transmis son code.
- Chaque établissement naît avec son code (import) ; les établissements existants l'ont reçu par migration.

## Amendement du 2026-09-28 — barème en base

*Chantier [`docs/chantiers/bareme-classes`](../../chantiers/bareme-classes/prd.md), [ADR-0058](0058-bareme-des-classes-en-base.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Le barème n'est plus dans le code.** Le tableau du §4 et la constante du §6 (`DefaultClassroomPlan::PLAN`) deviennent la **valeur initiale** de la table `classroom_plan_entries`, reprise au déploiement et modifiable par l'équipe à l'écran « Barème des classes » (UDR-0045). Le coût « le plan de génération est dans le code : le changer demande une PR » est levé.
- « Par série » devient **une ligne par série liée au moment de la reprise** ; une série liée ensuite n'a pas de nombre tant que l'équipe ne l'a pas renseigné.
- « Un niveau ou une série absent du référentiel est sauté et compté » devient : **une ligne absente du barème** (niveau du premier cycle, ou couple niveau × série liée) est sautée et comptée ; un niveau du second cycle sans série liée l'est toujours.
- `Entities::Classroom::DefaultClassroomPlan.rows_for(school:, lookup:, plan:)` reçoit le barème : le domaine ne lit toujours aucune base.
- Inchangé : correspondance par identifiant de niveau (le slug ne sert plus qu'à la reprise), `mixed` suit `private`, un collège ne prend que le premier cycle, noms « 6ème 1 » / « Tle D 3 », aucune classe existante régénérée.

- **L'enseignant ne choisit plus son école : il la désigne par son code d'établissement**, transmis par l'équipe (saisi, ou porté par le lien `/e/<code>`). Un code inconnu, remplacé, ou d'un établissement inactif ou en brouillon est refusé par le même message. Le rattachement reste une ligne `teacher_schools` principale, créée dans la transaction du compte.
- Le coût consenti « un enseignant peut se déclarer dans n'importe quelle classe de son école » est borné : « son école » est celle qui lui a transmis son code.
- Chaque établissement naît avec son code (import) ; les établissements existants l'ont reçu par migration.

## Amendement du 2026-09-28 — compte en attente (ADR-0063)

*Chantier `docs/chantiers/croissance-parrainage`.* Un enseignant sans école principale n'accède qu'à l'écran d'attente et à la déconnexion (garde de `AuthenticatedController`). L'inscription sans code (code national ou DRENA → établissement) crée ce compte, avec une demande `school_join_requests` que l'équipe ou un garant du même établissement décide.

## Amendement du 2026-09-28 — la direction en V2 (ADR-0066, accepté)

*Chantier [`docs/chantiers/espace-direction`](../../chantiers/espace-direction/prd.md). Statut : **accepté** par le porteur le 2026-09-28 (avec ses retours), avec l'[ADR-0066](./0066-espace-direction-droits-et-gestes.md). Le texte ci-dessus reste ; en cas d'écart, cette section fait foi.*

- « À partir de la V2, aussi le `school_admin` rattaché à l'école de la classe » se limite à **ajouter la classe suivante d'un niveau** (`AddLevelClassroom`, ADR-0059), autorisé par `Policies::School::StaffPolicy` (`:add_classroom`). `CreateClassroom` (nom libre) et `RemoveLevelClassroom` (« − ») restent à l'équipe : `ManageClassroomPolicy` ne change pas (Q3 du porteur).
- « En V2, la direction peut retirer une déclaration » devient : le Proviseur ou le Censeur **retire un enseignant de l'établissement** (`School::DetachTeacher`) : sa ligne `teacher_schools` et ses déclarations des classes de l'établissement disparaissent ; classes, devoirs et résultats restent.
- « Un enseignant qui change d'établissement passe par l'équipe » : un enseignant **sans** école principale (retiré) rejoint un **autre** établissement avec son code d'établissement, depuis son écran d'attente (`School::RejoinSchoolWithCode`), jamais seul l'établissement qui l'a retiré (départ ouvert dans `teacher_school_departures`).
- **Réintégration** (porteur, 2026-09-28) : le Proviseur ou le Censeur de l'établissement réintègre un enseignant qu'il a retiré (`School::ReinstateTeacher`), depuis la page « Enseignants » : la ligne `teacher_schools` principale revient, le départ est clos ; les déclarations de classes ne reviennent pas (délégué) : l'enseignant se redéclare dans ses classes (`DeclareTeaching`), comme en V1.
