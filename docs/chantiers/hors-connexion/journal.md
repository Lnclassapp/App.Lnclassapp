# Journal — Lnclass hors connexion

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-12 | Jeton signé du paquet (pas de table d'ouverture) | Borne l'heure et lie la copie à l'élève sans écrire en base | ADR §4.4 |
| 2026-11-12 | Synchro dans un contrôleur distinct de la copie hors ligne | Lots B et C parallèles sans fichier commun | Non (plan) |
| 2026-11-12 | Enseignant en lecture seule | Aucune correction manuelle n'existe (ADR-0115 option E) | ADR §4.6 |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-12 · hors-connexion · Quelle heure fait foi pour une copie rendue hors ligne ? — appliqué : heure du téléphone bornée dans [émission du paquet, réception], 30 jours au plus, heure de réception gardée et montrée à l'enseignant ; autres : heure de réception seule, heure du téléphone sans borne ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Exercice modifié entre l'ouverture et l'envoi : que devient la copie ? — appliqué : refusée, montrée « non comptée » ; autres : corriger les seules questions encore présentes ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Accès (bêta, abonnement) évalué quand ? — appliqué : à la réception, copie `locked` gardée en file 30 jours ; autres : à l'heure d'origine (horloge non fiable) ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · L'enseignant peut-il écrire hors ligne ? — appliqué : non, lecture seule (rien à corriger aujourd'hui) ; autres : file d'écritures enseignant avec résolution de conflits ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Combien garder ? — appliqué : 60 pages par compte, 30 jours ; autres : 30 pages, 7 jours ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Entraînement de notion (« Vérifier » dans la leçon) hors ligne ? — appliqué : non (réseau demandé, hors ADR) ; autres : corrigé de l'entraînement dans le paquet ; recommandé : chantier de suivi

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Entraînement de notion hors ligne | ADR-0119 garde le corrigé de l'entraînement sur le serveur | `hors-connexion-entrainement` |
| Images `no-store` hors ligne | Servies privées, non gardables sans revoir ADR-0031 | à ouvrir |
| WebView Android et programme d'arrière-plan | Non vérifiable dans le dépôt | selon le challenger du Lot A |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
