# ADR-0062 : Les indicateurs de pilotage se lisent en direct, par deux queries bornées, sur des définitions métier fixées

| | |
|---|---|
| **Statut** | Accepté (décidé par le porteur le 2026-09-28) |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/pilotage-equipe`](../../chantiers/pilotage-equipe/memo.md) — V4, TR-10, TR-11, TR-12 |
| **Complète** | [ADR-0049](./0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (F-27, option C : indicateurs côté serveur) · [ADR-0038](./0038-comptes-de-l-equipe-et-sous-roles.md) (« Lire les indicateurs agrégés ») |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0049 a retiré tout outil de mesure navigateur et promis, en échange, des « indicateurs métier agrégés, lus par des queries CQRS, affichés dans l'espace équipe » en V4. Il esquissait une `Queries::School::EngagementQuery` sans fixer ni les définitions ni la forme de lecture.

Trois questions restaient ouvertes :

1. **Les définitions.** Le schéma n'a ni statut de compte, ni DRENA sur l'élève, ni notion d'« élève actif ». Sans définition écrite, deux écrans compteront bientôt deux choses différentes sous le même mot, comme l'ancien « Control Center » (TR-10) qui lisait des méthodes disparues sans qu'aucun test le voie.
2. **La forme de lecture.** Lire en direct, précalculer dans une table d'agrégats, ou mettre en cache.
3. **Les données personnelles.** La page liste des comptes d'un public en majorité mineur (ADR-0049 §1) : ce qu'elle montre doit être minimal.

## 2. Moteurs de décision

1. Des chiffres **justes et explicables** : chaque indicateur a une définition d'une phrase, testée.
2. **Aucune nouvelle table** (feuille de route, V4), aucun traceur (ADR-0049).
3. Un coût de lecture **borné** : un nombre de requêtes fixe, indépendant du volume.
4. Minimisation : pas de numéro complet sur un écran d'agrégats.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Table d'agrégats quotidiens remplie par un job | Lecture instantanée à tout volume ; historique | Une table et un job de plus, des chiffres en retard d'un jour, une source de vérité en double ; surdimensionné aux volumes de la V1 |
| B — Lecture en direct + `Rails.cache` | Coût amorti | Des chiffres périmés juste après une action de l'équipe (défaut que l'UDR-0018 a déjà écarté pour l'accueil) ; clé de cache à tenir complète (période, DRENA, jour) |
| **C — Lecture en direct, requêtes groupées en nombre fixe** | Chiffres exacts ; aucune table ; aucun cache à invalider ; coût mesuré | Retenue — voir coûts consentis |

## 4. Décision

> **Nous lisons les indicateurs en direct, par deux queries de lecture : `Queries::School::TeamDashboardQuery` (indicateurs, répartition, couverture, inscrits récents) et `Queries::Identity::AccountSearchQuery` (recherche). Chacune émet un nombre fixe de requêtes, groupées, quel que soit le volume. Aucune table, aucun index, aucun cache en V1 du pilotage.**

**Définitions** (une phrase chacune, chacune testée) :

| Indicateur | Définition |
|---|---|
| Compte actif | Compte non anonymisé (`anonymized_at` vide, ADR-0036) |
| Élève placé | Élève non anonymisé qui a une classe **principale**, non quittée, **active**, de l'**année scolaire en cours** (ADR-0040, ADR-0041) |
| DRENA d'un élève | Celle de l'établissement de sa classe de placement ; un élève non placé n'en a pas |
| DRENA d'un enseignant | Celle de son établissement **principal** (ADR-0030) |
| DRENA d'un membre de l'équipe | Aucune : sous un filtre DRENA, l'équipe n'est pas comptée |
| Nouvel inscrit | Compte actif créé dans la période |
| Élève actif | Élève qui a **commencé** au moins une session d'exercice dans la période, quel qu'en soit le statut |
| Exercice terminé | Session `completed` dont la clôture tombe dans la période |
| Taux de réussite | Moyenne arrondie des `score_percent` des exercices terminés de la période ; absent (« — ») s'il n'y en a aucun |
| Assignation | Ligne `classroom_assignments` dont `assigned_at` tombe dans la période, tous statuts |
| Établissement actif | `schools.status = 'active'` ; « avec une classe », « avec un enseignant », « avec un élève » se lisent sur les seules classes actives de l'année et les comptes actifs |
| Classe | Classe active de l'année scolaire en cours |

**Période** : `Entities::School::ReportingPeriod`, valeur pure du domaine. `7d` (défaut), `30d` ou `year`, en jours entiers jusqu'à aujourd'hui inclus, dans le fuseau de l'application ; `year` part du 1ᵉʳ septembre (ADR-0041). Toute autre clé vaut `7d`.

**Filtre DRENA** : il s'applique à tous les indicateurs de la page, tableau « Par DRENA » compris. Une DRENA inconnue donne la vue nationale.

**Numéros** : la query masque le numéro (`Entities::Identity::Contact.mask`, deux premiers et deux derniers chiffres) avant qu'il ne quitte l'infrastructure. Le numéro complet n'atteint jamais la vue du pilotage.

**Recherche** : élèves et enseignants actifs, sur le nom (casse et accents ignorés, comme `SchoolsQuery`) ou le numéro (4 chiffres au moins), 2 caractères au moins, 20 par page, triés par nom. Les jokers `%` et `_` sont échappés.

**Autorisation** : `Policies::School::ReadIndicatorsPolicy` autorise tout acteur `team` (matrice ADR-0038, trois sous-rôles) ; la recherche passe aussi par `Policies::Identity::ReadUserPolicy`. Aucun use case : ce sont des lectures (ADR-0006, ADR-0012).

## 5. Conséquences

### 🟢 Positives

- Chaque chiffre de la page a une définition écrite et un test ; un écran futur qui voudra « les élèves actifs » reprendra la même phrase.
- Aucune table ni job : rien à migrer, rien à resynchroniser, aucun chiffre en retard.
- Le nombre de requêtes est fixe et vérifié par un test ; une régression N+1 casse la CI.
- Le numéro d'un mineur ne s'affiche jamais en entier sur l'écran d'agrégats.

### 🔴 Coûts consentis

- **Le coût croît avec le volume** : les comptages parcourent `users`, `exercise_sessions` et `classroom_assignments` sans index sur leurs dates. Mesuré le 2026-09-28 (journal, base de test locale, 2 000 établissements, 10 000 classes) : **0,17 à 0,27 s** pour 10 000 élèves et 10 000 sessions, **0,64 s** pour 100 000 élèves et 100 000 sessions ; la recherche, 0,12 s puis 0,7 s. Les volumes de la V1 sont bien en dessous du premier point. **Seuil de reprise** : quand la page dépasse 300 ms en production (vers 20 000 à 30 000 élèves d'après ces mesures), un chantier d'optimisation ajoute d'abord des index sur `exercise_sessions.started_at`, `exercise_sessions.completed_at`, `users.created_at` et `classroom_assignments.assigned_at`, puis, s'il le faut, un cache court avec clé complète ; pour la recherche, un index trigramme (`pg_trgm`) sur le nom.
- **Pas d'historique** : on ne peut pas comparer à la période précédente, ni tracer une courbe. Une V2 du pilotage le fera, sur les mêmes définitions.
- **La recherche partielle par numéro** ouvre l'annuaire que l'UDR-0020 réservait à la V4 : elle est bornée (équipe seule, 20 par page, numéro masqué dans la réponse).
- Les définitions du territoire ignorent les élèves non placés sous un filtre DRENA : un élève sans classe n'apparaît que dans la vue nationale.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/school/reporting_period.rb
ReportingPeriod = Data.define(:key, :since) do
  # Une clé absente ou inconnue (paramètre d'URL) vaut la période par défaut.
  def self.parse(key, today:)
    key = self::DEFAULT unless self::KEYS.include?(key)
    since = self::DAYS.key?(key) ? today - (self::DAYS.fetch(key) - 1) : school_year_start(today)
    new(key:, since:)
  end
  # …
end
ReportingPeriod::DAYS = { "7d" => 7, "30d" => 30 }.freeze
ReportingPeriod::KEYS = [ *ReportingPeriod::DAYS.keys, "year" ].freeze
```

