# PRD — Pilotage de l'équipe

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'équipe n'a aucun indicateur d'usage depuis le retrait des outils tiers (ADR-0049), et l'entrée « Pilotage » de sa navigation est inactive depuis la V1. Ce chantier livre la page `GET /teams/dashboard` : chiffres clés agrégés lus côté serveur, filtres de période et de DRENA, répartition des élèves par niveau, couverture par DRENA, inscrits récents à numéro masqué, et recherche d'un élève ou d'un enseignant (TR-10, TR-11, TR-12). Voir le [memo](memo.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Équipe (`team`, tout sous-rôle, second facteur vérifié) | Ouvrir « Pilotage », filtrer par période et par DRENA, chercher un élève ou un enseignant | Voir le numéro complet d'un compte depuis cette page ; ouvrir une fiche de compte (V2) |
| Enseignant, élève, direction (`school_admin`) | — | Ouvrir la page : 403 |
| Visiteur | — | Ouvrir la page : redirection vers la connexion |
| Équipe sans second facteur vérifié | — | Ouvrir la page : redirection vers le second facteur |

Règle : `Policies::School::ReadIndicatorsPolicy` (ADR-0028), qui autorise tout acteur `team` — la matrice de l'ADR-0038 donne « Lire les indicateurs agrégés » aux trois sous-rôles. La recherche passe en plus par `Policies::Identity::ReadUserPolicy` (recherche sans cible : l'équipe seule).

## 3. Parcours utilisateur

### Chemin nominal

1. Le membre de l'équipe clique sur « Pilotage » dans la barre latérale (bureau) ou la barre basse (téléphone).
2. La page affiche les chiffres de la période par défaut (7 jours), nationaux.
3. Il choisit « 30 jours » : les indicateurs de flux se recalculent, l'URL porte `?period=30d`.
4. Il choisit une DRENA dans la liste déroulante et valide : toute la page se restreint à cette DRENA, l'URL porte `drena=<public_id>`.
5. Il tape un nom dans « Rechercher un élève ou un enseignant » : les résultats (20 au plus par page) s'affichent sous le formulaire, sans recalculer les indicateurs.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Base vide | Toutes les cartes à 0, taux de réussite « — », états vides de la répartition, du tableau DRENA et des inscrits |
| Période inconnue dans l'URL | 7 jours |
| DRENA inconnue dans l'URL | Vue nationale, liste déroulante sur « Toutes les DRENA » |
| Recherche de moins de 2 caractères | Aucun résultat, message « Tapez au moins 2 caractères. » |
| Recherche sans résultat | État vide « Aucun compte trouvé » |
| Plus de 20 résultats | Pagination, le terme conservé |
| Rôle autre que `team` | 403 |

## 4. Critères d'acceptation

Chaque critère a son test ; le fichier est indiqué en commentaire.

