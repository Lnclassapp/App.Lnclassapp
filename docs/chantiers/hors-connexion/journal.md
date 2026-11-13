# Journal — Lnclass hors connexion

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-12 | Jeton signé du paquet (pas de table d'ouverture) | Borne l'heure et lie la copie à l'élève sans écrire en base | ADR §4.4 |
| 2026-11-12 | Synchro dans un contrôleur distinct de la copie hors ligne | Lots B et C parallèles sans fichier commun | Non (plan) |
| 2026-11-12 | Jeton du paquet chiffré (MessageEncryptor) et `OfflineKeepable` refuse `secret_response` / `no-store` | Revue sécurité du Lot 0 : identifiants internes lisibles (ADR-0029), garde P6 côté serveur | ADR §4.4 inchangé (contrat identique) |
| 2026-11-12 | Contrat store.js étendu : deletePack, additif | Un refus du serveur (402, 403, 404) doit retirer le paquet déjà rangé (revue « pannes silencieuses », Lot B) | Non |
| 2026-11-12 | Enseignant en lecture seule | Aucune correction manuelle n'existe (ADR-0115 option E) | ADR §4.6 |
| 2026-11-12 | Lot 0 : les deux méthodes du port des sessions (`record_offline_copy`, `find_by_client_copy_id`) sont **implémentées** dans l'adaptateur dès le Lot 0, pas laissées au Lot C | `test/architecture/port_contracts_test.rb` exige que l'adaptateur définisse toute méthode du port : un port gelé sans adaptateur casse la CI. Le Lot C n'a plus qu'à les appeler (et à compléter les tests de rejeu concurrent) | Non |
| 2026-11-12 | Lot 0 : étape Node `Tests: Node (JavaScript)` placée dans le groupe `lint`, entrées limitées à `test/javascript/`, `app/javascript/`, `package.json`, `config/ci.rb` | Pas de base de données ni de navigateur ; rejouée seulement quand le JavaScript bouge | Non |
| 2026-11-12 | Lot C : l'empreinte courante est **injectée** dans `SyncOfflineCopy` (`current_digest:`, obligatoire, callable `exercise → String`) ; le contrôleur la câble sur `Queries::Assessment::OfflinePackQuery` (fin de l'intérim : `digest_for` et la branche `defined?` sont supprimés à l'intégration du Lot B) | Une seule source de l'empreinte : celle que le paquet signe. Test : le jeton du paquet réellement servi est accepté (pas de `stale`) | Non |
| 2026-11-12 | Lot C : les indices `display_order` / `blanks` d'une copie en file se rapportent au mélange `AnswerShuffle` de graine **l'identifiant de l'exercice** (ordre porté en clair par le paquet) ; le serveur les ramène aux identifiants avec la même graine, comme `SubmitExerciseCopy` avec la session | Pas de session hors ligne ; même règle que la copie en ligne | Non |
| 2026-11-12 | Lot C : une réponse mal formée (hors bornes, texte trop long) n'est pas rangée par l'appareil ; le serveur la compte non répondue (copie rangée). Seules une copie illisible ou une question étrangère refusent la copie (`invalid`) | Alignement sur le Lot B | Non |
| 2026-11-12 | Lot C : `Shared::Result` n'a pas de code `wrong_owner`/`stale`/`paused`/`already_synced` ; le use case rend `:forbidden` / `:conflict` avec `errors[:base]` (`wrong_owner`, `stale`, `paused`, `subscription_required`, `not_published`), et `already_synced` est un succès (`Synced#already_synced`) | `Shared::Result` est partagé et hors de la fiche ; le contrôleur ramène ces faits aux six motifs de la file | Non |
| 2026-11-12 | Lot B (revue sécurité) : le paquet ne porte plus aucun identifiant de proposition. `answers[]` n'a plus d'`id`, `display` est une liste de **rangs**. L'identifiant de question reste | Les ids `Orm::Answer` sont internes (ADR-0029) | ADR §4.4 inchangé |
| 2026-11-12 | **Forme des réponses en file (à traduire par le Lot C)** : `answers` = `{ "<id de question>": réponse }`. Rang d'une proposition = son indice dans `question.answers` du paquet = ordre (`position`, `id`) des propositions de la question. `display` = rangs dans l'ordre où la feuille les montre ; graine du mélange = `AnswerShuffle.for(session_id: exercise.id, question_id:, ids:)` (`avoid: ids` pour ordering et matching), `ids` = identifiants des propositions en ordre de rang, **jamais envoyée** : le serveur la recalcule. Réponse par type : choice, ordering, matching (et select à une case) → `{ display_order: [i, …] }`, entiers, chaque `i` étant un **indice dans `display`** (une place sur la feuille), pas un rang ; id serveur = `ids[display[i]]`, soit `AnswerShuffle.pick(display_ids, display_order)` pour ordering/matching et `.select` pour choice/select. Select à plusieurs cases → `{ blanks: { "<case>": "<i>" } }` (`i` : indice dans `display` en chaîne, vide = case laissée vide), id = `ids[display[i]]`. fill_blank et numeric → `{ response_text }` ou `{ blanks: { "<case>": texte } }` (aucun id). written → `{ response_text }`. Une réponse vide ou mal formée n'est pas rangée | Le Lot C n'a qu'à recalculer `display_ids` côté serveur (même `AnswerShuffle`, mêmes `ids` dans l'ordre `position, id`) et appliquer `display_ids[i]` ; un paquet dont l'empreinte (`digest`) a changé est déjà refusé (`:stale`) | Non |
| 2026-11-12 | **Budget du point d'entrée (ADR-0051, train #563)** : les six contrôleurs hors ligne passent dans `offline/controllers/`, hors du motif d'enregistrement, et forment un seul morceau chargé à la première connexion de l'un d'eux (`offline/lazy_controllers.js`) ; le layout portant `offline-session`, le morceau est chargé en ligne sur chaque page, donc gardé par le programme d'arrière-plan. Stimulus est prêté au morceau (`offline/controller_base.js`) pour ne pas sortir du point d'entrée. 67,9 → 59,9 Ko gzip ; seul morceau statique : l'aide d'esbuild (0,3 Ko). |

