# PRD — Suivi de la classe sur une leçon : lacunes, réussite par exercice, remédiation

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Issue #340. La refonte de la page de la leçon (#337) a supprimé les pages de notion, et avec elles trois fonctions : le détail « à revoir / levée » d'une notion pour l'enseignant, la réussite de la classe par exercice, et l'exercice de remédiation proposé à l'élève. Elle a aussi laissé de la dette : code sans appelant, une route d'envoi d'images de question sans formulaire, les jours de séance qu'on ne peut plus modifier, l'équipe qui ne peut plus assigner depuis la leçon. Le porteur a choisi de tout traiter ici (grill du 2026-11-05, `memo.md`).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Enseignant de la classe | Voir, sous chaque notion de la leçon vue depuis la classe, les élèves à revoir et ceux qui ont levé leur lacune cette année ; voir la réussite de la classe sous chaque exercice d'une feuille vue depuis la classe ; modifier ses jours de séance depuis la page de la classe | Voir ces données pour une classe qu'il n'enseigne pas (refus actuel inchangé) |
| Équipe Lnclass | Tout ce que voit l'enseignant, pour toute classe ; assigner un exercice à la classe depuis une feuille vue depuis cette classe | — |
| Direction (`school_admin`) | Voir, en lecture seule, la leçon vue depuis une classe **de son établissement** : détail « à revoir / levée » et réussite par exercice ; le bloc « Fiches à revoir » sur sa page de la classe | Assigner, modifier les jours ; voir une classe d'un autre établissement (404) |
| Élève | Se voir proposer un exercice de remédiation pour chaque lacune en attente, à trois endroits | Voir les lacunes ou la réussite des autres élèves |
| Parent | — (hors périmètre) | Tout ce qui précède |

## 3. Parcours utilisateur

### Chemin nominal

1. **Enseignant.** Sur la page de sa classe, « Fiches à revoir » montre « Thalès : 3 élèves ». Il touche la ligne : la leçon s'ouvre dans la classe, à la notion. Sous la fiche de la notion, un encadré « Dans votre classe » liste « À revoir (3) » avec, pour chacun, le nom, la date d'ouverture et le nombre de copies ratées, puis « Lacune levée (5) » avec la date de levée.
2. **Enseignant.** Il ouvre la feuille « Prépare interros » d'une notion dans la classe. Sous chaque exercice, à côté de « Assigner à 3e 2 », il lit « 12 / 20 élèves ont réussi ».
3. **Élève.** Il rate un exercice de Thalès (moins de 10/20) : une lacune s'ouvre. La page de résultat affiche « Refais un exercice sur cette notion » qui ouvre l'exercice proposé dans sa feuille. Dans « Ma classe », la ligne « Thalès » de « Fiches à revoir » mène au même exercice. Sur la page de la leçon, la notion Thalès porte « À revoir : fais cet exercice », vers le même exercice.
4. **Élève.** Il réussit l'exercice proposé : la lacune est levée (règle actuelle) ; les trois propositions disparaissent ; l'enseignant le voit passer dans « Lacune levée ».
5. **Direction.** Sur sa page d'une classe de son établissement, elle voit « Fiches à revoir » et ouvre la leçon dans la classe en lecture seule (encadrés et taux, sans « Assigner »).
6. **Enseignant.** Sur la page de sa classe, le bloc « Jours de séance » est de retour ; « Modifier les jours » ouvre la fenêtre des jours.
7. **Équipe.** Elle ouvre une feuille d'une leçon depuis une classe et voit « Assigner à <cette classe> » sous chaque exercice, comme l'enseignant.

### Chemins alternatifs et erreurs

