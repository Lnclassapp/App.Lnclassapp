# Journal — Croissance par parrainage, démarrage à froid et mesure du k-factor

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Défauts appliqués sans arbitrage : badge à 3 filleuls, 5 demandes en attente par établissement, un seul garant, compte refusé conservé, nom du parrain non affiché | Le porteur a demandé d'avancer ; chaque défaut est listé « à confirmer » dans le memo | Oui — ADR-0063, UDR-0050 (statut *Proposé*) |
| 2026-09-28 | Table `referrals` plutôt que `users.referred_by_id` | Source (lien / garant), date et établissement lisibles par les métriques ; `users` inchangé | Oui — ADR-0063 §3 |
| 2026-09-28 | Jeton de parrainage tiré par la base (`DEFAULT`), pas par le domaine | Aucun chemin d'écriture à toucher (inscription, seeds, fabriques, existant) ; le jeton n'a pas de sens métier | Oui — ADR-0063, coût consenti |
| 2026-09-28 | Compte en attente = enseignant sans `teacher_schools` + ligne `school_join_requests` | L'écran d'attente existait déjà pour « enseignant sans école » (ADR-0030) | Oui — ADR-0063 §3 H |
| 2026-09-28 | Audit des décisions sous `school.changed` (`change: join_request_*`), sans nouvelle action d'audit | Même forme que la régénération du code (ADR-0057) ; la liste fermée n'est pas touchée (le chantier photo-de-profil la modifie aussi) | Non |
| 2026-09-28 | Partage compté par `navigator.sendBeacon` sur un vrai lien | Le lien s'ouvre même si l'envoi échoue ; aucune redirection vers un domaine tiers depuis notre serveur | Oui — ADR-0063 §4 |

## Ce qui a dérapé

*(rempli pendant l'exécution)*

## Mesures

*(rempli pendant l'exécution)*

## Ce qu'on a appris sur la codebase

*(rempli pendant l'exécution)*

## Dette laissée derrière

*(rempli à la clôture)*

## Clôture

| | |
|---|---|
| **Livré le** | — |
| **PR** | *(ouverte par le coordinateur)* |
| **ADR produits** | ADR-0063 ; amendements ADR-0057, ADR-0030 |
| **UDR produits** | UDR-0050 |