```ruby
# app/controllers/teams/dashboards_controller.rb
def show
  render_result Policies::School::ReadIndicatorsPolicy.new.call(actor: current_actor), success: lambda { |_|
    render_result Policies::Identity::ReadUserPolicy.new.call(actor: current_actor), success: ->(_) { respond_with_search }
  }
end

# Le frame de recherche ne reçoit que ses résultats : chercher ne recalcule pas les indicateurs.
def respond_with_search
  @search = Queries::Identity::AccountSearchQuery.new.call(term: params[:q], page: params[:page])
  return render(partial: "search_results", locals: { search: @search }) if turbo_frame_request_id == SEARCH_FRAME

  @period = Entities::School::ReportingPeriod.parse(params[:period], today: Date.current)
  @dashboard = Queries::School::TeamDashboardQuery.new.call(period: @period, drena_public_id: params[:drena])
  @drenas = Queries::School::SchoolOptionsQuery.new.drenas
end
```

```ruby
# app/infrastructure/queries/school/team_dashboard_query.rb — un élève est placé par sa classe principale de l'année
def placements(territorial: true)
  scope = Orm::ClassroomStudent.joins(:student, classroom: :school)
                               .where(primary: true, left_at: nil, users: { anonymized_at: nil },
                                      classrooms: { status: "active", school_year: @year })
  territorial ? in_drena(scope) : scope
end
```

