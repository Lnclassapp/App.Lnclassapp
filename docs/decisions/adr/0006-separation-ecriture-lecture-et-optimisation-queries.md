# ADR-0006 : Séparation Stricte Écriture/Lecture (CQRS Léger) et Élimination des `group_by` Ruby

| | |
|---|---|
| **Statut** | Accepté — *instauré pour tous les tableaux de bord et rapports de statistiques* |
| **Date** | 2026-07-08 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique
Dans l'architecture hexagonale, un Use Case modélise une action métier en chargeant les Entités nécessaires via un Repository, en appliquant des validations sur ces objets purement Ruby, puis en sauvegardant l'état en base de données.
Cependant, si l'on tente d'utiliser ce même modèle d'entités pour afficher des **pages de lecture à forte volumétrie** (comme le tableau de bord administrateur `/admin`, le flux d'actualités enseignant ou le rapport détaillé d'une classe sur un cours,  exercices,habilélé ou examen blanc), le système s'effondre :
* Charger en mémoire 500 élèves, leurs 10 000 sessions d'exercices et leurs 100 000 tentatives de questions pour les convertir en instances `Entities::Student` et `Entities::ExerciseSession` consomme des centaines de mégaoctets de RAM.
* Si le calcul du taux de réussite ou de la progression se fait en Ruby via des appels `.select`, `.count` ou `.group_by(&:student_id)` sur de vastes tableaux d'objets en mémoire, le garbage collector de Ruby est saturé et le serveur Puma ralentit considérablement.

---

## 2. Moteurs de décision
* **Performance et Empreinte Mémoire (RAM) :** Maintenir des temps de réponse sous les 100 millisecondes et une consommation RAM stable même lors des pics de connexion (ex: veille des examens nationaux du BAC ou BEPC).
* **Séparation des Modèles (CQRS Léger) :** Ne pas alourdir les entités du Domaine avec des attributs de formatage d'affichage ou de comptage statistique.
* **Exploitation Maximale du Moteur SQL :** Confier les tris, jointures, groupements et agrégations mathématiques (`COUNT`, `AVG`, `MAX`) directement au moteur de base de données PostgreSQL.

---

## 3. Décision
Nous instaurons une séparation claire entre le cycle d'**Écriture (Commandes)** et le cycle de **Lecture (Requêtes)** :

1. **Écriture (Use Cases & Repositories) :** Réservée aux mutations de données (inscription, création d'école, soumission d'exercice). Passe toujours par les `Entities` et les `Ports`.
2. **Lecture Haute Performance (`app/infrastructure/queries/`) :** Les pages de listing, de feed et de tableaux de bord n'appellent **jamais** de Use Case et ne convertissent pas les données en entités du domaine. Elles instancient des objets Query spécialisés (`Queries::ClassroomReportQuery`, `Queries::TeamsDashboardQuery`).
3. **Interdiction des `group_by` en mémoire sur de gros volumes :** Les Queries doivent utiliser les agrégations SQL ou des structures indexées (`index_by`) sur des périmètres restreints par la base de données.

---

## 4. Conséquences

### 🟢 Positives
* **Rapidité Foudroyante :** Les rapports administratifs et de classe s'affichent instantanément en exécutant quelques requêtes SQL optimisées.
* **Sobriété Mémoire :** Le serveur Puma ne subit aucun pic d'allocation RAM, ce qui permet d'héberger l'application sur des serveurs de production à coût maîtrisé (Railway / Kamal).
* **Domaine Propre :** Nos entités métier restent épurées, sans méthodes d'assistance liées à la présentation.

### 🔴 Coûts consentis
* **Dualité de Code :** Les développeurs doivent naviguer entre deux concepts : `UseCases` pour modifier, `Queries` pour lire.
* **SQL Avancé :** Les développeurs doivent maîtriser Arel ou l'API de requêtage d'ActiveRecord pour formuler des jointures et agrégations performantes dans les modules `Queries::`.

---

## 5. Notes d'implémentation

Extrait de `Queries::ClassroomReportQuery` illustrant l'utilisation du SQL pour regrouper les sessions en base de données avant traitement léger en Ruby :
```ruby
# app/infrastructure/queries/classroom_report_query.rb
module Queries
  class ClassroomReportQuery
    def get_exercise_stats(classroom_id, exercise_id)
      classroom = Orm::Classroom.find(classroom_id)
      students = classroom.students.ordered
      student_ids = students.map(&:id)

      # 1. Requêtage et filtrage directement en SQL dans PostgreSQL
      sessions_by_student = Orm::ExerciseSession
        .where(student_id: student_ids, exercise_id: exercise_id)
        .completed
        .order(completed_at: :desc)
        .group_by(&:student_id) # OK ici car le périmètre est déjà restreint aux ID d'une seule classe et d'un seul exercice

      badges_by_student = Orm::ExerciseBadge
        .where(student_id: student_ids, exercise_id: exercise_id)
        .index_by(&:student_id)

      # 2. Construction d'un Hash de résultats légers prémâchés pour la Vue
      results = students.map do |student|
        sessions = sessions_by_student[student.id] || []
        {
          student: student,
          sessions: sessions,
          best_score: sessions.map(&:percentage).max,
          attempts: sessions.size,
          badge: badges_by_student[student.id]
        }
      end

      { students: students, results: results }
    end
  end
end
```

Exemple d'agrégation SQL 100% native utilisée pour le Dashboard Admin (`TeamsDashboardQuery`) :
```ruby
# Agrégation SQL directe sans charger d'objets en mémoire
def get_students_per_level
  Orm::Student.joins(classroom_students: :classroom)
              .where(classroom_students: { primary: true })
              .group("classrooms.level_id")
              .count
end
```

---

## 6. Mise à jour (Juillet 2026)
Suite à une revue d'architecture, la séparation CQRS a été renforcée : le Use Case `GetClassroomDetails` passe désormais par un `ClassroomDashboardQuery` dédié, et le `ClassroomRepository` a été nettoyé de toutes ses méthodes de requêtes agrégées (stats, etc.).
