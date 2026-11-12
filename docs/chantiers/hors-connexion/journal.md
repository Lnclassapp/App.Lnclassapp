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
- [ ] 2026-11-12 · hors-connexion Lot B · Contrat pour le Lot C (ordre d'affichage) : une copie hors ligne n'a pas de session, donc pas de graine de mélange — appliqué : graine = identifiant de l'exercice (`AnswerShuffle.for(session_id: exercise.id, question_id:, ids: question.answer_ids, avoid: (ids_by_position pour ordering et matching))`) ; les `display_order` et `blanks` (liste) de la copie sont des indices dans ce mélange, que le paquet porte en clair (`questions[].display`) ; le serveur du Lot C relit les indices avec la même graine ; autres : un identifiant de proposition par réponse (CopyInput ne le lit pas) ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot B · Empreinte du paquet (`digest`) : calculée par `Queries::Assessment::OfflinePackQuery.digest(questions)` (SHA-256 du JSON canonique, clés triées, 16 hex) sur les questions du paquet — appliqué : le Lot C compare avec `OfflinePackQuery.new.call(public_id:).digest` (lecture seule) ; autres : un calcul dans le domaine sur l'entité `Exercise` (fichier hors fiche) ; recommandé : appliqué, à déplacer au domaine si le Lot C préfère un port
- [ ] 2026-11-12 · hors-connexion Lot B · Réponse mal formée hors ligne (deux cases cochées sur « une seule », texte illisible) — appliqué : elle compte fausse et n'est pas rangée dans la copie (la copie en ligne la refuserait en 422 ; ici le serveur n'a pas à perdre toute la copie) ; autres : bloquer le rendu avec un message par question ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot B · Libellé « Bonne réponse » du résultat provisoire absent de `offline.fr.yml` (locale gelée) — appliqué : clé existante `assessment.session_results.question_review.right_answer` ; autres : nouvelle clé `offline.result.right_answer` ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot B · Paquet absent au rendu (page gardée mais paquet purgé ou expiré) — appliqué : message `offline.copy.not_saved` (la clé la plus proche), rien n'est rangé, réponses laissées ; autres : message dédié « Ouvre l'exercice avec du réseau » (`offline.start.unavailable`) ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot B · `exercise_sessions/show.html.erb` est hors fiche : la feuille de la copie hors ligne en reprend la structure (partials par type partagés, `_kinds/*`), sans en extraire un partial — appliqué : duplication de ~60 lignes, rendu en ligne inchangé ; autres : extraire un partial commun (touche le rendu en ligne, à faire dans un lot de refactor) ; recommandé : extraire plus tard
- [ ] 2026-11-12 · hors-connexion Lot B · Copie hors ligne : pas de brouillon ni de fenêtre « questions vides » (UDR §3.4 n'en parle pas) — appliqué : « Vérifier ma copie » rend tout de suite, les questions vides comptent fausses ; autres : reprendre `assessment--copy` ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot B · Pause « Recommencer » hors ligne — appliqué : calculée sur les seules copies de l'appareil (en file, non rejetées) ; le serveur la rejoue à l'envoi (R3) ; autres : ne rien faire hors ligne ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot B · Images de questions hors ligne — appliqué : non gardées (`no-store`, dette déjà notée) : la copie hors ligne montre le texte de remplacement du navigateur ; autres : revoir ADR-0031 ; recommandé : chantier de suivi

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Lot B : `offline-start` demande aussi la copie hors ligne en `fetch` (Accept `text/html`) après avoir rangé le paquet : c'est ce qui la fait garder par le programme d'arrière-plan du Lot A. Sans le Lot A, la copie hors ligne n'est ouvrable qu'après une visite en ligne gardée.
- Lot B : un contrôleur Stimulus ne voit que les cibles DOM qu'il contient : le compteur sticky de la copie hors ligne est donc dans le `form` (le contrôleur y est), contrairement à la copie en ligne (contrôleur sur le conteneur).
- Lot B : `Numeric.parse` et `FillBlank.normalize` ont des cas limites (espace fine insécable, moins Unicode, ligatures, apostrophes) : la table `grading_cases.json` les fige pour Ruby et Node.

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
