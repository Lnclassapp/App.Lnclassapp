# Plan d'exécution — Entonnoir AARRR des élèves

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Une seule session, une seule PR vers `Develop` : les deux lots sont séquentiels (le lot 2 réutilise la query du lot 1), un commit chacun.

## Graphe

```
Lot 1 — SOCLE + ENTONNOIR BRUT (query + tâche rake de lecture seule)
  ↓
Lot 2 — ÉCRAN (section « Élèves : entonnoir AARRR » de la page Croissance)
```

---

## Lot 1 — Socle et entonnoir brut

- **Couche**       : infrastructure (query CQRS) + tâche rake
- **Fichiers**     : `app/infrastructure/queries/identity/student_funnel_query.rb` (contrat gelé : `weekly(from:, to:)`, `call(from:, to:, now:)`, `Report`, `WeekRow`, `Steps`, `Cohort`, `Revenue`)
                     `lib/tasks/entonnoir.rake` (`entonnoir:brut`)
                     `test/infrastructure/queries/identity/student_funnel_query_test.rb`
                     `test/tasks/entonnoir_task_test.rb`
                     docs du chantier (memo, prd, plan, journal) et UDR
- **Dépend de**    : —
- **Test associé** : les critères « Entonnoir brut » et « Définitions » du PRD §5
- **Done quand**   : `bin/rails entonnoir:brut` imprime l'entonnoir par semaine et par voie sur une base de test, dans une transaction `READ ONLY`, sans nom ni numéro ; requêtes en nombre fixe

---

## Lot 2 — Écran

- **Couche**       : delivery + ui
- **Fichiers**     : `app/controllers/teams/growth_controller.rb`
                     `app/views/teams/growth/show.html.erb` · `app/views/teams/growth/_funnel.html.erb`
                     `config/locales/teams/growth.fr.yml`
                     `test/controllers/teams/growth_controller_test.rb` · `test/system/teams/growth_test.rb`
- **Dépend de**    : Lot 1
- **Test associé** : les critères « Écran » du PRD §5
- **Done quand**   : un compte équipe voit les cinq étages + « Non mesuré » à 390 px et sur ordinateur ; un enseignant est refusé ; captures envoyées au porteur

---

## Décisions ouvertes

Aucune bloquante : les décisions réversibles prises par défaut sont dans `journal.md` § À trancher.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/infrastructure/queries/identity/student_funnel_query.rb` | Lot 1 |
| `lib/tasks/entonnoir.rake` | Lot 1 |
| `app/controllers/teams/growth_controller.rb` | Lot 2 |
| `app/views/teams/growth/**` | Lot 2 |
| `config/locales/teams/growth.fr.yml` | Lot 2 |
| Fichiers du chantier `activation-eleve` (`student_homes`, `student_registrations`, `catalog/courses`) | **aucun lot — interdits** |

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