- 2026-11-12 · Lot B2 (décision du porteur) : le paquet d'un devoir à rendre est servi ; chaque remise est enregistrée (`offline_pack_deliveries`, première remise gardée par élève et exercice) ; une copie rattachée à un devoir, rendue à la première remise du corrigé ou après (heure du serveur), ou faite hors ligne, porte une marque pour l'enseignant et l'équipe (« Corrigé reçu sur le téléphone le … ») ; une copie hors ligne d'un devoir est de nouveau rattachée au devoir, avec la même marque. Écart d'exécution : l'icône du suivi est en taille `sm` (`ui_icon` n'a pas de `xs`).
- 2026-11-12 · Lot B2, revues : la marque ne lit plus l'heure de début (donnée par le téléphone, ramenée à l'heure d'émission du jeton, elle échappait à la marque) ; elle suit l'heure de remise du serveur pour une copie en ligne, et toute copie hors ligne d'un devoir remis est marquée. Le signalement du 503 porte l'élève. Clés étrangères en `restrict` (règle du schéma) ; le remplacement des exercices d'une leçon efface les remises de ces exercices.

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-12 · hors-connexion · Quelle heure fait foi pour une copie rendue hors ligne ? — appliqué : heure du téléphone bornée dans [émission du paquet, réception], 30 jours au plus, heure de réception gardée et montrée à l'enseignant ; autres : heure de réception seule, heure du téléphone sans borne ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Exercice modifié entre l'ouverture et l'envoi : que devient la copie ? — appliqué : refusée, montrée « non comptée » ; autres : corriger les seules questions encore présentes ; recommandé : appliqué
- [x] 2026-11-12 · hors-connexion lot B · Le corrigé hors ligne d'un devoir assigné : le servir ? — appliqué : refusé pour un devoir en attente (devoirs non faisables hors ligne ; à la synchro, une copie d'un devoir en attente est rangée comme entraînement, non rattachée) ; autres : servi et la copie en ligne commencée après la remise du paquet est marquée pour l'enseignant (une table de remises), servi sans marque (risque accepté) ; recommandé : servi avec marque côté enseignant — **tranché par le porteur le 2026-11-12 : servi, avec marque pour l'enseignant** (Lot B2)
- [ ] 2026-11-12 · hors-connexion lot B2 · La remise du corrigé ne peut pas s'écrire (base indisponible) : servir quand même ? — appliqué : non, 503 sans corrigé, erreur signalée (`Rails.error.report`), l'appareil réessaiera (pas de corrigé sans trace pour l'enseignant) ; autres : servir et signaler ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion lot B2 · Le suivi du devoir marque-t-il aussi l'élève qui n'a pas encore rendu ? — appliqué : non, la marque se lit sur la ligne des élèves qui ont rendu une copie (la marque dépend d'une copie rattachée) ; autres : marque aussi sur « pas encore fait » dès que le corrigé est reçu ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Accès (bêta, abonnement) évalué quand ? — appliqué : à la réception, copie `locked` gardée en file 30 jours ; autres : à l'heure d'origine (horloge non fiable) ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · L'enseignant peut-il écrire hors ligne ? — appliqué : non, lecture seule (rien à corriger aujourd'hui) ; autres : file d'écritures enseignant avec résolution de conflits ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Combien garder ? — appliqué : 60 pages par compte, 30 jours ; autres : 30 pages, 7 jours ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion · Entraînement de notion (« Vérifier » dans la leçon) hors ligne ? — appliqué : non (réseau demandé, hors ADR) ; autres : corrigé de l'entraînement dans le paquet ; recommandé : chantier de suivi
- [ ] 2026-11-12 · hors-connexion Lot 0 · Bandeau visible aussi sur une page servie du cache alors que `navigator.onLine` est vrai (réseau capricieux) ? — appliqué : oui, visible si hors ligne **ou** meta `lnclass-offline-served` présente (texte « Hors ligne. … Gardée le … ») ; autres : seulement si `onLine === false` (UDR §3.1 à la lettre) ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot 0 · Où se rangent les 30 jours des copies en file (rejetées, en attente) ? — appliqué : `store.js` n'expire que les paquets (`getPack`) ; l'expiration des copies est laissée au Lot C (`listCopies` ne supprime jamais rien, pour ne pas perdre une copie en silence) ; autres : expirer à la lecture ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion lot C · Un élève qui change de niveau peut-il encore rendre une copie d'un paquet reçu avant ? — appliqué : oui, pendant 30 jours (`SyncOfflineCopy` revérifie le droit de l'élève, l'exercice publié et l'accès, mais pas le niveau ; l'ADR-0133 ne vérifie le niveau qu'à l'émission du paquet) ; autres : refuser à la réception si le niveau ne correspond plus (test : jeton émis → changement de niveau → synchro refusée) ; recommandé : refuser à la réception, sur décision du porteur
- [ ] 2026-11-12 · hors-connexion #565 · Rouge système du train (crm_journal:48, boucle_pedagogique:200) imputé au chargeur différé des contrôleurs hors ligne ? — appliqué : rien changé au chargeur, cause non confirmée (les deux fichiers 10 fois de suite, processeur du navigateur bridé ×6 : 30 tests, 0 échec ; train passé en production ensuite) ; autres : charger le morceau après `turbo:load` ; recommandé : appliqué, rouvrir si l'échec revient
- [ ] 2026-11-12 · hors-connexion Lot C · Une copie en attente depuis plus de 30 jours : supprimée ou montrée ? — appliqué : passée `rejected` (motif `expired`), montrée avec « J'ai compris », jamais supprimée en silence ; le texte `offline.queue.rejected.expired` n'existe pas dans les locales gelées au Lot 0, la vue retombe sur « Copie refusée par le serveur. » (à remplacer par « Copie trop ancienne : elle n'a pas pu être envoyée. » dans un lot de locales) ; autres : suppression avec un message ; recommandé : appliqué + ajouter la clé
- [ ] 2026-11-12 · hors-connexion Lot C · La mention « Rendue hors ligne … » (UDR §3.7) pour l'élève propriétaire ? — appliqué : réservée à l'enseignant et à l'équipe (l'élève sait déjà qu'il a rendu hors ligne) ; dates au format `:short` des locales (« 12 nov. 20h44 ») faute de format dédié ; autres : visible de tous ; recommandé : appliqué
- [x] 2026-11-12 · hors-connexion Lot C · Câblage final de l'empreinte — fait à l'intégration du Lot B : `OfflinePackQuery` seule, `digest_for` retiré ; test de parité grader.js / serveur ajouté (`sync_offline_copy_parity_test.rb`, 71 cas de la table partagée : même note des deux côtés)
- [ ] 2026-11-12 · hors-connexion Lot A · Déconnexion alors que la file de copies n'a pas pu partir (envoi échoué ou délai de 10 s dépassé) : que devient la file ? — appliqué : pages et caches purgés, mais la base garde les copies en attente (`keepQueue`), la déconnexion part quand même, l'erreur va en console ; autres : tout purger (copies perdues), bloquer la déconnexion ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot A · Page du réseau dont la meta de clé diffère de la clé reçue par le programme (première page après un changement de compte) — appliqué : non gardée (la page suivante, après `postMessage`, l'est) ; autres : adopter la clé de la page ; recommandé : appliqué
- [ ] 2026-11-12 · hors-connexion Lot A · Réponses de frame Turbo (`Turbo-Frame`) portant l'en-tête keep (le concern ne les distingue pas) — appliqué : le programme ne les garde ni ne les sert, pour qu'un morceau de page n'écrase jamais la page entière ; autres : le concern ne pose pas l'en-tête sur une requête de frame (hors fiche, fichier du Lot 0) ; recommandé : appliqué, et reprise dans le concern à une retouche
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

- Lot A : le programme d'arrière-plan est testé dans un `vm` (Cache Storage simulé), pas dans un navigateur ; son exécution dans le WebView de l'app Android n'a pas pu être vérifiée dans le dépôt, à contrôler sur un appareil avant la fusion de la vague.
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
| `SyncOfflineCopy` reprend `award` et `settle_gap` de `CloseExerciseSession` (clôture d'une session déjà terminée à l'écriture) | `CloseExerciseSession` exige une session `started` et n'est pas dans la fiche du Lot C | extraire un service de règles de clôture partagé |
| Le test de rejeu concurrent du dépôt est séquentiel (index unique) et celui du use case simule la course (`RacingSessions`) | Une vraie course de threads exige une base hors transaction de test | aucun |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |

## Lot C — correctifs des revues (sécurité, pannes silencieuses)

- S1 : `SyncOfflineCopy` reçoit `pending:` (`PendingAssignmentRepository`, port existant) ; un devoir en attente à la réception range la copie sans rattachement. Le test « rattachée à l'assignation active » est remplacé : pour un exercice assigné et non rendu, il n'y a plus de rattachement hors ligne.
- S2 : verrou `pg_advisory_xact_lock` via la méthode additive `lock_restart_window` du port ; la pause est relue sous le verrou, dans la transaction. Écart : pas de test de concurrence réel (transactions de test) ; test que le verrou est pris, et l'ordre verrou puis relecture.
- F4 : le jeton porte `expires_at` (signature + 30 j) ; l'enveloppe chiffrée vit 365 j pour que `expired?` (ajout au port) distingue « expiré » d'« altéré » sans changer `verify`. L'appareil n'expire plus rien.
- F5 : écart assumé : la déconnexion est bloquée aussi quand des copies `locked` / `paused` restent en attente (`pending > 0`), comme demandé.
- F6 : `safeRefresh` dans le contrôleur de la file ; message « Envoi impossible » affiché tant que des copies attendent.

