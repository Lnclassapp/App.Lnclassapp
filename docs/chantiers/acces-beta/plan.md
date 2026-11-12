# Plan — Accès complet gratuit pendant la bêta

Un seul lot : le changement tient en un réglage, un statut et deux partials.

## Lot A — bêta ouverte

| Champ | Valeur |
|---|---|
| **Dépend de** | — |
| **Fichiers** | `app/domain/entities/billing/{offer,access}.rb`, `app/views/billing/subscriptions/{_home_notice,_status}.html.erb`, `config/locales/billing/subscriptions.fr.yml`, tests billing, `test/support/billing_beta_helper.rb` |
| **Tests** | `test/domain/entities/billing/access_test.rb`, `test/integration/billing/free_period_test.rb` (classe `BillingBetaAccessTest`), `test/infrastructure/queries/billing/student_access_query_test.rb` |
| **Porte** | tests billing verts, `bin/ci-quiet` vert |

## Collisions

Aucun lot parallèle.

## Décisions ouvertes

Aucune avant lancement : la décision du porteur est prise. Les suites sont dans `journal.md` § À trancher.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle (sans objet : aucun port)
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/` (aucun fichier créé)
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