```gherkin
# test/domain/policies/school/read_indicators_policy_test.rb
Scénario: seul un membre de l'équipe lit les indicateurs
  Étant donné un acteur de chaque rôle et un visiteur
  Quand chacun demande à lire les indicateurs
  Alors seul le membre de l'équipe est autorisé, quel que soit son sous-rôle
  Et l'élève, l'enseignant, la direction et le visiteur reçoivent :forbidden

# test/domain/entities/school/reporting_period_test.rb
Scénario: la période se lit depuis l'URL
  Étant donné la date du 2026-09-28
  Alors « 7d » commence le 2026-09-22, « 30d » le 2026-08-30, « year » le 2026-09-01
  Et une clé absente ou inconnue vaut « 7d »

# test/infrastructure/queries/school/team_dashboard_query_test.rb
Scénario: base vide
  Quand l'équipe ouvre le pilotage sur une base vide
  Alors chaque compteur vaut 0, le taux de réussite est absent, les listes sont vides

Scénario: comptes actifs par rôle
  Étant donné 2 élèves, 1 enseignant, 1 membre de l'équipe et 1 élève anonymisé
  Alors la page compte 2 élèves, 1 enseignant, 1 membre de l'équipe

Scénario: indicateurs de flux sur la période
  Étant donné un élève inscrit il y a 3 jours et un autre il y a 20 jours
  Et un élève qui a commencé une session il y a 2 jours, un autre il y a 20 jours
  Et deux sessions terminées dans les 7 jours, à 80 % et 60 %
  Et une assignation faite il y a 2 jours, une autre il y a 20 jours
  Quand la période est de 7 jours
  Alors 1 nouvel inscrit, 1 élève actif, 2 exercices terminés, 70 % de réussite, 1 assignation
  Quand la période est de 30 jours
  Alors 2 nouveaux inscrits, 2 élèves actifs et 2 assignations

Scénario: couverture des établissements
  Étant donné un établissement actif avec classe, enseignant et élève, un actif vide et un inactif
  Alors 2 établissements actifs, dont 1 avec classe, 1 avec enseignant, 1 avec élève
  Et les classes comptées sont les classes actives de l'année scolaire

Scénario: filtre DRENA
  Étant donné deux DRENA qui ont chacune un établissement, une classe, un enseignant et un élève actif
  Quand l'équipe filtre sur la première
  Alors chaque indicateur ne compte que la première, et la carte « Équipe » est absente
  Et le tableau « Par DRENA » n'a qu'une ligne
  Quand la DRENA est inconnue
  Alors la vue est nationale

Scénario: répartition des élèves par niveau (TR-12)
  Étant donné 3 élèves en Tle, 1 en 6ème, 1 sans classe et 1 dans une classe archivée
  Alors la répartition donne 6ème 1, Tle 3 par position de niveau, et 2 élèves sans classe

Scénario: tableau par DRENA
  Alors chaque DRENA donne ses établissements actifs, classes, enseignants, élèves et élèves actifs
  Et les DRENA sont triées par nombre d'élèves décroissant, puis par nom

Scénario: inscrits récents sans numéro complet
  Étant donné 12 comptes
  Alors les 10 plus récents s'affichent avec rôle, établissement et date
  Et leur numéro est masqué : seuls les deux premiers et les deux derniers chiffres se lisent

Scénario: lectures bornées
  Quand le volume de DRENA, d'établissements, d'élèves et de sessions triple
  Alors le nombre de requêtes du pilotage ne change pas

# test/infrastructure/queries/identity/account_search_query_test.rb
Scénario: rechercher un élève ou un enseignant (TR-11)
  Étant donné l'élève « Aya Kouassi » en Tle D 1 au Lycée Classique et l'enseignant « Yao Kouadio »
  Quand l'équipe cherche « koua »
  Alors les deux apparaissent, triés par nom, avec rôle, établissement et classe
  Et un membre de l'équipe, une direction et un compte anonymisé n'apparaissent jamais
  Quand elle cherche 4 chiffres du numéro
  Alors le compte qui les porte apparaît, numéro masqué
  Quand elle cherche « a » ou « 12 »
  Alors aucune recherche n'est faite
  Quand 25 comptes correspondent
  Alors la première page en montre 20 et la seconde 5
  Et le nombre de requêtes ne dépend pas du nombre de résultats

# test/controllers/teams/dashboards_controller_test.rb
Scénario: accès
  Un enseignant, un élève et une direction reçoivent 403 ; un visiteur va à la connexion

Scénario: page et filtres
  Le membre de l'équipe voit les chiffres clés, la période choisie marquée courante, la DRENA choisie sélectionnée
  Une recherche servie au frame « team_dashboard_search » ne rend que les résultats

# test/system/teams/dashboard_test.rb
Scénario: ouvrir « Pilotage » depuis la navigation, filtrer par DRENA, chercher un élève
  Au bureau (1280 px) puis sur un téléphone (390 px), sans défilement horizontal de la page

# test/system/role_homes_test.rb
Scénario: la navigation de l'équipe n'a plus d'entrée inactive
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::School::ReportingPeriod` (valeur), `Entities::Identity::Contact.mask`, `Policies::School::ReadIndicatorsPolicy`. Aucun use case : lecture seule (CQRS, ADR-0006) |
| Infrastructure | `Queries::School::TeamDashboardQuery`, `Queries::Identity::AccountSearchQuery`. Aucune migration, aucune table, aucun index |
| Delivery | `get "teams/dashboard"` → `Teams::DashboardsController#show` (`team_dashboard_path`, nom gelé par l'UDR-0006) |
| UI | `teams/dashboards/show` et ses partials, `Teams::DashboardsHelper` (largeur des barres), locale `teams.dashboards` |

## 6. Décisions rattachées

- [ADR-0062](../../decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md) — indicateurs de pilotage lus en direct par deux queries, définitions métier, lectures bornées.
- [UDR-0049](../../decisions/udr/0049-page-pilotage-de-l-equipe.md) — page « Pilotage ».
- Amendements datés de l'[UDR-0006](../../decisions/udr/0006-shell-applicatif-par-role.md) et de l'[UDR-0018](../../decisions/udr/0018-accueil-equipe.md) : l'entrée « Pilotage » devient active.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL pour afficher le pilotage | page inexistante | constant quel que soit le volume | voir `journal.md` |
| JavaScript ajouté | — | 0 octet | 0 octet |
| CSS (gzip) | voir `journal.md` | ≤ 30 Ko | voir `journal.md` |
