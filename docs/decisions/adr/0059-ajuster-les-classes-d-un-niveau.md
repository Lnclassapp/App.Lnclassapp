# ADR-0059 : Ajuster les classes d'un niveau — la suivante au nom du barème, la dernière supprimée seulement si elle n'a jamais servi
<!-- index
titre: Ajuster les classes d'un niveau : la suivante au nom du barème, la dernière supprimée seulement si elle n'a jamais servi
statut: Accepté *(2026-09-28)*
problematique: « + » nomme la classe suivante (plus grand numéro + 1), mêmes règles qu'« Ajouter une classe » ; « − » supprime la dernière du couple niveau/série, sous verrou, si aucune adhésion, aucun enseignant ni assignation, sinon `:conflict`. Audit `school.changed`. Numéro = plus haut + 3 (chantiers parallèles). Précise ADR-0036 et ADR-0041.
-->

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-28, défauts compris)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/classes-par-niveau`](../../chantiers/classes-par-niveau/prd.md) |
| **Remplace** | — (précise [ADR-0036](./0036-suppression-archivage-et-anonymisation.md) et [ADR-0041](./0041-vie-d-une-classe-annee-scolaire-et-code.md), voir §8) |
| **Remplacé par** | — |

> Numéro : le plus haut ADR existant sur `Develop` au 2026-09-28 (0056) **+ 3**, pour éviter les collisions avec les chantiers menés en parallèle.

---

## 1. Contexte et problématique

Le barème (`DefaultClassroomPlan`, ADR-0030, ADR-0056) donne un nombre moyen de classes par niveau et par série. L'équipe doit l'ajuster établissement par établissement : ajouter une sixième, retirer une terminale A2 générée en trop. « Ajouter une classe » (UDR-0031) demande de saisir un nom ; **aucun** geste ne retire une classe. L'ADR-0036 range la classe parmi les données qu'on **archive** et dit qu'elle n'est « jamais supprimée dès qu'un élève l'a rejointe ou qu'une assignation existe » ; il ne dit pas ce qu'on fait d'une classe qui n'a jamais servi. `DeleteSchool` supprime déjà physiquement les classes d'un établissement quand aucune n'a d'élève, d'enseignant ni d'assignation.

## 2. Moteurs de décision

1. Aucune action ne perd le travail d'un élève ni d'un enseignant (ADR-0036).
2. La fiche, le tableau des établissements et le bloc par niveau disent le même nombre.
3. Les noms restent ceux du barème, sans trou ni doublon.
4. Réutiliser les règles d'« Ajouter une classe » plutôt que les réécrire.
5. Aucune migration.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Retirer = archiver | Une seule règle pour toutes les classes | La classe archivée reste comptée (fiche, tableau), bloque son nom (index unique), et encombre la fiche ; archiver une classe vide ne protège rien |
| B — **Retirer = supprimer, seulement si la classe n'a jamais servi ; sinon refuser** | Rien de perdu ; compteurs justes sans filtre ; même règle que `DeleteSchool` | Deux sorts possibles pour une classe ; l'équipe doit comprendre le refus |
| C — Supprimer si vide, archiver sinon, d'un seul geste | Le geste réussit toujours | Archiver une classe utilisée en cours d'année coupe ses élèves de leurs cours : trop grave pour un « − » |

Option B retenue.

## 4. Décision

> **« + » crée la classe suivante du couple niveau/série, nommée comme au barème ; « − » supprime définitivement la dernière classe du couple si elle n'a jamais servi, et refuse sinon.**

- **Couple** : niveau et série (nulle pour un niveau sans série), dans l'établissement et l'année scolaire en cours (`SchoolYear.current`).
- **Nom** (`Entities::Classroom::ClassroomNumbering`) : préfixe du barème (`"#{niveau} #{série}"`, comme `DefaultClassroomPlan.rows_of`), suivi du plus grand numéro portant ce préfixe dans l'établissement et l'année, plus un. « Tle D 1, Tle D 3 » → « Tle D 4 ». Le nom ne peut pas être pris : tout nom de ce préfixe entre dans le maximum. Sous concurrence, l'index unique `(school_id, school_year, name)` refuse le second : `AddLevelClassroom` recalcule une fois.
- **Ajout** (`UseCases::Classroom::AddLevelClassroom`) : `ManageClassroomPolicy` ; établissement actif seulement (`school_inactive`, `school_draft`) ; niveau et série contrôlés par `Entities::Classroom::Placement`, extrait de `CreateClassroom`, qui l'utilise aussi (collège = premier cycle, couple ouvert, série exigée si le niveau en a) ; plafond 80 ; code tiré par `ClassroomRepositoryPort#create` (ADR-0041).
- **Dernière classe** : plus grand numéro final, puis nom (l'ordre de la fiche, `SchoolDetailQuery`). La requête porte l'identifiant de la classe que la confirmation a nommée ; si ce n'est plus la dernière du couple (`names_in_level`), `:conflict` `not_last`.
- **Retrait** (`UseCases::Classroom::RemoveLevelClassroom`) : `ManageClassroomPolicy` ; tout statut d'établissement (retirer une classe vide ne touche personne) ; classe de l'établissement et de l'année en cours, sinon `:not_found`. `ClassroomRepositoryPort#delete_if_unused(id:)`, dans la transaction du use case : verrou de ligne (`SELECT … FOR UPDATE`, le même que prend `JoinWithCode`), puis refus `:conflict` si la classe a une adhésion, même terminée (`has_students`), un enseignant déclaré (`has_teachers`) ou une assignation, même archivée (`has_assignments` — les sessions d'exercice en dépendent) ; sinon `DELETE`. Les clés étrangères `on_delete: :restrict` refuseraient de toute façon.
- **Audit** : `school.changed`, sujet l'établissement (la classe retirée n'a plus de ligne), `metadata: { change: "classroom_added" | "classroom_removed", classroom_public_id:, name: }`. Aucune action nouvelle dans `AuditAction::ALL`.
- **Ports** (`ClassroomRepositoryPort`) : `names_in_level(school_id:, school_year:, level_id:, series_id:) → [String]` ; `delete_if_unused(id:) → Result | failure(:conflict, errors: { base: [:has_students | :has_teachers | :has_assignments] }) | failure(:not_found)`.