- Notion sans lacune dans la classe : pas d'encadré « Dans votre classe » (rien d'affiché, pas de bloc vide).
- Notion avec lacunes en attente mais aucune levée : « À revoir » seul, et inversement.
- Exercice sans aucune copie terminée dans la classe : « Pas encore fait par la classe ».
- Lacune sur une notion qui n'a plus d'exercice publié : aucune proposition ; la ligne de « Fiches à revoir » mène à la notion de la leçon.
- Seul exercice publié de la notion = celui raté : il est reproposé.
- Direction d'un autre établissement, ou enseignant d'une autre classe : 404 (ou refus actuel inchangé pour l'enseignant).
- Élève, ou acteur non connecté : aucun encadré enseignant, aucun taux.
- Classe archivée : 404, inchangé.

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Suivi de la classe sur une leçon

  Scénario: CA-1 l'enseignant voit qui est à revoir et qui a levé sa lacune
    Étant donné une classe de 3e avec Awa (lacune en attente sur « Thalès ») et Koffi (lacune levée sur « Thalès » cette année)
    Quand l'enseignant de la classe ouvre la leçon depuis la classe
    Alors sous la notion « Thalès » il lit « À revoir (1) » avec Awa
    Et il lit « Lacune levée (1) » avec Koffi

  Scénario: CA-2 une lacune levée l'an dernier n'apparaît pas
    Étant donné Koffi a levé sa lacune « Thalès » pendant l'année scolaire précédente
    Quand l'enseignant ouvre la leçon depuis la classe
    Alors Koffi n'apparaît pas sous « Lacune levée »

  Scénario: CA-3 un élève parti de la classe n'apparaît pas
    Étant donné Awa a quitté la classe avec une lacune en attente
    Quand l'enseignant ouvre la leçon depuis la classe
    Alors Awa n'apparaît dans aucune liste

  Scénario: CA-4 aucun encadré sans lacune
    Étant donné aucune lacune sur « Thalès » dans la classe
    Quand l'enseignant ouvre la leçon depuis la classe
    Alors la notion « Thalès » n'a pas d'encadré « Dans votre classe »

  Scénario: CA-5 la réussite de la classe compte la meilleure copie de chaque élève
    Étant donné une classe de 3 élèves et un exercice de la feuille « Thalès »
    Et Awa a 8/20 puis 14/20, Koffi a 6/20, Ama n'a pas fait l'exercice
    Quand l'enseignant ouvre la feuille depuis la classe
    Alors sous l'exercice il lit « 1 / 3 élèves ont réussi »

  Scénario: CA-6 exercice jamais fait
    Étant donné aucun élève de la classe n'a terminé l'exercice
    Quand l'enseignant ouvre la feuille depuis la classe
    Alors sous l'exercice il lit « Pas encore fait par la classe »

  Scénario: CA-7 la remédiation proposée est un autre exercice, de fixation d'abord
    Étant donné la notion « Thalès » a les exercices publiés E1 (évaluation), E2 (évaluation), E3 (fixation)
    Et Awa a raté E1, ce qui a ouvert une lacune
    Quand Awa ouvre « Ma classe »
    Alors la ligne « Thalès » de « Fiches à revoir » mène à E3 dans la feuille de la notion

  Scénario: CA-8 le même exercice est proposé aux trois endroits
    Étant donné Awa a une lacune en attente sur « Thalès » et E3 est l'exercice proposé
    Alors la page de résultat de la copie ratée propose E3
    Et la notion « Thalès » de la page de la leçon propose E3
    Et « Fiches à revoir » de « Ma classe » propose E3

  Scénario: CA-9 seul exercice de la notion
    Étant donné la notion n'a qu'un exercice publié, E1, raté par Awa
    Quand Awa ouvre « Ma classe »
    Alors la ligne « Thalès » mène à E1

  Scénario: CA-10 notion sans exercice publié
    Étant donné tous les exercices de la notion ont été retirés après l'ouverture de la lacune
    Quand Awa ouvre « Ma classe »
    Alors la ligne « Thalès » mène à la notion dans la page de la leçon

  Scénario: CA-11 lacune levée, plus de proposition
    Étant donné Awa réussit E3 et sa lacune est levée
    Quand Awa ouvre la page de la leçon
    Alors la notion « Thalès » ne propose plus d'exercice

  Scénario: CA-12 la direction lit la leçon d'une classe de son établissement
    Étant donné une direction du Lycée A et une classe du Lycée A
    Quand elle ouvre la leçon depuis la classe
    Alors elle voit l'encadré « Dans votre classe » et les taux de réussite
    Et elle ne voit aucun bouton « Assigner »

  Scénario: CA-13 la direction d'un autre établissement est refusée
    Étant donné une direction du Lycée B et une classe du Lycée A
    Quand elle ouvre la leçon ou une feuille depuis cette classe
    Alors la réponse est 404

  Scénario: CA-14 l'élève et l'enseignant d'une autre classe sont refusés
    Étant donné un élève de la classe, et un enseignant qui n'enseigne pas dans la classe
    Quand chacun ouvre la leçon depuis la classe
    Alors aucun ne voit l'encadré ni les taux

  Scénario: CA-15 modifier les jours de séance depuis la page de la classe
    Étant donné l'enseignant a renseigné lundi et jeudi
    Quand il ouvre la page de la classe
    Alors il lit « Vos jours de séance : lundi, jeudi »
    Et « Modifier les jours » ouvre la fenêtre des jours

  Scénario: CA-16 l'équipe assigne depuis une feuille vue dans la classe
    Étant donné un membre de l'équipe ouvre une feuille de la leçon depuis la classe « 3e 2 »
    Alors il voit « Assigner à 3e 2 » sous chaque exercice
    Et assigner crée le devoir pour cette classe

  Scénario: CA-17 la dette est retirée sans changer le comportement
    Étant donné le code sans appelant listé en §5
    Quand le lot de nettoyage est fusionné
    Alors la suite complète reste verte
    Et la route d'envoi d'images de question de l'équipe répond 404
```

## 5. Modélisation préliminaire

| Couche | Ce qui bouge |
|---|---|
| Domaine | `Entities::Assessment::RemediationPick` réutilisé tel quel ; nouvelle règle pure `Entities::Assessment::ClassSuccess` (meilleure copie par élève, seuil `Grading::PASS_THRESHOLD`) ; nouvelle policy `Policies::Classroom::ReadClassroomLessonPolicy` (enseignant de la classe, équipe, direction de l'établissement de la classe ; `Access` dit `can_assign`, faux pour la direction) ; `ReadClassroomPolicy` ne change pas |
| Infrastructure | `Queries::Assessment::ClassroomGapsQuery#detail` réutilisé (par notion, pour toutes les notions de la leçon en une requête : `details_for_course`) ; nouvelle query `Queries::Assessment::ClassExerciseSuccessQuery` (une requête pour tous les exercices d'une feuille) ; nouvelle query `Queries::Assessment::RemediationProposalsQuery` (lacunes en attente de l'élève → exercice proposé, via `RemediationPick`, une requête) |
| Delivery | `Classroom::ClassroomCoursesController` et `ClassroomPrepareSheetsController` ouverts au rôle `school_admin` ; `SchoolAdmin::ClassroomsController#show` charge « Fiches à revoir » ; `Catalog::CoursesController`, `Classroom::StudentClassroomsController`, `Assessment::SessionResultsController` chargent la proposition |
| UI | encadré « Dans votre classe » sous une notion ; taux sous un exercice (barre enseignant) ; « Refais un exercice sur cette notion » (résultat) ; « À revoir : fais cet exercice » (notion de la leçon) ; lien de « Fiches à revoir » (Ma classe) ; bloc « Jours de séance » rendu sur la page de la classe ; barre d'assignation pour l'équipe |
| Dette retirée | `UseCases::Assessment::CreateExercise`, `UpdateExercise` et leurs DTO, `ClassroomOverviewQuery#shown_course?`, route et `Teams::QuestionImagesController` (`config/routes/teams.rb`), leurs tests et locales |

Pas de migration, pas de nouvelle table, pas de nouveau port : tout se lit par des queries (CQRS) sur les tables existantes.

## 6. Décisions rattachées

- ADR-0125 — la direction lit la leçon d'une classe de son établissement (droit nouveau sur des données nominatives).
- UDR-0156 — les six surfaces modifiées.
- Réutilisées : ADR-0041, 0043, 0079, 0101 (lacunes) ; UDR-0121 (« Fiches à revoir »), UDR-0077 §3.4 (jours de séance), UDR-0149 (feuilles).

## 7. Mesures

| Mesure | Avant | Cible |
|---|---|---|
| Requêtes SQL ajoutées à la leçon en classe | — | ≤ 2 (lacunes de toutes les notions, réussite d'une feuille) |
| Requêtes ajoutées à « Ma classe » et à la page de la leçon (élève) | — | 1 |
| Lignes de code sans appelant listées dans #340 | > 0 | 0 |