Lectures groupées : un `GROUP BY` par dimension (rôle, niveau, DRENA) ; la couverture en une lecture de `COUNT(*) FILTER (WHERE EXISTS …)`, en SQL constant où seule l'année est liée ; les inscrits récents avec deux lectures groupées de leurs établissements, jamais une par compte. Mesure du 2026-09-28 : **18 requêtes** en vue nationale, **21** sous un filtre DRENA, **4** pour une recherche, identiques quel que soit le volume.

## 7. Comment vérifier que la décision est respectée

- `test/infrastructure/queries/school/team_dashboard_query_test.rb` : un test par définition du §4, le cas vide, le filtre DRENA, et « le nombre de requêtes ne change pas quand le volume triple ».
- `test/infrastructure/queries/identity/account_search_query_test.rb` : rôles exclus, anonymisés exclus, numéro masqué, jokers échappés, nombre de requêtes constant.
- `test/domain/policies/school/read_indicators_policy_test.rb` : un refus par rôle non autorisé.
- `test/views/no_third_party_resources_test.rb` et `test/integration/content_security_policy_test.rb` (ADR-0049) restent verts : la page n'ajoute ni script ni ressource.

## Amendement du 2026-09-29 — index, lecture groupée des placements et `pg_trgm`

*Chantier [`docs/chantiers/cache-ecrans-lourds`](../../chantiers/cache-ecrans-lourds/memo.md), décisions du porteur du 2026-09-29. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi. Les budgets de temps sont dans l'[ADR-0067](./0067-budgets-de-temps-serveur-des-ecrans.md).*