## 5. Conséquences

### 🟢 Positives

- L'équipe ajuste un établissement en quelques clics, sans saisir de nom.
- Une classe générée en trop disparaît vraiment : fiche, tableau et bloc restent d'accord sans filtre sur le statut.
- Aucune classe qui a servi n'est touchée ; la base le garantit aussi (`on_delete: :restrict`).

### 🔴 Coûts consentis

- Une classe a désormais deux fins possibles (suppression si jamais servie, archivage de fin d'année) : à connaître.
- Le refus conseille d'archiver, mais l'archivage d'une seule classe n'existe pas encore (seul l'archivage de l'année est prévu, ADR-0041) : l'équipe n'a pas d'issue immédiate pour une classe utilisée en trop.
- Une classe au milieu de la numérotation ne se retire pas : l'équipe qui veut retirer « 6ème 2 » vide devra attendre un autre geste.
- Le journal ne garde que le nom et l'identifiant public d'une classe supprimée.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/classroom/classroom_numbering.rb
def self.next_name(prefix:, taken:)
  pattern = /\A#{Regexp.escape(prefix)} (\d+)\z/
  "#{prefix} #{taken.filter_map { pattern.match(it)&.[](1)&.to_i }.max.to_i + 1}"
end
```

```ruby
# app/infrastructure/repositories/classroom/classroom_repository.rb
def delete_if_unused(id:)
  return ::Shared::Result.failure(:not_found) unless Orm::Classroom.lock.exists?(id:)
  ...
end
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/classroom/remove_level_classroom_test.rb` : refus `has_students`, `not_last`, rien de supprimé ni tracé.
- `test/infrastructure/repositories/classroom/classroom_repository_test.rb` : `delete_if_unused` refuse une adhésion terminée, un enseignant, une assignation archivée.
- `test/system/school/classrooms_by_level_test.rb` : « + » donne « 6ème 5 », « − » la retire, « − » sur une classe avec un élève est refusé.

## 8. Remplace, complète, amende

- **Précise** l'ADR-0036 : une classe qui n'a **jamais** eu d'adhésion, d'enseignant ni d'assignation peut être supprimée physiquement ; dès qu'elle a servi, elle ne l'est jamais.
- **Précise** l'ADR-0041 : la classe ajoutée en cours d'année suit la numérotation du barème.

## 9. Points à confirmer par le porteur

- Suppression physique (et non archivage) d'une classe jamais utilisée.
- « − » permis sur un établissement désactivé ou en brouillon ; « + » réservé aux établissements actifs.
- Jamais d'autre classe que la dernière du couple.
- Audit sous `school.changed` plutôt qu'une action `classroom.*` nouvelle.
