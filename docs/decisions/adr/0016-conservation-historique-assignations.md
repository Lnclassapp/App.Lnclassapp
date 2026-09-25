# ADR-0016 : Conservation de l'Historique via Soft Delete (Archivage) pour les Assignations Polymorphes

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-08 *(jour non documenté)* |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique
Les enseignants ont besoin de pouvoir assigner et retirer facilement des ressources pédagogiques (Cours, Essentiels) à leurs classes via une interface fluide de type "Toggle".
Initialement, le retrait (`RemoveResourceFromClassroom`) procédait à une suppression définitive (Hard Delete) de l'enregistrement de liaison en base de données (`classroom_courses`).
Toutefois, cette suppression brisait la traçabilité. Un élève ayant commencé un cours ou réalisé des exercices liés risquait de voir son historique rendu incohérent ou orphelin (selon la politique des clés étrangères).

De plus, lors d'un remplacement de professeur en cours d'année, il s'est avéré nécessaire de distinguer :
1. L'appartenance du contenu (Le cours appartient de manière collaborative à la classe pour une matière donnée).
2. L'empreinte de l'activité (Les exercices et devoirs appartiennent au professeur actif à cet instant).

## 2. Décision
- **Cycle de Vie via Statut (Soft Delete)** : Plutôt que de détruire l'enregistrement (`.destroy`), l'action de retrait met à jour un champ `status` à la valeur `"archived"`. L'assignation passe au statut "archived", la rendant inactive pour le futur sans la détruire.
- **Réactivation** : Si une ressource est de nouveau assignée, l'enregistrement "archived" est réactivé (passage au statut `"added"`).
- **Séparation Contenu/Activité** : Les assignations de cours n'intègrent pas de notion de `teacher_id`. Le contenu appartient à la classe. En revanche, ce sont les `ExerciseSession` (les devoirs) qui traceront le `teacher_id`, permettant à un professeur remplacé de conserver ses droits de lecture sur son activité passée, tandis que le nouveau professeur gère l'avenir.

## 3. Conséquences
- **Avantages** :
  - **Historique préservé** : Zéro perte de données pour l'analyse statistique ou la consultation par les anciens professeurs.
  - **Fluidité des Remplacements** : Un nouveau professeur hérite instantanément des cours de sa matière déjà assignés à la classe, sans migration de base de données.
- **Impacts / Contraintes** :
  - **Développement UI** : Les requêtes (Repositories et Vues) doivent explicitement filtrer ou vérifier que le statut `!= "archived"` pour afficher un cours comme actif.
  - **Taille de la base** : Croissance très légèrement supérieure de la base, mais négligeable comparé au gain métier.