- **Le seuil de reprise est atteint** au volume de la feuille de route (40 000 élèves, 312 000 sessions : 338 ms en p50 sur 7 jours). Le premier temps prévu au §5 est appliqué, **dans l'ordre** : `exercise_sessions (started_at, student_id)`, `exercise_sessions (completed_at) INCLUDE (student_id, score_percent) WHERE status = 'completed'`, `users (created_at, id)` (qui sert aussi les derniers inscrits), `classroom_assignments (assigned_at)`.
- **Les placements se lisent une fois.** Le §4 « un `GROUP BY` par dimension » devient, pour les élèves placés, **une seule lecture groupée par (niveau, DRENA)** avec `COUNT(*) FILTER` pour les actifs de la période : le total, la répartition par niveau, les élèves et les actifs par DRENA en découlent. Les définitions du §4 sont inchangées, un test de non-régression couvre leurs cas limites. Nombre de requêtes : **16** en vue nationale (au lieu de 18), **18** sous un filtre DRENA (au lieu de 21), toujours indépendant du volume.
- **`pg_trgm` est activée** (première extension du projet hors `plpgsql`). C'est une extension standard, livrée avec PostgreSQL (`contrib`) et donc avec l'image officielle sur laquelle repose l'image Railway `postgres-ssl` ; elle est « trusted » depuis PostgreSQL 13 (le propriétaire de la base peut l'activer sans superutilisateur). Cinq index GIN `gin_trgm_ops` portent **exactement** les expressions de recherche : nom dans les deux ordres pour `AccountSearchQuery`, nom, sigle et code national pour `SchoolsQuery`. La recherche garde sa définition (casse et accents ignorés par `translate(lower(...))`, pas `unaccent`) ; `test/infrastructure/queries/trigram_search_indexes_test.rb` échoue si une expression s'écarte de son index. Un terme de 2 caractères n'a aucun trigramme complet : il reste en parcours séquentiel, comme avant.
- **Le cache court** : écarté par cet amendement, puis retenu pour la seule vue « année » par l'amendement suivant.

## Amendement du 2026-09-29 (second) — les chiffres de l'année scolaire sont gardés 5 minutes

*Chantier [`docs/chantiers/cache-ecrans-lourds`](../../chantiers/cache-ecrans-lourds/memo.md), décision du porteur du 2026-09-29, prise sur la mesure après les index et la lecture groupée. Le texte ci-dessus et l'amendement précédent restent tels qu'acceptés ; en cas d'écart, cette section fait foi.*

