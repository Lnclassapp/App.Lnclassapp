# PRD — Supprimer une leçon qui n'a jamais servi à un élève

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'équipe ne peut qu'archiver une leçon, et l'import refuse une leçon déjà présente qui n'est plus entièrement en brouillon (ADR-0116 §4.4). Une leçon à refaire reste donc bloquée. On permet de la supprimer définitivement, depuis sa page, tant qu'aucun élève ne s'en est servi ; elle peut ensuite être réimportée.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team (rôles qui gèrent le contenu) | Ouvrir la confirmation et supprimer une leçon sans activité d'élève, quel que soit son statut | Supprimer une leçon qui a de l'activité d'élève |
| Teacher, SchoolStaff, Student, Parent | — | Voir l'entrée « Supprimer », ouvrir la confirmation, supprimer |

Règle d'autorisation : `Policies::Catalog::ManageContentPolicy` (les contrôleurs `Teams::*` exigent en plus un compte équipe).

## 3. Parcours utilisateur

### Chemin nominal

1. Sur la page d'une leçon, l'équipe ouvre le menu ⋮ et choisit « Supprimer », sous « Archiver ».
2. Une modale demande « Supprimer la leçon « <nom> » ? » et dit que la leçon, ses notions, exercices, sujets et images seront supprimés définitivement, et qu'on pourra la réimporter.
3. L'équipe confirme « Supprimer définitivement ».
4. Elle arrive au catalogue avec le message « Leçon « <nom> » supprimée. Vous pouvez la réimporter depuis Imports. »
5. L'import du même fichier crée de nouveau la leçon.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| La leçon a de l'activité d'élève à l'ouverture de la modale | La modale s'intitule « Cette leçon ne peut pas être supprimée », explique que des élèves s'en sont servis et propose « Modifier la leçon » (ouvre la modification) et « Fermer ». Aucun bouton « Supprimer ». |
| Une activité apparaît entre l'ouverture et la confirmation | La suppression est refusée (422) ; la modale passe à l'état de refus ci-dessus ; rien n'est supprimé. |
| La leçon n'existe plus (double clic, autre onglet) | Page introuvable (404). |
| Compte non équipe | 403/404 comme le reste de l'espace équipe ; rien n'est supprimé. |
| Un élève commence un exercice de la leçon pendant la suppression | Soit la suppression voit sa séance et refuse, soit la séance attend la fin et échoue ; jamais de séance orpheline. |
| Un enseignant envoie un exercice de la leçon pendant la suppression | Idem : le devoir attend la fin et est refusé, ou la suppression le voit et refuse. |

## 4. Critères d'acceptation

```gherkin
CA-01
Étant donné un acteur qui n'est pas de l'équipe
Quand il demande la suppression d'une leçon
Alors la demande est refusée (forbidden) et la leçon existe toujours

CA-02 (un scénario par source)
Étant donné une leçon dont un exercice a une séance d'élève | une réponse d'élève | un badge
  | dont une notion a été lue | dont une notion porte une lacune | dont un exercice a été livré en pack hors ligne
  | dont un exercice a été envoyé à une classe (devoir actif ou archivé)
Quand l'équipe demande sa suppression
Alors la suppression est refusée (conflict, student_activity)
Et la leçon, son contenu et la trace de l'élève existent toujours

CA-03
Étant donné une leçon publiée sans activité, avec texte de cours, notions, exercices de notion, problèmes, sujets, questions, réponses et image
Quand l'équipe la supprime
Alors la leçon et tout ce contenu n'existent plus, l'image est détruite
Et une leçon voisine n'a rien perdu
Et le journal d'audit porte « content.deleted » avec le nom et le slug de la leçon

CA-04
Étant donné une leçon brouillon ou archivée sans activité
Quand l'équipe la supprime
Alors elle est supprimée

CA-05
Étant donné une leçon publiée supprimée
Quand l'équipe importe de nouveau le même fichier
Alors la leçon est créée (aucune erreur « leçon déjà publiée »)

CA-06
Étant donné une leçon sans activité
Quand l'équipe ouvre « Supprimer » dans le menu ⋮
Alors la modale nomme la leçon, dit que c'est définitif et propose « Supprimer définitivement »
Et la confirmation renvoie au catalogue avec « Leçon « <nom> » supprimée »

CA-07
Étant donné une leçon avec activité
Quand l'équipe ouvre « Supprimer »
Alors la modale dit qu'elle ne peut pas être supprimée et propose « Modifier la leçon »
Et une confirmation envoyée quand même est refusée en 422 avec ce même message

CA-08
Étant donné un exercice dont la leçon vient d'être supprimée
Quand un enseignant tente de l'envoyer à une classe
Alors l'envoi est refusé et aucun devoir orphelin n'est écrit
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | use case `UseCases::Catalog::DeleteCourse` ; port `CourseRepositoryPort` + `student_activity`, `lock_for_deletion`, `delete` ; action d'audit `content.deleted` |
| Infrastructure | `CourseRepository` (lecture de l'activité, verrous, suppression) (purge du seul contenu) ; `AssignmentRepository#create` verrouille l'exercice |
| Delivery | `Teams::CoursesController#deletion` (GET, modale) et `#destroy` (DELETE) ; routes `teams/courses/:slug/deletion`, `DELETE teams/courses/:slug` |
| UI | entrée « Supprimer » du menu ⋮ (`catalog/courses/_role_actions`), modale `teams/courses/deletion` et son partiel `_deletion_dialog` (rendu aussi par le refus en Turbo Stream) |

## 6. Décisions rattachées

- ADR-0136 — amende ADR-0036 §4 (ligne « Cours… ») et ADR-0035.
- UDR-0172 — l'entrée du menu, la modale de confirmation et son état de refus.

## 7. Mesures

Sans objet.
