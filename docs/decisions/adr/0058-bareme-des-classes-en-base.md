# ADR-0058 : Le barème des classes générées est en base, modifiable par l'équipe, repris à l'identique au déploiement

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/bareme-classes`](../../chantiers/bareme-classes/prd.md) |
| **Remplace** | — *(amende [ADR-0030](0030-une-ecole-par-enseignant-et-creation-des-classes.md) §4 « Génération des classes par défaut » et [ADR-0056](0056-generation-des-classes-manquantes.md))* |
| **Remplacé par** | — |

> Numérotation : ADR-0057 est laissé libre à dessein. Deux chantiers tournaient en parallèle le 2026-09-28 (`code-etablissement`, `finitions-generation-menu`) ; ce chantier a pris « le plus haut + 2 » pour éviter une collision de numéro au merge.

---

## 1. Contexte et problématique

L'ADR-0030 a fixé le nombre de classes générées à la création d'un établissement dans une constante du domaine, `Entities::Classroom::DefaultClassroomPlan::PLAN` : par type (`public`, `private` ; `mixed` suit `private`), par slug de niveau, avec trois formes — un nombre (`"6eme" => 4`), « par série liée » (`"2nde" => { per_series: 6 }`) et une liste de séries nommées (`"tle" => { "c" => 2, "d" => 6, … }`). L'ADR-0030 le reconnaissait dans ses coûts : « le plan de génération est dans le code : le changer demande une PR ».

Depuis le 2026-09-28, deux chemins le lisent : l'import des établissements (`UseCases::School::ImportSchools`) et la génération des classes manquantes (`UseCases::Classroom::GenerateMissingClassrooms`, ADR-0056), qui doit doter près de 3 900 établissements. Le porteur demande que l'équipe modifie ce barème depuis l'écran. Deux contraintes pèsent :

- **Le jour du déploiement, rien ne doit changer** : le premier import ou la première génération après la mise en production doivent donner exactement les classes de l'ancien barème.
- Le « par série liée » est une règle cachée : une série liée à la 2nde plus tard reçoit 6 classes sans que personne ne l'ait décidé. À l'écran, l'équipe doit voir chaque nombre qu'elle obtiendra.

## 2. Moteurs de décision

1. Comportement identique en production au déploiement (reprise exacte).
2. Le domaine reste pur : l'entité de plan ne lit pas la base, elle reçoit le barème.
3. Ce que l'écran montre est exactement ce que l'import et la génération appliquent, sans règle implicite.
4. La génération de 3 900 établissements ne ralentit pas (une lecture du barème par exécution).
5. Aucune classe existante n'est touchée par un changement du barème.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Garder la constante, ajouter des surcharges en base | Reprise gratuite | Deux sources de vérité ; l'écran devrait expliquer laquelle gagne |
| B — Stocker le barème tel quel (jsonb, formes « nombre », « par série », « séries nommées ») | Reprise triviale | Le « par série » reste implicite ; clés par slug non contraintes (un slug renommé casse en silence) ; unicité et bornes invérifiables en base |
| C — **Une ligne par (type, niveau, série éventuelle)**, clés étrangères vers le référentiel | Chaque nombre est explicite et contraint ; l'écran affiche ce qui s'applique ; les lignes suivent le référentiel | Une série liée plus tard n'a pas de nombre : il faut une règle pour l'absence |

## 4. Décision

> **Nous stockons le barème dans `classroom_plan_entries`, une ligne par type d'établissement, niveau et série (nulle au premier cycle), reprise de l'ancien barème par migration de données ; une ligne absente vaut 0, s'affiche « Non défini » et est comptée comme sautée. L'entité de plan devient une fonction pure qui reçoit le barème ; l'import et la génération le lisent une fois par exécution. Modifier le barème ne touche aucune classe existante.**

**Table `classroom_plan_entries`** (contexte `classroom`) :

| Colonne | Type | Contrainte |
|---|---|---|
| `school_type` | `string` | `NOT NULL`, `CHECK IN ('public','private')` — `mixed` suit `private` (ADR-0030) |
| `level_id` | `bigint` | `NOT NULL`, FK `levels` `ON DELETE RESTRICT` |
| `series_id` | `bigint` | nul au premier cycle, FK `series` `ON DELETE RESTRICT` |
| `count` | `integer` | `NOT NULL`, `CHECK (count BETWEEN 0 AND 30)` |
| `created_at`, `updated_at` | `datetime` | `NOT NULL` |

Index uniques partiels : `(school_type, level_id, series_id) WHERE series_id IS NOT NULL` et `(school_type, level_id) WHERE series_id IS NULL` (sans dépendre de `NULLS NOT DISTINCT`, PostgreSQL 15+). Les lignes suivent le référentiel : supprimer un niveau ou une série emporte les siennes, sans jamais être retenu par elles — `Repositories::Catalog::TaxonomyRepository#delete_level` et `#delete_series` les effacent juste avant, dans la transaction du use case. Les clés étrangères restent `RESTRICT` : la liste fermée des cascades de l'ADR-0036 ne change pas. Délier un couple garde son nombre, sans effet tant que le couple n'est pas relié.

