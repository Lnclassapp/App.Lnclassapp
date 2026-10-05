# Plan d'exécution — Rétention de l'adresse IP du journal d'audit

Un seul lot, séquentiel : une migration d'index, un port étendu, un use case et sa policy, un job, une tâche planifiée. Aucun fichier n'est partagé avec un autre lot.

## Lot 0 — Effacer l'IP des événements de plus de 12 mois

- **Couche**       : domaine + infrastructure
- **Fichiers**     :
  - `db/migrate/20261005090000_add_ip_retention_index_to_audit_events.rb`, `db/schema.rb`
  - `app/domain/entities/identity/audit_retention.rb`
  - `app/domain/ports/identity/audit_log_port.rb`
  - `app/infrastructure/repositories/identity/audit_log_repository.rb`
  - `app/domain/policies/identity/erase_audit_ips_policy.rb`
  - `app/domain/use_cases/identity/erase_audit_ips.rb`
  - `app/jobs/identity/erase_audit_ips_job.rb`
  - `config/recurring.yml`
  - les faux `AuditLogPort` des tests, qui doivent implémenter la nouvelle méthode (`test/architecture/port_contracts_test.rb` ne porte que sur les adaptateurs ; les faux restent libres)
- **Dépend de**    : —
- **Test associé** :
  - `test/infrastructure/repositories/identity/audit_log_repository_test.rb`
  - `test/domain/use_cases/identity/erase_audit_ips_test.rb`
  - `test/domain/policies/identity/erase_audit_ips_policy_test.rb`
  - `test/jobs/identity/erase_audit_ips_job_test.rb`
  - `test/jobs/recurring_tasks_test.rb`
- **Couvre**       : RI-01 à RI-05
- **Done quand**   : la tâche, lancée à la main, efface l'IP d'un événement de 12 mois et 1 jour, garde celle d'un événement de 11 mois, et journalise le nombre traité

## Vérification de collision

Un seul lot : pas de collision possible.

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