**Pourquoi.** Après les index, la vue « année » restait à **304 ms en p95** (budget 300 ms, [ADR-0067](./0067-budgets-de-temps-serveur-des-ecrans.md)). Son coût suit les sessions de l'année scolaire : les index n'y servent plus (la période couvre la moitié de la table au 29 septembre, bientôt toute l'année), et la page dépassera nettement le budget avant la fin de l'année. C'est le « second temps » prévu au §5 : un cache court, à clé complète.

**Décision.** Pour la **seule période `year`**, `Queries::School::TeamDashboardQuery` garde ses **agrégats** dans `Rails.cache` (Solid Cache en production) **5 minutes** (`expires_in: 5.minutes`). Les périodes 7 et 30 jours restent lues en direct, filtre DRENA compris. L'option B du §3 est donc retenue pour cette vue, et pour elle seule.

| | |
|---|---|
| **Ce qui est gardé** | Tout ce que la page calcule, **sauf les derniers inscrits** : comptes par rôle, flux de la période, couverture, classes, répartition par niveau, élèves placés et non placés, lignes par DRENA. Des nombres seulement. |
| **Ce qui ne l'est jamais** | Les derniers inscrits (noms, numéro masqué) : lus en direct à chaque page. Un compte créé apparaît tout de suite, et aucune donnée personnelle n'entre dans le cache. |
| **Clé** | `team_dashboard/v<CACHE_VERSION>/year/<année scolaire>/<début de période>/<public_id de la DRENA résolue ou national>`. Tout vient de la base ou de l'horloge, rien de l'URL tel quel : une DRENA inconnue lit l'entrée nationale, deux DRENA ont deux entrées, et rien ne dépend de l'acteur (toute l'équipe voit les mêmes chiffres, ADR-0038). `CACHE_VERSION` change avec une définition du §4 ou la forme des chiffres. |
| **Durée** | 5 minutes, puis la page suivante relit la base. |
| **Invalidation** | **Aucune invalidation fine.** Les chiffres dépendent de sessions, de devoirs, d'inscriptions, de placements et d'établissements, écrits par de nombreux use cases de plusieurs contextes (évaluation, classe, identité, établissement) : purger l'entrée à chacun d'eux couplerait toute l'écriture à un écran de lecture, pour gagner au plus 5 minutes. L'expiration suffit. |

**Coût consenti.** Les chiffres de l'année peuvent avoir **jusqu'à 5 minutes de retard** : une session terminée, un devoir ou une inscription n'y apparaît qu'à la lecture suivante après expiration. Sur un indicateur cumulé depuis le 1ᵉʳ septembre, ce retard ne change pas la lecture de la page ; il reste le défaut que l'UDR-0018 refuse pour un accueil, et c'est pourquoi les vues 7 et 30 jours, faites pour suivre l'activité récente, restent en direct. La première page après expiration paie le calcul complet (≈ 280 ms aujourd'hui, davantage en fin d'année) : le budget de l'ADR-0067 s'applique à l'entrée chaude, le froid est mesuré et noté.

**Vérification.**

- `test/infrastructure/queries/school/team_dashboard_query_test.rb` : mêmes chiffres à froid, à chaud et sans cache (`NullStore`) ; une seconde lecture dans les 5 minutes ne lance aucune requête de chiffres ; chiffres en retard à 4 min 59 s et à jour à 5 min 01 s, derniers inscrits jamais en retard ; deux filtres DRENA, et un filtre face à la vue nationale, n'ont jamais la même entrée ; 7 et 30 jours relisent la base.
- `PERF=1 test/performance/school/heavy_screens_budget_test.rb` : p95 de la vue « année » à chaud sous 300 ms ; le froid est affiché.
- `script/perf/measure_screens.rb` et `PERF_COLD=1` : la page à chaud et à froid.

## Amendement du 2026-10-03 — lecture « Par établissement » d'une DRENA

*Chantier [`docs/chantiers/reorganisation-equipe-enseignant`](../../chantiers/reorganisation-equipe-enseignant/prd.md), [UDR-0068](../udr/0068-configuration-et-pilotage-par-etablissement.md) §3.6. Statut : proposé, accepté avec le plan du chantier. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Nouvelle lecture** `Queries::School::DrenaSchoolsQuery`, servie par le pilotage sous filtre DRENA : les établissements de la DRENA et, pour chacun, classes, enseignants, élèves et élèves actifs.
- **Mêmes définitions** que `TeamDashboardQuery#drena_rows`, établissement par établissement : classes actives de l'année scolaire ; enseignants rattachés à titre principal, non anonymisés ; élèves placés (classe principale, non quittée, active, de l'année) ; élèves placés ayant commencé une session dans la période. Une définition qui change, change pour les deux lectures.
- **Liste** : les établissements actifs, plus tout établissement non actif qui compte encore une classe, un enseignant ou un élève, pour que **la somme des établissements égale la ligne de la DRENA** (critère RE-08, testé).
- **Nombre de requêtes fixe** (le total, puis une page de 25 aux chiffres calculés par agrégats groupés ou sous-requêtes), quel que soit le nombre d'établissements ; tri par élèves décroissants, nom, id ; recherche par `Queries::Shared::TextSearch` sur le nom.
- **Aucun cache** : la page d'établissements n'entre pas dans le cache des chiffres de l'année (second amendement du 2026-09-29) ; `CACHE_VERSION` reste 1.
- **Coût consenti** (constat du challenger, 2026-10-04) : en vue « année », la ligne DRENA et les chiffres clés sont gardés 5 minutes, le tableau des établissements est lu en direct. Pendant ces 5 minutes après un changement, la somme des établissements peut différer de la ligne DRENA (ex. 423 élèves contre 422). En 7 et 30 jours, les deux lectures sont en direct et égales (RE-08). Faire entrer le tableau dans le cache est le levier si l'écart gêne. Budget : celui du pilotage (ADR-0067, < 300 ms p95), mesuré sur la plus grande DRENA du jeu de mesure ; un dépassement ouvre un chantier `optimize` (index d'abord).

