# Plan d'exécution — Pilotage de l'équipe

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — SOCLE : route, navigation, locale, période, masque du numéro, policy
  ↓
  Lot A — Indicateurs, répartition, couverture, inscrits (page Pilotage)
  ↓
  Lot B — Recherche d'un élève ou d'un enseignant (TR-11), dans la page du lot A
```

Le lot B est **séparé** parce que la recherche est un cas d'usage distinct (TR-11) avec sa query, sa policy et ses tests ; il **dépend** du lot A parce qu'il vit dans le même contrôleur et la même vue. Aucun parallélisme : un seul exécutant, trois lots en série dans le worktree du chantier.

---

## Lot 0 — Socle

- **Couche**       : domaine + delivery (fichiers partagés)
- **Fichiers**     : `config/routes/teams.rb` · `config/locales/teams/dashboards.fr.yml` *(nouveau)*
                     `app/domain/entities/school/reporting_period.rb`
                     `app/domain/entities/identity/contact.rb` (`Contact.mask`)
                     `app/domain/policies/school/read_indicators_policy.rb`
                     `test/system/role_homes_test.rb` (« Pilotage » actif)
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/school/reporting_period_test.rb` · `test/domain/entities/identity/contact_test.rb` · `test/domain/policies/school/read_indicators_policy_test.rb`
- **Done quand**   : la période, le masque et la policy sont verts ; `team_dashboard_path` est dessinée

---

## Lot A — Indicateurs de la page Pilotage

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/school/team_dashboard_query.rb`
                     `app/controllers/teams/dashboards_controller.rb`
                     `app/helpers/school/dashboard_helper.rb`
                     `app/views/teams/dashboards/show.html.erb` · `_filters` · `_key_figures` · `_levels` · `_drenas` · `_recent_signups`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/school/team_dashboard_query_test.rb` · `test/controllers/teams/dashboards_controller_test.rb` · `test/helpers/school/dashboard_helper_test.rb` · `test/system/teams/dashboard_test.rb`
- **Done quand**   : un membre de l'équipe ouvre « Pilotage » depuis la navigation, voit les chiffres, change de période et filtre par DRENA, au bureau et à 390 px ; le nombre de requêtes est constant

---

## Lot B — Recherche d'un élève ou d'un enseignant (TR-11)

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/identity/account_search_query.rb`
                     `app/views/teams/dashboards/_search.html.erb` · `_search_results.html.erb`
                     *(et, en série après le lot A : l'action de recherche de `dashboards_controller.rb`)*
- **Dépend de**    : Lot A
- **Test associé** : `test/infrastructure/queries/identity/account_search_query_test.rb` · recherche dans `dashboards_controller_test.rb` et `test/system/teams/dashboard_test.rb`
- **Done quand**   : l'équipe trouve un élève par un morceau de son nom ou de son numéro, 20 résultats par page, numéro masqué, sans recalcul des indicateurs

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb` | Lot 0 |
| `config/locales/teams/dashboards.fr.yml` | Lot 0 |
| `test/system/role_homes_test.rb` | Lot 0 |
| `app/controllers/teams/dashboards_controller.rb` | Lot A, puis Lot B **en série** (dépendance, pas de parallélisme) |
| `test/controllers/teams/dashboards_controller_test.rb`, `test/system/teams/dashboard_test.rb` | Lot A, puis Lot B en série |

**Avec les chantiers parallèles** (code d'établissement, barème des classes, classes par niveau, cycles en boutons radio, photo de profil, menu « Classes » sur `/teams/schools`) : ce chantier ne touche ni la fiche établissement, ni les formulaires de niveau ou d'établissement, ni le profil, ni `teams/schools/index`. Fichiers communs possibles : `docs/decisions/adr/README.md`, `docs/decisions/udr/README.md`, `docs/features-refonte.md` (une ligne chacun), `app/domain/entities/identity/contact.rb` (méthode ajoutée en fin de module).

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR-0062 écrit, indexé dans `decisions/adr/README.md`
- [x] UDR-0049 écrite, indexée dans `decisions/udr/README.md` ; UDR-0006 et UDR-0018 amendées
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests (100 %) · système · brakeman · budget d'assets : au vert
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
