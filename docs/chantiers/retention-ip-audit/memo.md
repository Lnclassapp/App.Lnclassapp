# Memo — Rétention de l'adresse IP du journal d'audit

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-10-05 |
| **Branche** | `feature/retention-ip-audit` |
| **Programme** | — |

---

## Le problème

Le journal d'audit (`audit_events`) enregistre l'adresse IP de chaque événement : connexion verrouillée, inscription, retrait, suppression… Il la garde sans limite. Supprimer un compte ne l'efface pas non plus : l'ADR-0036 §4 garde le journal tel quel et laissait ouverte la question de l'IP (« Questions à trancher », 2).

## Pour qui

Toute personne dont un événement est journalisé : élève, enseignant, direction, équipe. L'équipe, qui enquête sur un incident, a besoin de l'IP récente.

## Pourquoi maintenant

La revue de sécurité d'`inscription-direction` a relevé que l'IP reste après la suppression d'un compte. Le porteur a tranché le 2026-10-04.

## Hors périmètre

- L'IP des sessions (`sessions.ip_address`) et des tentatives de connexion (`login_attempts.ip_address`) : d'autres tables, avec leurs propres rétentions (ADR-0036 §4 et la suppression du compte les effacent déjà).
- La suppression des événements eux-mêmes : ils restent. Seule leur IP est effacée.
- Une rétention différente selon l'action ou le rôle.
- Un écran : rien ne change à l'interface.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| À la suppression d'un compte, que devient l'IP de ses lignes du journal ? | Porteur, 2026-10-04 : « Gardée 12 mois puis effacée », pour tous les comptes | Une règle de rétention générale, pas un effacement à la suppression. Une tâche quotidienne |
| 12 mois à partir de quoi ? | De la date de l'événement (`created_at`) | Un seul seuil, sans dépendre de l'état du compte |
| Les autres colonnes du journal (acteur, sujet, métadonnées) ? | Elles restent : elles ne portent ni numéro ni nom (ADR-0050, « sans aucun secret ») | Seule `ip_address` est vidée |
| Volume ? | Le journal grandit avec chaque inscription et chaque geste d'équipe | Effacement par lots et index partiel sur les lignes qui ont encore une IP |

## Cas limites identifiés

- Un événement d'exactement 12 mois : il est effacé dès qu'il a dépassé l'échéance (`created_at < now - 12 mois`).
- Un événement sans IP (actions du système) : il est ignoré.
- Une seconde exécution le même jour : elle n'efface rien de plus.
- Des centaines de milliers de lignes au premier passage : elles sont traitées par lots de 1 000, sans verrou long.

## Questions encore ouvertes

- Aucune.