**Les lignes attendues** sont celles que le référentiel rend possibles, dans l'ordre des positions : un niveau du premier cycle a **une** ligne (série nulle) ; un niveau du second cycle a une ligne **par série liée**. Un niveau du second cycle sans série n'a pas de ligne (sauté et compté, comme avant).

**Génération** (`Entities::Classroom::DefaultClassroomPlan.rows_for(school:, lookup:, plan:)`, pure ; `plan` est un `Entities::Classroom::ClassroomPlan`, valeur construite des entrées) :

- barème du type (`public`, sinon `private`) ; un collège (`cycle = 'first'`) ne prend que les niveaux du premier cycle ;
- nombre défini : autant de classes, nommées comme avant (« 6ème 1 », « Tle D 3 ») ; `0` : aucune classe, rien de compté ;
- ligne **absente** : aucune classe ; le niveau (premier cycle) ou le couple `niveau/série` (second cycle) est compté dans `skipped` — même clé au rapport (`skipped_levels`, `skipped_series`), libellés précisés ; un niveau du second cycle sans série liée est compté dans `skipped_levels`, comme avant — **quel que soit son code** : un niveau créé par l'équipe hors des sept codes historiques, au second cycle et sans série, est désormais compté pour chaque lycée, alors que l'ancienne constante l'ignorait.
- ce qui disparaît : un niveau « absent du référentiel » n'existe plus (le barème pointe vers des niveaux par clé étrangère). Un référentiel vide ne compte donc plus 7 niveaux sautés par établissement : il n'y a rien à sauter. Le compteur « Sans classe à générer » de l'ADR-0056 le dit toujours.

**Lecture une fois par exécution** : `ImportSchools#prepare` lit le barème avec le référentiel (`ImportContext#data[:plan]`) ; `GenerateMissingClassrooms` le lit au démarrage, avec le référentiel. Un changement pendant une exécution s'applique à la suivante.

**Reprise** (`db/migrate/20260928140100_fill_classroom_plan_entries.rb`), une requête `INSERT … SELECT … ON CONFLICT DO NOTHING` par forme de l'ancien barème, par slug :

