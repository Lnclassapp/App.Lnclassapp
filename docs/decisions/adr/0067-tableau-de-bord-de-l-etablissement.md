# ADR-0067 : Le tableau de bord de l'établissement se lit en direct, par classe, sans aucune note d'élève nommé

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/espace-direction`](../../chantiers/espace-direction/prd.md) — critères ED-27 à ED-32 (SC-15, SC-18, TR-15) |
| **Complète** | [ADR-0062](./0062-indicateurs-de-pilotage-lus-en-direct.md) (définitions et forme de lecture) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Dans l'ancienne application, le tableau de bord de l'établissement (SC-15) affichait un fil d'actualité vide codé en dur, et celui d'une classe côté direction (SC-18) laissait fuiter les données d'un autre établissement, avec des statistiques vides. Le grill 9 a été délégué ; la décision prise est : **des chiffres par classe, sans note par élève**. En tête, le nombre de classes, d'enseignants et d'élèves ; puis, pour chaque classe, l'effectif, les devoirs donnés, le taux de rendu et la moyenne de la classe.

L'ADR-0062 a posé la méthode pour l'équipe : chaque chiffre a une définition d'une phrase, testée, et se lit en direct par une query au nombre de requêtes fixe. Sans définitions écrites, « élève », « devoir » ou « rendu » voudront dire deux choses sur deux écrans.

Les données sont celles de mineurs : la direction ne doit jamais lire la note d'un élève nommé (memo, grill 9).

## 2. Moteurs de décision

1. Des chiffres **justes et explicables**, sur les définitions de l'ADR-0062 quand elles existent.
2. **Aucune note nominative** : seuls des agrégats par classe quittent l'infrastructure.
3. Un coût de lecture **borné** et indépendant du nombre de classes.
4. Aucune table, aucun cache, aucun job.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Liste des élèves avec leur dernière note (comme la page classe de l'enseignant, UDR-0027) | La direction « voit ses élèves » | Refusée par le grill 9 : la direction ne voit pas la note d'un élève nommé |
| B — Agrégats précalculés par un job | Lecture instantanée | Une table, un job, des chiffres en retard ; écarté par l'ADR-0062 aux volumes actuels |
| C — **Lecture en direct, requêtes groupées par classe** | Chiffres exacts, aucune table ; même forme que le pilotage | Retenue — voir coûts |

## 4. Décision

> **Nous lisons le tableau de bord de l'établissement en direct, par `Queries::School::SchoolDashboardQuery`, sur les définitions ci-dessous, en un nombre de requêtes fixe ; il ne renvoie que des agrégats, jamais une ligne par élève.**

**Périmètre** : l'établissement de l'acteur (ADR-0066), l'année scolaire en cours (`Entities::Classroom::SchoolYear.current`, ADR-0041).

| Chiffre | Définition |
|---|---|
| Classe | Classe `active` de l'année scolaire en cours de l'établissement (ADR-0062) |
| Enseignant de l'établissement | Compte enseignant non anonymisé dont l'établissement **principal** est celui-ci (`teacher_schools.primary`, ADR-0030) |
| Élève de l'établissement | Élève placé (ADR-0062) : non anonymisé, adhésion principale non quittée, dans une classe de l'établissement |
| Effectif d'une classe | Élèves non anonymisés dont l'adhésion à la classe n'est pas quittée (`left_at IS NULL`) ; affiché avec le plafond (« 34 / 80 ») |
| Devoirs donnés | Lignes `classroom_assignments` de la classe, tous statuts (un devoir retiré a été donné) |
| Taux de rendu | Parmi l'effectif, part des élèves qui ont **terminé** au moins une session d'exercice `standard` rattachée à un devoir de la classe ; arrondi à l'unité ; « — » si l'effectif est nul ou si la classe n'a aucun devoir |
| Moyenne de la classe | Moyenne arrondie des `score_percent` des sessions `completed`, `kind = 'standard'`, rattachées à un devoir de la classe, **quel que soit l'élève** (un élève parti garde ses résultats, ADR-0036) ; « — » si **moins de 5 élèves distincts** ont une telle session (`MIN_STUDENTS_FOR_AVERAGE = 5`) : croisée avec la liste des élèves de la classe, la moyenne d'un ou deux élèves serait une note nominative |

- Les sessions de remédiation (`kind = 'remediation'`, ADR-0043) ne comptent ni dans le rendu ni dans la moyenne : elles ne sont pas des devoirs.
- Le tableau liste **toutes** les classes de l'année, triées par niveau (`levels.position`) puis par nom, sans pagination (77 au plus pour un lycée public, ADR-0030).
- Le seuil de 5 élèves est une règle de minimisation, pas une préférence d'affichage : il tient le moteur 2 même quand deux pages se croisent (moyenne de la classe × liste de ses élèves).
- La même query sert la page d'une classe (`#classroom(public_id:)`) avec les mêmes définitions, plus la liste des **noms** de ses enseignants.

