# PRD — Rétention de l'adresse IP du journal d'audit

| | |
|---|---|
| **Chantier** | `retention-ip-audit` — cycle feature |
| **Memo** | [`memo.md`](memo.md) |
| **Décisions** | [ADR-0080](../../decisions/adr/0080-retention-de-l-ip-du-journal-d-audit.md) |

## 1. Contexte

Le journal d'audit garde l'IP de chaque événement sans limite. Une tâche quotidienne efface l'IP des événements de plus de 12 mois, pour tous les comptes ; les événements restent.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Le système (tâche planifiée) | Effacer l'IP des événements de plus de 12 mois | Toucher un autre champ, supprimer un événement |
| Équipe, direction, enseignant, élève | — | Déclencher l'effacement (aucun écran, aucune route) |

Règle : `Policies::Identity::EraseAuditIpsPolicy` n'autorise que le système (acteur `nil`).

## 3. Parcours

### Chemin nominal

1. Chaque jour à 4 h 30 (production), `Identity::EraseAuditIpsJob` lance `UseCases::Identity::EraseAuditIps` avec l'échéance `maintenant − 12 mois`.
2. Les événements créés avant l'échéance perdent leur `ip_address`, par lots de 1 000.
3. Le nombre d'événements traités est journalisé dans les logs, zéro compris.

### Chemins alternatifs

| Situation | Comportement attendu |
|---|---|
| Aucun événement échu | 0, rien n'est écrit |
| Une personne connectée appelle le use case | `:forbidden`, rien n'est écrit |
| Seconde exécution le même jour | 0 |

## 4. Critères d'acceptation

```gherkin
# RI-01
Étant donné un événement d'audit créé il y a 12 mois et 1 jour avec une IP, et un autre créé il y a 11 mois
Quand la tâche quotidienne tourne
Alors le premier n'a plus d'IP, et garde son action, son acteur, son sujet, ses métadonnées et sa date
Et le second garde son IP

# RI-02
Étant donné 2 500 événements échus avec une IP
Quand la tâche tourne
Alors les 2 500 perdent leur IP, en trois lots, et le nombre 2 500 est journalisé

# RI-03
Quand la tâche tourne une seconde fois
Alors elle traite 0 événement et le journalise

# RI-04
Quand un membre de l'équipe appelle l'effacement
Alors il est refusé (:forbidden) et rien n'est écrit

# RI-05
Alors la tâche est déclarée en production dans config/recurring.yml, chaque jour à 4 h 30
```

## 5. Modélisation

| Couche | Éléments |
|---|---|
| Domaine | `Ports::Identity::AuditLogPort#erase_ips_before(at:, batch_size:)` ; `UseCases::Identity::EraseAuditIps` ; `Policies::Identity::EraseAuditIpsPolicy` ; `Entities::Identity::AuditRetention::IP_MONTHS = 12` |
| Infrastructure | Migration : index partiel `audit_events(created_at) WHERE ip_address IS NOT NULL` ; `AuditLogRepository#erase_ips_before` ; `Identity::EraseAuditIpsJob` ; `config/recurring.yml` |
| Delivery, UI | — |

## 6. Décisions rattachées

- ADR-0080 : rétention de 12 mois de l'IP du journal d'audit. Elle tranche la question 2 de l'ADR-0036 pour le journal.
- Pas d'UDR : aucune vue ne change.
