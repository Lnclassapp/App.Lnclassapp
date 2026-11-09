# ADR-0125 : La direction lit, sans agir, la leçon d'une classe de son établissement
<!-- index
titre: Lecture de la leçon en classe par la direction
statut: Accepté
problematique: Qui peut lire les lacunes nominatives et la réussite par exercice d'une classe, et la direction peut-elle agir sur la classe ?
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-05 |
| **Chantier** | `docs/chantiers/suivi-classe-lecon` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le chantier `suivi-classe-lecon` (#340) remet, sur la leçon vue depuis une classe, les élèves à revoir et ceux qui ont levé leur lacune (des noms), et la réussite de la classe par exercice. Ces pages sont aujourd'hui ouvertes à l'enseignant de la classe et à l'équipe (`ReadClassroomPolicy`). Le porteur veut que la direction de l'établissement les voie aussi (grill du 2026-11-05). La direction voit déjà la liste des élèves d'une classe de son établissement (`ManageClassroomMembersPolicy`), mais aucune donnée de résultats nominative par leçon.

## 2. Moteurs de décision

- Données nominatives d'élèves mineurs : un accès hors périmètre est une fuite.
- Une direction d'un autre établissement ne doit pas pouvoir constater qu'une classe existe (règle déjà suivie : 404, pas 403).
- La direction pilote, elle n'enseigne pas : assigner un devoir ou fixer les jours de séance reste à l'enseignant (et à l'équipe).
- Ne pas élargir `ReadClassroomPolicy`, utilisée par d'autres écrans (page de la classe de l'enseignant, frames).

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A. Étendre `ReadClassroomPolicy` à la direction | Une seule règle | Ouvre d'un coup tous les écrans qui l'utilisent, dont des actions |
| B. Nouvelle policy de lecture de la leçon en classe, avec `can_assign` | Périmètre exact : deux pages, lecture seule pour la direction | Une policy de plus |
| C. Écran dédié dans l'espace direction | Séparation nette | Duplique la leçon en classe et ses deux queries |

## 4. Décision

**Option B.** `Policies::Classroom::ReadClassroomLessonPolicy#call(actor:, classroom:)` rend :

- succès `Access(can_assign: true)` pour l'équipe et pour l'enseignant de la classe (`ClassroomTeacher.teaches?`) ;
- succès `Access(can_assign: false)` pour un `school_admin` dont `school_id` égale celui de la classe ;
- échec `:not_found` pour un `school_admin` d'un autre établissement ;
- pour tout autre acteur, le résultat actuel de `ReadClassroomPolicy` (enseignant ailleurs : refus inchangé ; élève : pas de détail).

Elle garde uniquement `Classroom::ClassroomCoursesController#show` et `Classroom::ClassroomPrepareSheetsController#show`, ouverts au rôle `school_admin`. Les actions (assigner, jours de séance) gardent leurs policies actuelles (`AssignPolicy`, `SetSessionDaysPolicy`), qui refusent la direction. La vue n'affiche la barre d'assignation que si `can_assign`.

## 5. Conséquences

### 🟢 Positives

- La direction lit ce qui l'aide à piloter, sans pouvoir agir à la place de l'enseignant.
- Les autres écrans de classe ne changent pas de droits.

### 🔴 Coûts consentis

- Une policy de plus à maintenir, dont la règle « même établissement » double celle de `ManageClassroomMembersPolicy`.
- Une direction voit les noms des élèves à revoir de toutes les classes de son établissement : accepté par le porteur ; à rappeler dans la charte de l'établissement.

## 6. Notes d'implémentation

```ruby
# app/domain/policies/classroom/read_classroom_lesson_policy.rb — Ruby pur
Access = Data.define(:can_assign)
```

Le contrôleur passe `access.can_assign` à la vue ; la vue ne relit jamais le rôle.

## 7. Comment vérifier que la décision est respectée

- `test/domain/policies/classroom/read_classroom_lesson_policy_test.rb` : équipe, enseignant, direction du même établissement, direction d'un autre (`:not_found`), élève, enseignant d'une autre classe, acteur nil.
- Tests d'intégration des deux contrôleurs : direction du même établissement 200 sans « Assigner » ; autre établissement 404 ; `POST` d'assignation par la direction refusé.
- Revue `security-reviewer` sur le diff du lot qui l'introduit.
