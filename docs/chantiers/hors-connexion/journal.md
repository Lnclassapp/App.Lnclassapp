# Journal — Lnclass hors connexion

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-12 | Jeton signé du paquet (pas de table d'ouverture) | Borne l'heure et lie la copie à l'élève sans écrire en base | ADR §4.4 |
| 2026-11-12 | Synchro dans un contrôleur distinct de la copie hors ligne | Lots B et C parallèles sans fichier commun | Non (plan) |
| 2026-11-12 | Enseignant en lecture seule | Aucune correction manuelle n'existe (ADR-0115 option E) | ADR §4.6 |
| 2026-11-12 | Lot 0 : les deux méthodes du port des sessions (`record_offline_copy`, `find_by_client_copy_id`) sont **implémentées** dans l'adaptateur dès le Lot 0, pas laissées au Lot C | `test/architecture/port_contracts_test.rb` exige que l'adaptateur définisse toute méthode du port : un port gelé sans adaptateur casse la CI. Le Lot C n'a plus qu'à les appeler (et à compléter les tests de rejeu concurrent) | Non |
| 2026-11-12 | Lot 0 : étape Node `Tests: Node (JavaScript)` placée dans le groupe `lint`, entrées limitées à `test/javascript/`, `app/javascript/`, `package.json`, `config/ci.rb` | Pas de base de données ni de navigateur ; rejouée seulement quand le JavaScript bouge | Non |
| 2026-11-12 | Lot C : l'empreinte courante est **injectée** dans `SyncOfflineCopy` (`current_digest`, callable `exercise → String`) ; défaut `SyncOfflineCopy.digest_for` (adaptateur minimal) | Le Lot B calcule l'empreinte par `Queries::Assessment::OfflinePackQuery`. Le contrôleur la câble dès que la constante existe (`defined?`), sinon le défaut | Non |
| 2026-11-12 | Lot C : les indices `display_order` / `blanks` d'une copie en file se rapportent au mélange `AnswerShuffle` de graine **l'identifiant de l'exercice** (ordre porté en clair par le paquet) ; le serveur les ramène aux identifiants avec la même graine, comme `SubmitExerciseCopy` avec la session | Pas de session hors ligne ; même règle que la copie en ligne | Non |
| 2026-11-12 | Lot C : une réponse mal formée (hors bornes, texte trop long) n'est pas rangée par l'appareil ; le serveur la compte non répondue (copie rangée). Seules une copie illisible ou une question étrangère refusent la copie (`invalid`) | Alignement sur le Lot B | Non |
| 2026-11-12 | Lot C : `Shared::Result` n'a pas de code `wrong_owner`/`stale`/`paused`/`already_synced` ; le use case rend `:forbidden` / `:conflict` avec `errors[:base]` (`wrong_owner`, `stale`, `paused`, `subscription_required`, `not_published`), et `already_synced` est un succès (`Synced#already_synced`) | `Shared::Result` est partagé et hors de la fiche ; le contrôleur ramène ces faits aux six motifs de la file | Non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-12 · hors-connexion · Quelle heure fait foi pour une copie rendue hors ligne ? — appliqué : heure du téléphone bornée dans [émission du paquet, réception], 30 jours au plus, heure de réception gardée et montrée à l'enseignant ; autres : heure de réception seule, heure du téléphone sans borne ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Exercice modifié entre l'ouverture et l'envoi : que devient la copie ? — appliqué : refusée, montrée « non comptée » ; autres : corriger les seules questions encore présentes ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Accès (bêta, abonnement) évalué quand ? — appliqué : à la réception, copie `locked` gardée en file 30 jours ; autres : à l'heure d'origine (horloge non fiable) ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · L'enseignant peut-il écrire hors ligne ? — appliqué : non, lecture seule (rien à corriger aujourd'hui) ; autres : file d'écritures enseignant avec résolution de conflits ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Combien garder ? — appliqué : 60 pages par compte, 30 jours ; autres : 30 pages, 7 jours ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Entraînement de notion (« Vérifier » dans la leçon) hors ligne ? — appliqué : non (réseau demandé, hors ADR) ; autres : corrigé de l'entraînement dans le paquet ; recommandé : chantier de suivi
- [ ] 2026-11-12 · hors-connexion Lot 0 · Bandeau visible aussi sur une page servie du cache alors que `navigator.onLine` est vrai (réseau capricieux) ? — appliqué : oui, visible si hors ligne **ou** meta `lnclass-offline-served` présente (texte « Hors ligne. … Gardée le … ») ; autres : seulement si `onLine === false` (UDR §3.1 à la lettre) ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot 0 · Où se rangent les 30 jours des copies en file (rejetées, en attente) ? — appliqué : `store.js` n'expire que les paquets (`getPack`) ; l'expiration des copies est laissée au Lot C (`listCopies` ne supprime jamais rien, pour ne pas perdre une copie en silence) ; autres : expirer à la lecture ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot C · Une copie en attente depuis plus de 30 jours : supprimée ou montrée ? — appliqué : passée `rejected` (motif `expired`), montrée avec « J'ai compris », jamais supprimée en silence ; le texte `offline.queue.rejected.expired` n'existe pas dans les locales gelées au Lot 0, la vue retombe sur « Copie refusée par le serveur. » (à remplacer par « Copie trop ancienne : elle n'a pas pu être envoyée. » dans un lot de locales) ; autres : suppression avec un message ; recommandé : appliqué + ajouter la clé
- [ ] 2026-11-12 · hors-connexion Lot C · La mention « Rendue hors ligne … » (UDR §3.7) pour l'élève propriétaire ? — appliqué : réservée à l'enseignant et à l'équipe (l'élève sait déjà qu'il a rendu hors ligne) ; dates au format `:short` des locales (« 12 nov. 20h44 ») faute de format dédié ; autres : visible de tous ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot C · Câblage final de l'empreinte — appliqué : le contrôleur utilise `Queries::Assessment::OfflinePackQuery` (`.new.call(public_id:).digest`) si la constante existe, sinon `digest_for` ; à la fusion du Lot B, vérifier que les deux valeurs sont identiques (sinon toute copie serait `stale`) et retirer `digest_for` ; autres : garder `digest_for` seul ; recommandé : appliqué

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
| `SyncOfflineCopy` reprend `award` et `settle_gap` de `CloseExerciseSession` (clôture d'une session déjà terminée à l'écriture) | `CloseExerciseSession` exige une session `started` et n'est pas dans la fiche du Lot C | extraire un service de règles de clôture partagé |
| Le test de rejeu concurrent du dépôt est séquentiel (index unique) et celui du use case simule la course (`RacingSessions`) | Une vraie course de threads exige une base hors transaction de test | aucun |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
