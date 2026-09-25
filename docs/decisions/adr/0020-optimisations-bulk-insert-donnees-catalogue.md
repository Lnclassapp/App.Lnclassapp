# ADR-0020 : Optimisation des Imports Massifs via Bulk Insert (`insert_all`)

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-08-29 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique
Dans le cadre de l'onboarding des administrateurs et du lancement initial des DRENA et établissements, le système doit importer un catalogue massif de données via des tâches en arrière-plan (`ImportSchoolsJsonJob`, `ImportCoursesJsonJob`). 
Initialement, la logique d'import (cours, classes, élèves de démonstration) reposait sur le paradigme standard de l'architecture hexagonale : une itération instanciant des entités (`Entities::Classroom`, `Entities::Student`, `Entities::Course`) qui étaient sauvegardées individuellement via les Repositories.
Cela a engendré deux problèmes critiques :
1. **Timeouts et Lenteurs (Problème de requêtes N+1)** : L'insertion de dizaines de classes avec 45 élèves de démonstration chacune provoquait des milliers de requêtes `INSERT` séquentielles (utilisateurs, étudiants, associations), surchargeant PostgreSQL et faisant planter les jobs.
2. **Explosion Mémoire** : La création itérative chargeait massivement le Garbage Collector de Ruby.

## 2. Décision

### 2.1. Dérogation au paradigme d'insertion unitaire pour le Bulk
* **Décision** : Les cas d'usage impliquant de très grands volumes de création initiale (`GenerateDefaultClassrooms`, `ImportCoursesJsonJob`) délèguent dorénavant l'orchestration de l'insertion aux Repositories via des méthodes spécialisées (`bulk_import_courses`, `bulk_create_classrooms_and_demo_students`).
* **Justification** : Cela permet d'utiliser les méthodes ActiveRecord `insert_all!` et `upsert_all` qui contournent les callbacks de modèle et insèrent les données en un seul bloc de requêtes hautement optimisées.

### 2.2. Gestion Manuelle de l'Intégrité (Identifiants et Slugs)
* **Décision** : Puisque `insert_all!` ignore les callbacks, la génération des identifiants (`public_id`, `unique_code`, `slug`) est désormais calculée et fournie explicitement dans les dictionnaires de données avant insertion.
* **Justification** : Évite les contraintes de violation d'unicité en base de données.
* **Conséquences (Slugs des Classes)** : Le nom de la classe n'est plus suffisant pour le slug (ex: `6eme-1`). Le `slug` de l'école et le `unique_code` de la classe sont désormais intégrés (`lycee-technique-6eme-1-rxu27`) pour garantir une unicité absolue dans l'index global PostgreSQL.

### 2.3. Génération Déterministe pour éviter les Collisions (Birthday Paradox)
* **Décision** : Le format des contacts (limité à `varchar(10)`) pour les élèves de démonstration ne repose plus sur de l'aléatoire complet qui provoquait des collisions statistiques (Birthday Paradox). Il utilise désormais une combinaison du `unique_code` (5 caractères) et d'un index d'itération séquentiel formaté sur 5 chiffres.
* **Justification** : Assure 0% de probabilité de conflit de clés uniques lors des très grandes vagues d'insertions de profils fictifs.


## 3. Conséquences
* **Performances Extrêmes** : La génération complète des écoles, de leurs classes par défaut et de milliers d'élèves démos se fait en moins de 3 secondes par établissement. L'import des programmes et exercices via JSON est quasiment instantané.
* **Complexité Localisée** : Le code de formatage des Hash pour `insert_all!` se retrouve concentré dans les Repositories (notamment `CourseRepository` et `ClassroomRepository`), isolant ainsi cette complexité du reste des Use Cases métier.
* **Mise à jour requise des ADR liés** : Les contraintes sur les `Demo Students` ont été répercutées dans l'ADR-0019 (Sections 2.4 et 2.5).