| Ancienne forme | Lignes créées |
|---|---|
| nombre (`6eme`, `5eme`, `4eme`, `3eme`) | une ligne `(type, niveau, NULL)` |
| « par série » (`2nde`, `1ere`) | une ligne `(type, niveau, série)` **par série liée au moment de la reprise** |
| séries nommées (`tle` : `c`, `d`, `a1`, `a2`) | une ligne par couple **lié** ; une série de Tle hors de la liste reste non définie (elle n'avait pas de classe) |

Avec le référentiel A1/A2/C/D lié à la 2nde, la 1ère et la Tle, le barème repris donne lycée public 89, lycée privé 44, collège public 28, collège privé 12 — les nombres de l'ancien code. Relancée, la reprise n'écrit rien. Sur une base vide (développement, test), elle n'écrit rien : les seeds et les fabriques de test appellent la même reprise après avoir créé le référentiel.

**Modification** : `UseCases::Classroom::UpdateClassroomPlanLine` (policy `Policies::Classroom::ManageClassroomPlanPolicy`, équipe) écrit les seuls nombres changés d'une ligne, dans une transaction, avec une entrée d'audit `classroom_plan.changed` par nombre changé (`subject_type` `Level`, `metadata` : `school_type`, `level`, `series`, `from`, `to` ; `from` nul pour une ligne non définie). Lecture : `UseCases::Classroom::ShowClassroomPlan`, même policy.

## 5. Conséquences

### 🟢 Positives

- L'équipe ajuste le barème sans livraison ; ce qu'elle voit est ce qui s'applique.
- Le « par série » implicite disparaît : chaque couple niveau × série a un nombre explicite, ou un « Non défini » visible.
- Contraintes en base : unicité, bornes, clés étrangères vers le référentiel.
- La génération lit toujours le barème une fois : aucune requête de plus par établissement.

### 🔴 Coûts consentis

- ~~**Une série liée plus tard n'a pas de classes**~~ *(levé par l'amendement ci-dessous : D1 décidé par le porteur)* — tant que l'équipe ne l'a pas renseignée, alors que l'ancien « par série » lui en donnait 6 (public) ou 3 (privé) en 2nde et en 1ère. Décision par défaut D1 du memo, à confirmer par le porteur ; le rapport compte ces lignes comme sautées et l'écran les signale.
- Le compteur `skipped_levels` ne compte plus les niveaux « absents du référentiel » : un référentiel vide ne donne plus « 21 niveaux sautés » pour 3 établissements.
- La reprise suppose que 6ème à 3ème sont du premier cycle et 2nde à Tle du second (référentiel de l'ADR-0034). Un niveau `6eme` passé au second cycle garderait sa ligne sans effet : l'écran l'afficherait sans série liée.
- Un couple délié garde son nombre en base, invisible : relié, il retrouve l'ancien nombre sans que l'écran l'ait montré entre-temps.
- Un changement du barème ne corrige pas les établissements déjà dotés : il faut « Ajouter une classe » (hors périmètre, inchangé).

## 6. Notes d'implémentation

```ruby
# app/domain/entities/classroom/default_classroom_plan.rb
def self.rows_for(school:, lookup:, plan:)
  rows = []
  skipped = { levels: [], series: [] }
  slots(lookup).each do |level, series|
    next if school.cycle == "first" && !level.first_cycle?
    next skipped[:levels] << level.slug if !level.first_cycle? && series.nil?

    count = plan.count(school_type: school.school_type, level_id: level.id, series_id: series&.id)
    next skip(level, series, skipped) if count.nil?

    rows.concat(rows_of(level, series, count))
  end
  Generation.new(rows:, skipped:)
end
```

```ruby
# app/domain/use_cases/classroom/generate_missing_classrooms.rb
@lookup = @taxonomy.lookup
@plan = @classroom_plan.plan
```

```ruby
# app/infrastructure/repositories/catalog/taxonomy_repository.rb
Orm::ClassroomPlanEntry.where(plan_entries).delete_all if plan_entries
(id ? scope.where(id:) : scope).delete_all
```

## 7. Comment vérifier que la décision est respectée

- `test/db/classroom_plan_data_migration_test.rb` : la reprise donne 89/44/28/12 avec A1/A2/C/D, est idempotente, laisse non définie une série de Tle hors liste.
- `test/domain/entities/classroom/default_classroom_plan_test.rb` : fonction pure, ligne absente sautée et comptée, 0 sans classe ni compte.
- `test/infrastructure/repositories/classroom/classroom_plan_repository_test.rb` : unicité, bornes, lignes emportées avec leur niveau ou leur série ; `test/db/schema_constraints_test.rb` : index partiels, énumération, clés étrangères `RESTRICT`.
- `test/system/teams/classroom_plan_test.rb` : modifier un nombre, puis générer : l'établissement reçoit le nouveau nombre ; les classes existantes ne changent pas.
- `test/architecture/port_contracts_test.rb`, `test/architecture/use_case_policies_test.rb`, `test/domain/domain_purity_test.rb`.
- `test/performance/classroom/generate_missing_classrooms_performance_test.rb` (`PERF=1`) : 500 établissements en moins de 60 s.

## 8. Remplace, complète, amende

- **Amende l'ADR-0030** §4 « Génération des classes par défaut » : le tableau du barème n'est plus dans le code mais la **valeur initiale** de `classroom_plan_entries` ; « par série » devient une ligne par série liée à la reprise ; « un niveau ou une série absent du référentiel est sauté et compté » devient « une ligne absente du barème ». Le coût « le plan de génération est dans le code » est levé.
- **Amende l'ADR-0056** : la génération lit le barème en base au démarrage, en plus du référentiel.

## Amendement du 2026-09-28 — D1 décidé par le porteur : remplissage automatique

*Décision du porteur : « renseigner ces valeurs automatiquement à chaque nouvelle série liée ». En cas d'écart avec ce qui précède, cette section fait foi.*

- **Un couple niveau × série lié par l'équipe** (`UseCases::Catalog::LinkLevelSeries`, même transaction) reçoit ses nombres par défaut (`Entities::Classroom::ClassroomPlanDefaults`) : 2nde, 1ère et tout autre niveau du second cycle, public 6 / privé 3 ; Tle, les nombres de l'ancien barème (C 2/1, D 6/3, A1 3/2, A2 2/2), toute autre série 6/3.
- **Un niveau du premier cycle créé par l'équipe** (`UseCases::Catalog::CreateLevel`) reçoit 4/2 pour les codes `6eme` et `5eme`, 10/4 pour `4eme` et `3eme`. Tout autre niveau du premier cycle n'a **pas de règle sûre** (on ne sait pas s'il ressemble à une 6ème ou à une 3ème) : il reste « Non défini », signalé à l'écran et compté sauté.
- **Jamais d'écrasement** : seul un type encore absent est écrit ; une ligne existante, même à 0, est gardée. **Délier garde les lignes** (sans effet tant que le couple est délié) : relier retrouve le nombre choisi auparavant plutôt que le défaut.
- **Audit** : une entrée `classroom_plan.changed` par nombre écrit, `metadata.source` = `auto` (`from` nul) ; les modifications à l'écran portent `source` = `manual`.
- **La reprise de données ne change pas** : elle reproduit exactement l'ancien comportement (une série de Tle hors de l'ancienne liste, liée avant le déploiement, reste non définie ; l'ancien code ne lui donnait aucune classe).
- Les liens posés hors du use case (fabriques de test, console) ne remplissent rien.
- Preuves : `test/domain/entities/classroom/classroom_plan_defaults_test.rb`, `test/domain/use_cases/catalog/{link_level_series,create_level}_test.rb`, `test/controllers/teams/{level_series,levels}_controller_test.rb`, `test/system/teams/classroom_plan_test.rb` (lier une série dans la matrice → 6/3 au barème), `test/system/boucle_pedagogique_test.rb`.
