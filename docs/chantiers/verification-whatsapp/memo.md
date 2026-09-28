# Memo — Vérifier le numéro par WhatsApp à l'inscription sans code

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | backlog *(mis de côté par le porteur le 2026-09-28, grill interrompu à la question 2)* |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/verification-whatsapp` *(à créer à la reprise)* |
| **Programme** | — |

---

## Le problème

L'inscription sans code (chantier [`croissance-parrainage`](../croissance-parrainage/memo.md), ADR-0063) ne prouve pas le numéro de téléphone :

- les codes nationaux des établissements sont publics : un tiers peut occuper les **5 places** de demandes en attente d'un établissement (constat M1 du challenger, accepté par le porteur) ;
- n'importe qui peut réserver le numéro d'un tiers.

## Piste retenue par le porteur

Envoyer un code de vérification par **WhatsApp**, via un **hook n8n**, avant qu'une demande n'entre dans la file de l'établissement.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| 1. Chantier séparé ou fusionné avec [`canal-whatsapp`](https://github.com/Lnclassapp/App.Lnclassapp/pull/70) (annonces, récupération du PIN) ? | **Chantier séparé, port commun.** | Ce chantier pose le port d'envoi (contexte `communication`) et l'adaptateur n8n ; `canal-whatsapp` les réutilise ensuite. |
| 2. Quels comptes vérifient leur numéro ? | *Non répondue* : le porteur a mis la fonctionnalité au backlog. | Reprendre le grill ici. |

## Questions encore ouvertes (reprise du grill)

2. Quels comptes vérifient leur numéro : l'inscription sans code seulement, tous les enseignants, ou tous les comptes ?
3. Fournisseur derrière n8n (API WhatsApp Business de Meta), modèles de message à faire approuver, coût par message et qui le paie.
4. Numéro sans WhatsApp : repli (SMS, validation par l'équipe) ou refus ?
5. Code : longueur, durée de validité, nombre d'essais, limite d'envois par numéro et par IP (abus de facturation).
6. Sécurité du hook : signature (HMAC) dans les deux sens, hébergement de n8n, données transmises (numéro et code seulement).
7. Une demande non vérifiée compte-t-elle dans les 5 places ?
