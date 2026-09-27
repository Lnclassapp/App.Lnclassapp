# ADR-0019 : Simulation des Élèves de Démonstration (Demo Students)

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-08-27 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique
Dans la phase de lancement de Lnclass, il est crucial de déclencher rapidement un "aha moment" chez les enseignants lorsqu'ils créent leur première classe. Un établissement nouvellement inscrit n'ayant pas encore invité ses vrais élèves, l'enseignant se retrouve face à un tableau de bord vide. S'il assigne un exercice, il ne verra aucune statistique ni aucune remédiation se générer, ce qui l'empêche de percevoir la valeur immédiate du produit (surtout la fonctionnalité phare de détection des lacunes et remédiation automatique). 
L'objectif est de peupler les classes avec des "élèves de démonstration" qui vont automatiquement réaliser les exercices assignés de façon réaliste.

## 2. Décision

### 2.1. Marquage des Élèves Démos
* **Décision** : Ajout d'un flag `is_demo` (boolean, défaut à false, non-nul) sur la table de persistance de l'utilisateur (ou `students`). Ce flag doit être remonté jusqu'aux entités de la couche Domaine (`Entities::Student` et `Entities::User`).
* **Justification** : Cela permet d'identifier formellement les données simulées sans dépendre de rôles arbitraires ou de noms spécifiques. Cela simplifie le filtrage dans l'analytique globale et permet une suppression de masse sécurisée.
* **Conséquences** : Les repositories (`StudentRepository` et `UserRepository`) doivent mapper ce nouveau champ de la base vers le domaine.

### 2.2. Génération et Réalisme
* **Décision** : Le système injecte 40 à 45 élèves automatiquement à la création d'une classe via un nouveau cas d'usage `GenerateDemoStudents`. Les noms générés doivent refléter la réalité démographique de la Côte d'Ivoire (Kouassi, Bamba, Diarrassouba, etc.) pour une immersion totale. Aucun badge visuel de type "Démo" n'est affiché.
* **Justification** : L'enseignant doit avoir l'illusion d'une vraie classe.
* **Conséquences** : La génération aléatoire des prénoms et noms nécessite un dictionnaire interne léger. Chaque élève se verra attribuer (en mémoire ou en métadonnée) un profil caché (Fort, Moyen, En difficulté) qui conditionnera ses probabilités de succès ultérieures.

### 2.3. Exécution de la Simulation et Remédiation
* **Décision** : Lorsqu'un exercice est assigné, un ActiveJob asynchrone (`SimulateClassroomExerciseJob`) boucle sur les élèves `is_demo` pour simuler leurs participations via le Use Case `SimulateDemoStudentSession`.
* **Justification** : Évite le blocage du thread (timeout) du professeur lors de l'assignation. Les dates (`started_at`, `completed_at`) sont mockées pour créer une durée réaliste (5 à 20 minutes) et crédibiliser les métriques de temps de réponse.
* **Conséquences** : 
  - La simulation s'appuie sur la réutilisation stricte des Use Cases existants (`start_exercise_session`, `submit_question_attempt`, `complete_exercise_session`) pour ne pas dupliquer la logique métier d'évaluation.
  - **Boost de Remédiation** : Lors d'une remédiation, les élèves gagnent un boost de taux de succès (+60% pour les plus faibles) pour générer des courbes d'amélioration visibles sur les tableaux de bord de l'enseignant.

### 2.4. Optimisation de l'Insertion Massive (Août 2026)
* **Décision** : Pour éviter les requêtes N+1 et les timeouts (qui survenaient lors de la création d'une école complète avec des dizaines de classes), l'insertion des classes, utilisateurs démos et profils élèves se fait exclusivement via `insert_all!` (Bulk Insert).
* **Prévention des Collisions** : 
  - **Slugs de classes** : Le nom de l'établissement (`school.slug`) et un code unique sont ajoutés au slug de la classe pour garantir l'unicité globale PostgreSQL (`[ecole-slug]-[classe-slug]-[unique-code]`).
  - **Numéros de Contact (varchar(10))** : Pour éviter l'erreur de "Birthday Paradox" due aux nombres aléatoires (qui causaient des doublons sur les numéros d'élèves), le contact des élèves démos est généré de manière séquentielle et déterministe (`[unique_code_classe][index_sequentiel_5_chiffres]`). Cela garantit un respect strict de la limite de 10 caractères et une unicité absolue.
  - Les élèves démos ne sont générés **que pour les deux premières classes** de chaque niveau afin de limiter l'explosion volumétrique inutile tout en garantissant le "aha moment" de l'enseignant.

### 2.5. Purge des Données (Transition)
* **Décision** : Un Use Case `PurgeDemoStudents` est mis à disposition des enseignants et de l'équipe commerciale (Team).
* **Justification** : L'enseignant doit pouvoir nettoyer sa classe lorsqu'il est prêt à inviter de vrais élèves. L'équipe commerciale peut l'exécuter à la fin d'une démonstration sur le terrain.


## 3. Conséquences
- Création de la migration pour `is_demo`.
- Création du module de génération de noms ivoiriens.
- Développement des trois nouveaux Use Cases (`GenerateDemoStudents`, `SimulateDemoStudentSession`, `PurgeDemoStudents`) et du Job asynchrone.
- Intégration de la stratégie de Bulk Insert (`insert_all!`) dans le `ClassroomRepository` avec génération déterministe des contacts.
- Aucune dette technique générée sur la logique d'évaluation, car la simulation orchestre les Use Cases existants.
