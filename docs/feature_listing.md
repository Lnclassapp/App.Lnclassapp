# Priority 1: Member User
User et les profil des users
Users: la table de base
team: le profil des membres de l'equipe Lnclass( je ne suis pas sure de mon choix pour les compte admins, Tech, Marketing, Dev, Drena Manager, Agents de terrain Lnclass etc)
teacher: le profil des enseignants
student: le profil des eleves

# Priority 2 Tables
Drena: la direction regionale de education national
Schools: Etablissements
series: les series des niveaux ( Ex: C, A, D)
Level: les niveaux des classes, Ex: 5e; 3e Tle
level_series: table de jointure des niveaux et series


classrooms: les classes
teacher_classrooms: jointure teacher et classrooms, pour l'ajout d'un enseignant a une classe
classroom_students jointure student et classrooms, pour l'ajout d'un eleve a une classe

materials: les matieres enseignées dans les classes
courses: les lecons ayant des essentiels/habilletés
essentials: les habilletés ayant des exercices
classroom_courses: jointure classes et cours, pour l'ajout d'un cous a une classe
classroom_essentials: jointure classes et essentials, pour l'ajout d'une habilleté a une classe

exercises:
questions:
answers:
classroom_exercises:

exercise_sessions:
question_attempts:
exercise_badges:


messages:
AddInstallBannerStatusToUsers
school_roles
school_staffs

knowledge_gaps:
classroom_assignments:


#la suite Solide
solid_cache_entries:
solid_cable_messages:
solid_queue_jobs:
solid_queue_blocked_executions:
solid_queue_claimed_executions:
solid_queue_failed_executions:
solid_queue_pauses::
solid_queue_processes:
solid_queue_ready_executions:
solid_queue_recurring_executions:
solid_queue_recurring_tasks:
solid_queue_scheduled_executions:
solid_queue_semaphores: