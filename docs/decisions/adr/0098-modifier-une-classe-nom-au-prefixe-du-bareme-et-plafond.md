# ADR-0098 : Modifier une classe — seul le suffixe du nom et le plafond changent, par la direction et l'équipe
<!-- index
titre: Modifier une classe : seul le suffixe du nom et le plafond changent, par la direction et l'équipe
statut: Proposé
problematique: CL-02. `UpdateClassroom` sous `ManageSchoolStructurePolicy` (équipe, direction de son établissement actif) ; préfixe du barème fixe, suffixe libre, 15 caractères ; plafond 1 à 150 et jamais sous l'effectif présent, jugé sous le verrou de la classe ; classe active de l'année en cours ; audit `school.changed` `classroom_updated`. Amende 0041, précise 0059.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/vie-de-la-classe`](../../chantiers/vie-de-la-classe/memo.md) |
| **Remplace** | — (amende [ADR-0041](./0041-vie-d-une-classe-annee-scolaire-et-code.md), précise [ADR-0059](./0059-ajuster-les-classes-d-un-niveau.md), voir §8) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Une classe naît de trois façons : la génération au barème (ADR-0056), le « + » d'un niveau (ADR-0059), « Ajouter une classe » de l'équipe (UDR-0031). Les deux premières la nomment « préfixe n » (« 6ème 3 », « Tle D 2 ») et lui donnent un plafond de 80 élèves (ADR-0041). Ensuite, rien ne la corrige : aucun use case, aucun port, aucun écran (CL-02, déplacée de la V1 en V3 le 2026-09-28).

Sur le terrain, les établissements nomment leurs classes autrement (« 6ème A », « 6ème Excellence ») et certains dépassent 80 élèves par classe. La feuille de route signalait le risque : « renommer une classe générée casse la numérotation de l'ADR-0059 ». La règle « plus grand numéro + 1 » ne regarde que les noms « préfixe n » ; ce qui la casserait, c'est un nom qui sort de son préfixe (« Tle C 3 » pour une Tle D) ou un doublon.

La direction a reçu « + », « − » (V2) puis l'archivage (ADR-0088), sous `ManageSchoolStructurePolicy`. La réponse Q3 du 2026-09-28 (« les classes restent à l'équipe ») a donc déjà été dépassée pour la structure.

## 2. Moteurs de décision

1. La cascade de l'élève (DRENA → établissement → niveau → classe, ADR-0085) reste vraie : une classe affichée sous « Tle D » s'appelle « Tle D … ».
2. La numérotation du barème reste sans doublon ni collision.
3. Le plafond ne ferme jamais une classe en silence, et l'adhésion concurrente ne le dépasse jamais.
4. Une seule policy pour tous les gestes de structure d'une classe.
5. Aucune migration.

## 3. Options envisagées

### Le nom

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Nom entièrement libre | Simple ; l'établissement nomme comme il veut | « Tle C 3 » sous le niveau Tle D trompe l'élève dans la cascade et fausse le « + » du niveau Tle C |
| B — **Préfixe du barème fixe, suffixe libre** | La cascade reste juste ; le « + » et le « − » gardent leur règle | Le « + » d'un établissement passé aux lettres propose « 6ème 1 » à côté de « 6ème A » |
| C — Nom non modifiable | Aucun risque | Ne répond pas à CL-02 |

### Le plafond sous l'effectif

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Accepter, la classe devient complète | Permet de fermer une classe aux arrivées | Fermer une classe aux arrivées n'est pas un geste voulu (ADR-0085 §4.1 : on l'archive) ; l'écran dirait « 42 / 40 » sans explication |
| B — **Refuser sous l'effectif présent** | Le plafond dit toujours une place restante ou zéro | Pour descendre, il faut retirer des élèves d'abord |

### Qui

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — L'équipe seule (`ManageClassroomPolicy`) | Q3 du 2026-09-28 | La direction a déjà « + », « − » et l'archivage, et c'est elle qui connaît les vrais noms |
| B — **Équipe et direction (`ManageSchoolStructurePolicy`)** | Une policy pour toute la structure | La direction reçoit un geste de plus |
| C — B plus l'enseignant de la classe | Il est sur le terrain | Il se déclare enseignant d'une classe sans validation (ADR-0085 §5) : il pourrait renommer et plafonner une classe qu'il ne tient pas |

## 4. Décision

> **Nous permettons à l'équipe, et à la direction sur son seul établissement actif, de modifier deux champs d'une classe active de l'année en cours : le suffixe de son nom, après le préfixe fixe du barème, et son plafond, entre 1 et 150 et jamais sous l'effectif présent. Le niveau, la série, l'année, le statut et le lien ne se modifient pas par ce geste.**

- **Use case** : `UseCases::Classroom::UpdateClassroom(actor:, school_public_id:, classroom_public_id:, dto:)`, construit comme `ArchiveClassroom` : établissement lu, policy `ManageSchoolStructurePolicy`, classe de l'établissement et de l'année en cours (`SchoolYear.current`) sinon `:not_found`, transaction, audit.
- **Nom** : préfixe = `ClassroomNumbering.prefix(level_name:, series_name:)`. Le formulaire n'envoie que le suffixe ; `ClassroomNumbering.full_name(prefix:, suffix:)` compose « préfixe suffixe » après `squish`. Suffixe vide → `:invalid` (`suffix: [:blank]`) ; nom complet de plus de `Classroom::NAME_MAX` (15) → `:invalid` (`suffix: [:too_long]`). Un nom dont le préfixe ne correspond pas n'est jamais construit.
- **Classe dont le nom actuel ne commence pas par son préfixe** (saisie libre de l'équipe avant ce chantier) : le formulaire préremplit le suffixe vide, l'enregistrement la ramène au préfixe. `ClassroomNumbering.suffix_of(name:, prefix:)` → le suffixe, ou `""`.
- **Plafond** : entier de 1 à `MAX_STUDENTS_LIMIT` (150) → sinon `:invalid` (`max_students`). Sous le verrou de ligne de la classe (le `SELECT … FOR UPDATE` que prennent `RegisterStudent` et `JoinAsStudent`), l'effectif présent (`left_at IS NULL`) est compté ; plafond inférieur → `:conflict` (`max_students: [:below_headcount]`, avec l'effectif).
- **Statut** : classe archivée → `:conflict` (`base: [:archived]`).
- **Unicité** : l'index `(school_id, school_year, name)` couvre les classes archivées ; sa violation → `:conflict` (`suffix: [:taken]`).
- **Rien de changé** : succès, sans écriture ni audit.
- **Port** : `ClassroomRepositoryPort#update_settings(id:, name:, max_students:) → Result(Classroom) | failure(:conflict, errors: { base: [:archived] } | { max_students: [:below_headcount], headcount: n } | { suffix: [:taken] }) | failure(:not_found)`.
- **Audit** : `school.changed`, sujet l'établissement, `metadata: { change: "classroom_updated", classroom_public_id:, name:, previous_name:, max_students:, previous_max_students: }`. Aucune action nouvelle dans `AuditAction::ALL`.
- **Numérotation** (ADR-0059 inchangé dans sa règle) : le « + » prend le plus grand numéro parmi les noms « préfixe n » de l'établissement et de l'année, plus un ; un suffixe non numérique n'y entre pas. Le « − » garde son ordre (numéro final, puis nom ; un nom sans numéro passe avant « 1 »).

