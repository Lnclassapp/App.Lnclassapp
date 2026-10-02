# Memo — Validation des enseignants en pause

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-02 |
| **Branche** | `ccr-93a43a40-3h3ty4` *(branche imposée par la session, repartie de `Develop` le 2026-10-02 après la fusion de la PR #142)* |
| **Programme** | — |

---

## Le problème

Un enseignant qui s'inscrit sans le code secret de son établissement (il choisit son établissement par le code national ou dans la liste de sa DRENA) n'accède à rien tant que l'équipe ou un collègue garant ne l'a pas validé. Tant que l'équipe n'a pas atteint les établissements et que peu d'enseignants y sont actifs, personne ne valide : le nouvel inscrit reste bloqué sur l'écran d'attente, et chaque établissement ne peut pas avoir plus de 5 demandes en attente.

Ce verrou freine le démarrage à froid que le parrainage devait permettre.

## Pour qui

- **L'enseignant** qui s'inscrit sans code : il veut utiliser Lnclass tout de suite.
- **L'équipe** : elle ne veut plus trier les demandes une par une pour l'instant.
- **Les collègues et la direction** : ils n'ont plus de demande à valider pendant la pause.

## Pourquoi maintenant

Le porteur l'a décidé le 2026-10-02 : la validation est mise en pause. Elle reviendra plus tard sous le nom de **certification**, menée DRENA par DRENA à une période donnée, par les collègues et les directions, **avant le premier versement aux enseignants**.

## Hors périmètre

- **La certification elle-même** (campagne par DRENA, validation par les collègues et les directions, lien avec les versements) : chantier suivant, à ouvrir quand le porteur fixera la période.
- Les versements aux enseignants.
- L'inscription avec le code secret de l'établissement ou par un lien de parrainage : inchangée.
- L'inscription des élèves et le rattachement de la direction : inchangés.

## Ce que le grill a révélé

> Le porteur a donné la règle (« mettre en pause la partie validation des comptes […] il faut qu'il arrive à son moment *aha* le plus rapidement possible ») puis a demandé d'arrêter les questions. Les réponses ci-dessous sont des **choix par défaut** de l'agent, retenus pour aller au plus vite vers l'usage ; le porteur peut les changer.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que veut assouplir le porteur ? | Pause complète de la validation ; plus tard, une **certification** par DRENA, faite par les collègues et les directions, avant le premier versement aux enseignants. | Un enseignant inscrit sans code est rattaché à son établissement dès l'inscription. La certification est un chantier suivant. |
| Où arrive l'enseignant après l'inscription ? *(défaut)* | Là où arrive un enseignant inscrit par code : la sélection de ses classes, avec « Bienvenue ! ». | Plus d'écran d'attente pour les nouveaux inscrits ; le parcours vers le premier exercice assigné est le même pour tous. |
| Faut-il garder une trace de ceux qui n'ont pas été validés ? *(défaut)* | Oui : la demande reste enregistrée, validée « automatiquement », sans décideur. | Une nouvelle voie de décision, « automatique ». La future certification saura qui s'est inscrit sans code. |
| Et les demandes déjà en attente ? *(défaut)* | Validées de la même façon au déploiement, l'enseignant rattaché. Les demandes refusées restent refusées : c'était une décision de l'équipe. | Une étape de données dans la mise à jour de la base. |
| Le lien « Inviter un collègue » porte le code secret de l'établissement : faut-il le cacher aux inscrits sans code ? *(défaut)* | Non. Pendant la pause, le code secret ne protège plus rien : n'importe qui rejoint n'importe quel établissement sans lui. Le cacher freinerait le parrainage sans rien protéger. | Aucun changement de l'invitation. À la reprise de la validation, l'équipe régénérera les codes des établissements concernés (dette notée). |
| Le plafond de 5 demandes en attente par établissement ? | Plus aucune demande ne reste en attente : le plafond ne bloque plus personne. Il reste dans le code, prêt pour la certification. | Rien à retirer. |
| Acteurs oubliés : direction, équipe, collègues ? | La direction voit le nouvel enseignant comme les autres et peut le retirer (gestes existants). L'équipe peut le retirer depuis la fiche. Les collègues n'ont plus de demande à confirmer. | Aucune vue nouvelle ; la section « Enseignants en attente » et la carte des collègues en attente restent, vides. |

## Cas limites identifiés

- Un enseignant déjà rattaché à une école principale qui avait encore une demande en attente : sa demande est validée, son école principale ne change pas.
- Deux inscriptions simultanées dans le même établissement : chacune est rattachée, aucune ne reste en attente.
- Un compte refusé avant la pause reste sur l'écran d'attente ; il peut toujours rejoindre un établissement par son code secret.
- Un faux enseignant qui choisit un établissement au hasard y est rattaché : la direction ou l'équipe le retirent ; la certification le filtrera avant tout versement.

## Questions encore ouvertes

- Période, DRENA par DRENA, et règles de la **certification** (qui certifie, combien de garants, effet sur les versements) : chantier suivant.