**Nombre de requêtes** : fixe, quel que soit le nombre de classes, d'élèves et de sessions — une lecture des compteurs d'en-tête (sous-requêtes scalaires), une des classes avec leur effectif, une des devoirs groupés par classe, une du rendu et de la moyenne groupés par classe. Un test le vérifie en triplant le volume.

**Autorisation** : `StaffPolicy` geste `:read` (toute la direction) ; aucun use case, ce sont des lectures (ADR-0006, ADR-0062).

## 5. Conséquences

### 🟢 Positives

- La direction voit où ses classes en sont, sans jamais lire la note d'un élève nommé.
- Les définitions « classe » et « élève placé » sont celles du pilotage de l'équipe : les deux écrans disent le même nombre.
- Aucune table ni job ; un chiffre juste juste après un devoir donné.

### 🔴 Coûts consentis

- **Le taux de rendu est grossier** : un élève qui a terminé un seul exercice d'un seul devoir compte comme « rendu ». Un taux par devoir (élève × devoir) demanderait de déplier les cours et les fiches assignés en exercices ; il attend `rapports-de-classe` (V3).
- **Une petite classe n'a pas de moyenne** : sous 5 élèves ayant rendu, « — », même si la direction voudrait le chiffre.
- **La moyenne mélange** élèves partis et présents, et tous les devoirs de l'année : elle dit le niveau de travail de la classe, pas celui de l'effectif actuel.
- **Le coût croît avec les sessions** : les agrégats parcourent `exercise_sessions` par `classroom_assignment_id` (indexé) ; au-delà de 300 ms en production, un chantier d'optimisation ajoute un index composite `(classroom_assignment_id, status, kind)`, comme l'ADR-0062 le prévoit pour le pilotage.
- **Pas d'historique ni de période** : l'année scolaire en cours seulement.

## 6. Notes d'implémentation

```ruby
# app/infrastructure/queries/school/school_dashboard_query.rb
# 🔌 INFRA · Queries::School::SchoolDashboardQuery
# Rôle : tableau de bord de l'établissement : compteurs d'en-tête et chiffres par classe, sans aucune note d'élève nommé
# ADR  : 0062, 0066, 0067 · UDR : 0052
module Queries
  module School
    class SchoolDashboardQuery
      Dashboard = Data.define(:classrooms_count, :teachers_count, :students_count, :classrooms)
      # submission_rate, average_percent : nil → « — »
      ClassroomRow = Data.define(:public_id, :name, :level_name, :headcount, :max_students, :assignments_count,
                                 :submission_rate, :average_percent)

      def call(school_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        # … quatre lectures groupées, aucune par classe
      end
    end
  end
end
```

Le taux de rendu, en une lecture groupée :

```sql
SELECT a.classroom_id, COUNT(DISTINCT s.student_id) AS submitters, AVG(s.score_percent) AS average
FROM exercise_sessions s
JOIN classroom_assignments a ON a.id = s.classroom_assignment_id
WHERE a.classroom_id IN (:ids) AND s.status = 'completed' AND s.kind = 'standard'
GROUP BY a.classroom_id
```

`submitters` ne compte que les élèves de l'effectif (jointure sur `classroom_students` ouvertes de la classe) ; `average` porte sur toutes les sessions — deux expressions `FILTER` dans la même lecture.

## 7. Comment vérifier que la décision est respectée

- `test/infrastructure/queries/school/school_dashboard_query_test.rb` : un test par ligne du tableau §4 ; classe sans devoir → « — » ; moins de 5 élèves ayant rendu → moyenne « — » ; élève parti compté dans la moyenne, pas dans l'effectif ni le rendu ; session de remédiation ignorée ; élève anonymisé exclu ; classe archivée ou d'une autre année exclue ; **données d'un autre établissement absentes** ; nombre de requêtes identique quand le volume triple.
- `test/views/school_admin/homes_view_test.rb` (ou le test système) : aucun `score_percent` ni nom d'élève dans le HTML du tableau de bord et de la page classe.