## 5. Conséquences

### 🟢 Positives

- CL-02 est livrée sans migration, avec les règles et le verrou existants.
- La cascade de l'élève, le « + » et le « − » restent vrais après tout renommage.
- Un plafond affiché n'est jamais inférieur à l'effectif.
- Toute la structure d'une classe (ajouter, retirer, archiver, restaurer, modifier) relève d'une seule policy.

### 🔴 Coûts consentis

- Dans un établissement passé aux lettres, le « + » propose « 6ème 1 » à côté de « 6ème A » : il faut renommer la classe ajoutée.
- Un suffixe numérique choisi à la main (« 6ème 9 ») entre dans le maximum : le « + » suivant donnera « 6ème 10 ».
- Baisser le plafond d'une classe pleine demande de retirer des élèves d'abord.
- La direction reçoit un geste d'écriture que le PRD de `gestion-etablissement-direction` excluait.
- Un nom de classe saisi librement par l'équipe avant ce chantier est ramené au préfixe à sa première modification.
- Le journal garde le nom avant et après, pas l'historique complet.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/classroom/classroom_numbering.rb
def self.full_name(prefix:, suffix:) = "#{prefix} #{suffix.to_s.squish}"

# Le suffixe d'un nom de ce préfixe, ou "" quand le nom n'en vient pas (saisie libre d'avant l'ADR-0098).
def self.suffix_of(name:, prefix:) = name.delete_prefix("#{prefix} ").then { it == name ? "" : it }
```

```ruby
# app/infrastructure/repositories/classroom/classroom_repository.rb
def update_settings(id:, name:, max_students:)
  record = Orm::Classroom.lock.find_by(id:)
  return ::Shared::Result.failure(:not_found) if record.nil?
  return ::Shared::Result.failure(:conflict, errors: { base: [ :archived ] }) if record.status == "archived"

  headcount = Orm::ClassroomStudent.where(classroom_id: id, left_at: nil).count
  if max_students < headcount
    return ::Shared::Result.failure(:conflict, errors: { max_students: [ :below_headcount ], headcount: })
  end

  record.update!(name:, max_students:)
  ::Shared::Result.success(to_entity(record))
rescue ActiveRecord::RecordNotUnique
  ::Shared::Result.failure(:conflict, errors: { suffix: [ :taken ] })
end
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/classroom/classroom_numbering_test.rb` : `full_name` compacte les espaces ; `suffix_of` rend `""` pour un nom d'un autre préfixe.
- `test/domain/use_cases/classroom/update_classroom_test.rb` : direction d'un autre établissement → `:not_found` ; enseignant → `:forbidden` ; classe d'une année passée → `:not_found` ; rien de changé → aucun audit.
- `test/infrastructure/repositories/classroom/classroom_repository_test.rb` : `below_headcount` à 42 élèves pour 40 ; `archived` ; `taken` contre une classe archivée de la même année.
- Test de concurrence (deux connexions, comme l'ADR-0041) : une adhésion et une baisse de plafond au 80ᵉ siège ne laissent jamais plus d'élèves que le plafond.
- `test/system/school/classroom_settings_test.rb` : l'équipe renomme « 6ème 3 » en « 6ème A », puis le « + » ajoute « 6ème 3 ».

## 8. Remplace, complète, amende

- **Amende** l'ADR-0041 : le plafond d'une classe se modifie après sa création, dans ses bornes (1 à 150), jamais sous l'effectif présent.
- **Précise** l'ADR-0059 : un nom renommé garde son préfixe ; seuls les suffixes numériques entrent dans le maximum.
- **Étend** la `ManageSchoolStructurePolicy` (ADR-0059, ADR-0071, ADR-0088) à la modification d'une classe.

## 9. Points à confirmer par le porteur

- Q1 : équipe et direction, pas l'enseignant.
- Q2 : le nom et le plafond seulement.
- Q3 : plafond refusé sous l'effectif présent.
- Q4 : préfixe du barème fixe, suffixe libre.
