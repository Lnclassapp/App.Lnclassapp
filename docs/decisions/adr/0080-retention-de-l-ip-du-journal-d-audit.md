# ADR-0080 : L'adresse IP du journal d'audit est gardée 12 mois, puis effacée par une tâche quotidienne

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-04 : « Gardée 12 mois puis effacée »)* |
| **Date** | 2026-10-05 |
| **Chantier** | `docs/chantiers/retention-ip-audit` |
| **Remplace** | — *(tranche la question 2 de l'ADR-0036, « Questions à trancher », pour le journal d'audit)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

`audit_events.ip_address` est écrite par `AuditLogRepository#record` pour les événements qui viennent d'une requête : inscription, verrouillage de connexion, gestes de l'équipe et de la direction. Elle n'est jamais effacée. L'ADR-0036 §4 garde le journal à la suppression d'un compte « sans donnée effacée » et laissait ouverte la question : « L'adresse IP des sessions, des tentatives et du journal ? ». La revue de sécurité d'`inscription-direction` a relevé qu'après la suppression d'un compte, son IP reste dans le journal.

## 2. Moteurs de décision

1. Ne pas garder indéfiniment une donnée personnelle sans usage.
2. Garder assez longtemps l'IP pour enquêter sur un incident (abus du plafond, retraits en série, tentatives de connexion).
3. Une seule règle, simple à vérifier, quel que soit l'état du compte.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Effacer l'IP à la suppression du compte | Ciblée | Les comptes actifs gardent leur IP sans limite ; une enquête sur un compte supprimé perd tout (non retenue par le porteur) |
| B — Garder l'IP sans limite | Enquêtes toujours possibles | Donnée personnelle sans échéance |
| C — Garder 12 mois, puis effacer, pour tous | Une seule règle, et une fenêtre d'enquête d'un an | **Retenue** |

## 4. Décision

> **Nous effaçons chaque jour l'adresse IP des événements d'audit créés il y a plus de 12 mois, quel que soit le compte. L'événement reste ; seule `ip_address` devient nulle.**

- `Entities::Identity::AuditRetention::IP_MONTHS = 12`.
- `Ports::Identity::AuditLogPort#erase_ips_before(at:, batch_size:)` vide `ip_address` des lignes avec `created_at < at` qui en ont une. L'effacement se fait par lots de `batch_size`, chacun dans sa propre requête, et le port renvoie le nombre de lignes traitées.
- `UseCases::Identity::EraseAuditIps#call(at:, actor: nil)`, avec `Policies::Identity::EraseAuditIpsPolicy` (le système seul, acteur `nil`).
- `Identity::EraseAuditIpsJob` est déclaré dans `config/recurring.yml` (production), `every day at 4:30am`, avec `at = now − 12 mois` et des lots de 1 000.
- Un index partiel `audit_events (created_at) WHERE ip_address IS NOT NULL` évite de parcourir tout le journal chaque nuit.

## 5. Conséquences

### 🟢 Positives

- Plus aucune IP de plus d'un an dans le journal, y compris pour un compte supprimé.
- L'enquête sur un incident récent reste possible.

### 🔴 Coûts consentis

- Au-delà de 12 mois, on ne sait plus d'où venait un geste : seuls l'auteur et la date restent.
- Un index de plus sur `audit_events`, et une écriture par ligne échue à la première exécution, en lots.
- Les IP des sessions et des tentatives de connexion n'entrent pas dans cette règle. Elles relèvent d'autres tables, déjà effacées avec le compte supprimé (ADR-0036 §4, ADR-0077 §4.3).

## 6. Notes d'implémentation

```ruby
# app/infrastructure/repositories/identity/audit_log_repository.rb
def erase_ips_before(at:, batch_size:)
  erased = 0
  loop do
    ids = Orm::AuditEvent.where(created_at: ...at).where.not(ip_address: nil).limit(batch_size).pluck(:id)
    break erased if ids.empty?

    erased += Orm::AuditEvent.where(id: ids).update_all(ip_address: nil)
  end
end
```

## 7. Comment vérifier que la décision est respectée

- `test/jobs/identity/erase_audit_ips_job_test.rb` : un événement de 12 mois et 1 jour perd son IP et garde le reste ; un événement de 11 mois garde la sienne.
- `test/infrastructure/repositories/identity/audit_log_repository_test.rb` : 2 500 lignes échues sont traitées en trois lots.
- `test/jobs/recurring_tasks_test.rb` : la tâche est déclarée en production.
- `test/architecture/port_contracts_test.rb` : l'adaptateur implémente `erase_ips_before`.
