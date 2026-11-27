# Journal — Notifications envoyées dès l'événement

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-27 | Médaille : plus de délai de 2 h ; elle part tout de suite, sauf si l'élève est revenu dans l'application depuis (option b, porteur). Copie hors ligne corrigée : tout de suite. | Décision du porteur | ADR-0147 amendement II |
| 2026-11-27 | Le passage est demandé après le commit de la transaction (`ActiveRecord.after_all_transactions_commit`) ; une transaction annulée n'enfile rien | Le passage doit lire l'événement enregistré | Non |
| 2026-11-27 | Une assignation d'un seul exercice (`AssignResource`) demande aussi le passage, en plus de l'envoi groupé | « Exercice assigné » couvre les deux chemins ; le plan ne citait que l'envoi groupé | Non |
| 2026-11-27 | `PushApprovalRepository` ne garde que `history` et `purge_before` ; `for_date` et `create` retirés | Plus aucune validation n'est écrite ; l'historique et la purge restent | Non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-27 · envoi-immediat-notifications · Annonce : part seulement si sa case « Annonce de l'équipe » est cochée ET « Prévenir les élèves » cochée à la publication — appliqué : les deux conditions (le porteur n'avait pas de préférence) ; autres : « Prévenir les élèves » seul ; recommandé : appliqué.
- [ ] 2026-11-27 · envoi-immediat-notifications · « Exercice commencé » (unfinished) gardé, case décochée au départ (aucune ligne en base = décoché) — appliqué : gardé décoché ; autres : le retirer ; recommandé : appliqué.
- [ ] 2026-11-27 · envoi-immediat-notifications · Après le déploiement, toutes les cases sont décochées sauf celles déjà cochées avant (interro, devoir à rendre, exercice assigné) : rien d'autre ne part tant qu'un admin ne coche pas — appliqué : aucune case cochée d'office ; autres : cocher les événements à la migration ; recommandé : appliqué.

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `Entities::Communication::PushApproval` lit `PushMotive::PLANNABLE` : la constante reste pour relire les validations passées.
- Les seeds (`db/seeds/standard/activite.rb`) construisent `AssignResource` et `CloseExerciseSession` : ils reçoivent un passage qui ne fait rien, le jeu de données n'envoie aucune notification.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