## Amendement du 2026-10-04 — sous filtre DRENA, les établissements et les chiffres sont une seule lecture

*Chantier [`docs/chantiers/dettes-reorganisation`](../../chantiers/dettes-reorganisation/memo.md) (bug 4), demande du porteur du 2026-10-04 (« Fix les 4 dettes »). Statut : proposé, accepté avec le plan du chantier. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi. Remplace le « Coût consenti » et le point « Aucun cache » de l'amendement du 2026-10-03.*

**Pourquoi.** En vue « année », sous filtre DRENA, la page lisait ses chiffres dans le cache (jusqu'à 5 minutes de retard) et le tableau « Par établissement » en direct. La somme des établissements pouvait donc différer des chiffres de la DRENA sur la même page, ce que la règle 8 de l'UDR-0068 (RE-08) interdit. Deux options ont été écartées :
- **Un second cache pour le tableau** n'aligne rien : deux entrées remplies à deux instants restent décalées.
- **Tout lire en direct sous filtre** referait payer le coût que le cache de l'année évite. La sous-requête des élèves actifs parcourt toutes les sessions de la période, quel que soit le filtre, et ce coût croît jusqu'à la fin de l'année scolaire.

**Décision.** Sous un filtre DRENA, `TeamDashboardQuery` calcule, **dans la même lecture que ses chiffres**, les lignes de **tous** les établissements listés de la DRENA. `school_rows` vient de `DrenaSchoolsQuery#rows`, avec les définitions et la liste de l'amendement du 2026-10-03, inchangées.

- **Même instant.** En vue « année », ces lignes entrent dans l'**entrée de cache des chiffres**, à la même clé. En 7 et 30 jours, tout est lu en direct, comme avant. Les chiffres du haut et le tableau datent donc toujours du même instant, et leur somme est égale à toute période.
- **Recherche et pages.** `DrenaSchoolsQuery#page` les fait sur ces lignes : pages de 25, dans l'ordre de l'instantané.
  - La recherche garde sa définition : `Queries::Shared::TextSearch` sur le nom, en SQL, en une requête, parmi les établissements de l'instantané.
  - Un établissement créé ou renommé depuis apparaît à l'expiration de l'entrée, comme tout chiffre de l'année.
- **Version du cache.** La forme des chiffres gardés change : `CACHE_VERSION` passe à **2**, et les entrées v1 ne sont plus lues. La vue nationale garde le même contenu, sans lignes d'établissements (`school_rows` vaut `nil`).
- **Taille de l'entrée.** Elle grandit d'une ligne de sept valeurs par établissement de la DRENA : quelques centaines au plus, des nombres et des noms d'établissements, aucune donnée de personne.
- **Requêtes.** Le nombre reste fixe, quel que soit le volume.
  - Sous filtre, la lecture des chiffres compte une requête de plus (les lignes).
  - Le contrôleur n'en lit plus que pour une recherche (une requête), au lieu de trois : la DRENA, le total et la page.

**Coût consenti.**
- Le tableau d'une DRENA en vue « année » a désormais le même retard possible que ses chiffres, jusqu'à 5 minutes.
- En passant de la vue nationale à une DRENA, la ligne « Par DRENA » et la page filtrée sont deux entrées, remplies à deux instants : pendant 5 minutes au plus, elles peuvent différer. Ce sont deux pages ; l'égalité RE-08 est celle d'une même page.

**Vérification.**
- `test/infrastructure/queries/school/drena_schools_query_test.rb` : avec le cache réel, une page filtrée en vue « année » relue après un changement a toujours une somme des établissements égale à ses chiffres ; RE-07 à RE-10 inchangés.
- `test/infrastructure/queries/school/team_dashboard_query_test.rb` : la vue nationale « année » garde son cache ; le nombre de requêtes reste indépendant du volume.
- `PERF=1 test/performance/school/heavy_screens_budget_test.rb` : la page filtrée de la plus grande DRENA, en 7 jours et en année (entrée chaude), sous 300 ms p95.

