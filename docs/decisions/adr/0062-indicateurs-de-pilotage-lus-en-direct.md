# ADR-0062 : Les indicateurs de pilotage se lisent en direct, par deux queries bornées, sur des définitions métier fixées

| | |
|---|---|
| **Statut** | Accepté (par défaut, à confirmer par le porteur) |
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

- **Le coût croît avec le volume** : les comptages parcourent `users`, `exercise_sessions` et `classroom_assignments` sans index sur leurs dates. Mesuré le 2026-09-28 (journal) : négligeable en V1. **Seuil de reprise** : quand la page dépasse 300 ms en production, ou `exercise_sessions` 1 million de lignes, un chantier d'optimisation ajoute d'abord des index sur `exercise_sessions.started_at`, `exercise_sessions.completed_at`, `users.created_at` et `classroom_assignments.assigned_at`, puis, s'il le faut, un cache court avec clé complète.
- **Pas d'historique** : on ne peut pas comparer à la période précédente, ni tracer une courbe. Une V2 du pilotage le fera, sur les mêmes définitions.
- **La recherche partielle par numéro** ouvre l'annuaire que l'UDR-0020 réservait à la V4 : elle est bornée (équipe seule, 20 par page, numéro masqué dans la réponse).
- Les définitions du territoire ignorent les élèves non placés sous un filtre DRENA : un élève sans classe n'apparaît que dans la vue nationale.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/school/reporting_period.rb
ReportingPeriod = Data.define(:key, :since) do
  def self.parse(key, today:)
    key = KEYS.include?(key) ? key : DEFAULT
    since = key == "year" ? Date.new(SchoolYear first year, 9, 1) : today - (DAYS.fetch(key) - 1)
    new(key:, since:)
  end
end
```

```ruby
# app/controllers/teams/dashboards_controller.rb
def show
  render_result Policies::School::ReadIndicatorsPolicy.new.call(actor: current_actor), success: lambda { |_|
    return render_search if turbo_frame_request_id == SEARCH_FRAME

    @period = Entities::School::ReportingPeriod.parse(params[:period], today: Date.current)
    @dashboard = Queries::School::TeamDashboardQuery.new.call(period: @period, drena_public_id: params[:drena])
    @search = search
  }
end
```

Lectures groupées : un `GROUP BY` par dimension (rôle, niveau, DRENA), des `COUNT(*) FILTER (WHERE EXISTS …)` pour la couverture, et, pour les inscrits récents, deux lectures groupées de leurs établissements (élèves par classe, enseignants par établissement principal), jamais une par compte.

## 7. Comment vérifier que la décision est respectée

- `test/infrastructure/queries/school/team_dashboard_query_test.rb` : un test par définition du §4, le cas vide, le filtre DRENA, et « le nombre de requêtes ne change pas quand le volume triple ».
- `test/infrastructure/queries/identity/account_search_query_test.rb` : rôles exclus, anonymisés exclus, numéro masqué, jokers échappés, nombre de requêtes constant.
- `test/domain/policies/school/read_indicators_policy_test.rb` : un refus par rôle non autorisé.
- `test/views/no_third_party_resources_test.rb` et `test/integration/content_security_policy_test.rb` (ADR-0049) restent verts : la page n'ajoute ni script ni ressource.
