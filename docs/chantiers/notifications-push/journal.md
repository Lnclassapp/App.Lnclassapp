# Journal — Notifications poussées aux élèves

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-16 | Web Push seulement ; FCM et la coque Android sortent du périmètre ; pas de volet juridique dans ce chantier | Changement de cadrage du porteur, relayé par l'orchestrateur le 2026-11-16 | Oui (ADR §1) |
| 2026-11-16 | « Préparer une interro » = la veille de l'échéance d'une feuille « Prépare interros » (1 ou 2 exercices) assignée | Aucune table ne date une interrogation ; l'échéance est la prochaine séance (ADR-0072) et l'écran « Ma classe » distingue déjà interros et devoirs | Non (PRD §3.1) |
| 2026-11-16 | « Exercice commencé » = session ouverte depuis 24 h sans réponse, moins de 7 jours | Une seule session ouverte par élève et par exercice : la clé d'objet est naturelle | Non (PRD §3.1) |
| 2026-11-16 | Les motifs sont lus par une tâche récurrente, pas émis par les use cases | Aucun bus d'événements ; ne pas toucher `CloseExerciseSession` ni les annonces | Oui (ADR §3.2) |
| 2026-11-16 | Une session expirée garde son abonnement (`ON DELETE SET NULL`) ; une fermeture volontaire le supprime | Règle `app-android` Q11 : l'élève décroché reste joignable | Oui (ADR §4.1) |
| 2026-11-25 | Clés VAPID posées dans le `.env` des projets Hostinger `lnclass-develop`, `lnclass-staging` et `lnclass` (une paire par environnement, `PUSH_DELIVERY_ENABLED=false`), pas dans `credentials.yml.enc` | Les trois environnements tournent en `RAILS_ENV=production` : un seul fichier `credentials` leur donnerait la même paire ; le `.env` est la convention des secrets du VPS (ADR-0140). Décision du porteur, production redémarrée à sa demande | Non |
| 2026-11-25 | Aucun envoi automatique : l'équipe confirme chaque envoi de motif, piloté depuis un futur paramétrage des notifications ; `PUSH_DELIVERY_ENABLED` reste `false` sur Develop, Staging et production (activé quelques minutes sur Develop et Staging, puis recoupé) | Décision du porteur : éviter plusieurs notifications le même jour pour un élève. Le code fusionné (#652) envoie seul dès l'interrupteur ouvert : un chantier suivant doit ajouter la confirmation par l'équipe avant toute activation | À faire (chantier suivant) |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-16 · notifications-push · Quand inviter l'élève ? Aujourd'hui 0 élève a réussi un exercice : avec la règle retenue, personne n'est invitable à l'ouverture, et l'élève qui décroche avant sa première réussite ne sera jamais relancé — appliqué : après le premier exercice réussi (choix du porteur) ; autres : après le premier exercice commencé, dès la première visite ; recommandé : appliqué, puis « commencé » si deux semaines après l'ouverture les élèves « commencé sans réussite » dépassent les « réussi ».
- [ ] 2026-11-16 · notifications-push · Fenêtres d'envoi (aucune table ne porte d'horaire de cours) — appliqué : lundi-samedi 12 h-14 h et 17 h-20 h, dimanche 9 h-20 h, heure d'Abidjan ; autres : 17 h-20 h seulement (règle `app-android`), horaires par établissement (hors périmètre) ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Garde-fou contre la rafale sans plafond — appliqué : pas de doublon par objet, 4 h au moins entre deux envois, un seul motif par passage, le plus urgent ; autres : 2 h, 6 h, un par fenêtre ; recommandé : 4 h.
- [ ] 2026-11-16 · notifications-push · « Annonce de l'équipe » : quels auteurs ? — appliqué : comptes de l'équipe seulement ; autres : aussi direction et enseignants ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · « Résultat ou médaille » (les notes sont calculées à la clôture, l'élève les voit déjà à l'écran ; aucun enseignant ne « publie » de résultat) — appliqué : copie hors ligne corrigée à la synchronisation, ou médaille sans visite depuis 2 h ; autres : médaille seulement, rien ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Relances « inactif » — appliqué : paliers 3, 7 et 14 jours, puis plus rien sans nouvelle activité ; autres : 2-5-10, chaque semaine sans fin ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Variables d'environnement à poser par le porteur (jamais dans le chat ni le dépôt) : `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`, `PUSH_DELIVERY_ENABLED`, `PUSH_MIN_INTERVAL_HOURS` — appliqué : absentes, l'adaptateur répond « non configuré » ; recommandé : une paire VAPID par environnement (recette, production) avant le Lot B.

- [ ] 2026-11-16 · notifications-push · Lot 0 : le plan nomme `config/locales/fr.yml` et `test/fixtures/push_*.yml` ; le dépôt range les textes par contexte et n'a aucune fixture d'utilisateur — appliqué : `config/locales/communication/push.fr.yml` et des fabriques `test/support/factories/push.rb` ; autres : ajouter au `fr.yml` racine, fixtures YAML ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Lot 0 : `recurring.yml` nomme `DeliverPushNotificationsJob` et `PurgePushDataJob`, écrits au Lot B ; le test « un port, un adaptateur » (ADR-0026) reste rouge jusqu'aux Lots A et B — appliqué : un seul commit de Lot 0 laissé tel quel, la PR est verte à son head ; autres : adaptateurs vides au Lot 0 ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Lot A : le plan place la carte aussi dans `assessment/sheet_checks/create.turbo_stream.erb`, mais cette vue ne rend que le refus d'une copie ; une copie réussie redirige vers `session_results/show`, où la carte est rendue — appliqué : fichier non modifié ; autres : ajouter la carte au refus (faux : copie non terminée) ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Lot A : ni `ProfilesController` ni `SessionResultsController` ne sont dans la fiche : les deux partials (`_invitation`, `_push_row`) appellent `Queries::Communication::PushInvitationQuery` elles-mêmes (la carte pour l'élève propriétaire, l'agent utilisateur lu par `lnclass_app?`) — appliqué : requête dans la vue ; autres : l'exposer par le contrôleur dans un lot suivant ; recommandé : appliqué tant que les deux écrans ne changent pas.
- [ ] 2026-11-16 · notifications-push · Lot A : « Couper » supprime l'abonnement de la session courante et pose l'interrupteur ; les abonnements des autres navigateurs restent en base mais ne reçoivent rien (Lot B lit `turned_off?`) et redeviennent actifs à « Réactiver » — appliqué ; autre : tout supprimer (`delete_for_user`) ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Lot A : ajout additif d'un use case `UnregisterPushSubscription` (contrôle de propriété de `DELETE /push_subscriptions/:id`, absent de la fiche) ; l'adresse d'abonnement est validée (https, nom de domaine, pas d'IP ni de `localhost`, 2 048 caractères) car le Lot B l'appellera depuis le serveur — appliqué ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Lot A : l'UDR §3.1/§3.2 est corrigée (clés `communication.push.messages`, `intent=` au lieu de `postpone: 1`, `text-error`/`shadow-card` : les tokens `text-danger`/`shadow-lift` n'existent pas ou sont des états de survol) ; la ligne du profil n'a pas de session côté serveur : « sur un autre appareil » et « bloquées » sont dites par le navigateur ; la ligne exige `VAPID_PUBLIC_KEY`, comme la carte — appliqué.
- [ ] 2026-11-16 · notifications-push · Lot B : `PushDeliveryRepositoryPort#purge_before(time)` devient `purge_before(before:)` (changement additif : `PortsShapeTest` refusait l'argument positionnel) ; le port documente aussi l'upsert de `record` et le sens de `sent?` — appliqué.
- [ ] 2026-11-16 · notifications-push · Lot B : `test/architecture/use_case_policies_test.rb` (exemptions des use cases sans acteur) et `test/integration/pwa_test.rb` (qui interdisait tout écouteur `push`) ne sont pas dans la fiche : exemptions ajoutées pour `DeliverPushNotifications` et `PurgePushData`, le test PWA n'interdit plus que `sync` et exige `push` et `notificationclick` — appliqué ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Lot B : la gem `web-push` 3.1 n'écrit pas l'en-tête `Topic` : une sous-classe de `WebPush::Request` l'ajoute (topic = motif) ; 401/403/400/413 et toute réponse ou erreur inattendue sont traitées comme `:retry` (jamais `:gone` : un souci de clés VAPID ne doit pas supprimer les abonnements, et trois échecs mettent l'envoi en `failed`) — appliqué ; autre : `:not_configured` pour 401/403 ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Lot B : le motif « inactif » n'est candidat que le jour même du palier (3, 7, 14 jours de différence de date d'Abidjan, `valid_until` = fin de ce jour) ; un jour sauté (fenêtre fermée par une coupure de la tâche) perd la relance du palier — appliqué ; autre : candidat dès le palier jusqu'au suivant ; recommandé : appliqué (les fenêtres couvrent chaque jour, la tâche passe toutes les 15 minutes).
- [ ] 2026-11-16 · notifications-push · Lot B : statut noté pour plusieurs navigateurs = le plus significatif (delivered > retry > failed > not_configured > gone) ; un navigateur en `retry` quand un autre a reçu n'est pas retenté — appliqué.
- [ ] 2026-11-16 · notifications-push · Lot C : la requête lit les envois en masse (4 lectures fixes) au lieu d'appeler `StudentAssignedSheetsQuery` par élève ; elle reprend ses filtres (classe principale active, assignation active, exercice/cours/notion publiés, envoi = batch ou public_id, échéance la plus proche) mais PAS le filtre de niveau d'`AudienceFilter` (UDR-0013), trop coûteux par élève : un élève d'un autre niveau que sa classe pourrait être notifié d'une feuille qu'il ne voit pas — appliqué ; autre : filtre de niveau par élève ; recommandé : appliqué, tant que la classe fixe le niveau.
- [ ] 2026-11-16 · notifications-push · Lot D : la médaille est retrouvable de façon fiable (`exercise_badges.awarded_at` + `exercise_session_id`, une ligne par élève et exercice, la meilleure) : motif « résultat » = copie hors ligne (`exercise_sessions.received_at`, moins de 24 h) ou médaille (2 h à 24 h), une notification par session (la copie prime) ; « non revenu » = `LastActivity` au plus 1 minute après l'événement (la fermeture écrit `completed_at` autour de l'instant de la médaille) — appliqué ; autre : copie hors ligne seule ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Lot E : la règle de lecture de l'ADR-0078 §4.3 est évaluée en mémoire pour tous les élèves abonnés (5 lectures fixes) au lieu d'appeler `ReadableMessages#scope` par lecteur (une requête par classe) ; un test de parité la compare à `ReadableMessages` (audience, école, classes ciblées, élève sans classe active) — appliqué ; autre : `scope` par couple école-classe ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Lot H : le contrôleur `Teams::DashboardsController` (absent de la fiche) lit `PushUsageQuery` dans `@push_usage` ; « échouées » = statuts `failed` et `gone` de la semaine (7 jours glissants), les statuts provisoires ne comptent pas ; « ont coupé » = préférences avec `turned_off_at` ; le détail par motif ne liste que les envois partis, dans l'ordre de priorité des motifs — appliqué ; autre : compter aussi `retry` en échec ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Lot G : les abonnements des sessions fermées par un changement de PIN ou de numéro sont retrouvés par `for_user` (leurs `session_id`) puis supprimés AVANT `destroy_all_except` (sinon `SET NULL` les détacherait) ; `SignOut` supprime ceux de la session fermée ; une session expirée garde le sien — appliqué.
- [ ] 2026-11-16 · notifications-push · Corrections après revues : la route `DELETE /push_subscriptions/:id`, son action et `UnregisterPushSubscription` sont supprimés (personne ne les appelait, la règle « pas d'identifiant numérique » les interdisait) ; l'entrée du Lot A sur ce use case est caduque — appliqué.
- [ ] 2026-11-16 · notifications-push · Corrections : liste fermée d'hôtes push (anti-SSRF) dans `RegisterPushSubscription` ; plafond de 5 abonnements par élève (`delete_oldest_beyond`, additif au port, par `updated_at` puis `id`) ; `rate_limit` de 10 par minute et par élève sur `create` (réponse 429 sans corps) — appliqué ; autres : 5 ou 20 par minute ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Corrections : ports additifs `reattach_session`, `delete_for_user_except_session`, `reset_failures` (abonnements) et `user_ids: nil` (candidats) ; `ResetPinWithCode` reçoit `push_subscriptions:` (contrôleur mis à jour) — appliqué.
- [ ] 2026-11-16 · notifications-push · Corrections : `filter_parameters` reçoit `endpoint`, `p256dh`, `auth` en expressions ancrées (`/\Aauth\z/`), car `:auth` seul filtrerait aussi `author` — appliqué ; autre : symboles simples ; recommandé : appliqué.
- [ ] 2026-11-16 · notifications-push · Corrections (supplante l'entrée du Lot C sur le niveau) : `assignment_due` et `quiz_prep` ne notifient que les exercices du niveau (et de la série) des classes de l'élève, en deux lectures pour tous (règle de `StudentAudienceQuery`, repli sur la classe principale) ; l'échéance « la plus proche » reste calculée sur l'envoi entier — appliqué.
- [ ] 2026-11-16 · notifications-push · Corrections : passerelle — 400 et 413 valent `:gone` (comme demandé), 400 `UnauthorizedRegistration` (FCM) reste `:retry` en journal `error` avec 401/403 ; une exception inattendue lève, et le passage la signale par élève (`Rails.error.report`) ; le journal « clés VAPID absentes » est écrit par la tâche, pas par le domaine — appliqué.
- [ ] 2026-11-16 · notifications-push · Corrections : relecture avant envoi — si la clé choisie a disparu, rien ne part et rien n'est écrit, sans tenter le motif suivant avant le passage suivant (15 min) ; l'envoi parti est consigné dans un `ensure` même si une écriture suivante échoue ; `record` faux après un envoi parti est journalisé en `warn` — appliqué.
- [ ] 2026-11-16 · notifications-push · Corrections : en dehors de « denied », une demande de permission fermée (« default ») ne montre plus « bloquées » et laisse le bouton actif — appliqué.
- [ ] 2026-11-25 · #652 · `VAPID_SUBJECT` vaut `https://lnclass.com` sur les trois environnements — appliqué : l'adresse du site ; autres : `mailto:` d'une adresse de l'équipe ; recommandé : une adresse `mailto:` lue par l'équipe si les services push doivent pouvoir la joindre.

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

- Une première version du cadrage traitait deux canaux (Web Push et FCM) et un volet juridique ; le porteur a recentré le chantier le jour même sur le Web Push et reporté le volet juridique ailleurs. Réécriture du memo, du PRD, de l'ADR, de l'UDR et du plan avant le premier commit.
- Le hook d'index (`script/docs/build_index`) exige Ruby 3.4 ; la machine de session n'avait que 3.3 : Ruby compilé sur place.

## Ce qu'on a appris sur la codebase

- Dans un job, le cache de requêtes d'ActiveRecord est actif : une écriture faite par `select_value` (INSERT … RETURNING) ne l'invalide pas ; `PushDeliveryRepository#record` le vide à la main.
- Aucun bus d'événements : l'attribution d'une médaille n'est connue que du contrôleur (`earned_now`).
- L'activation (première réussite) n'est stockée nulle part : elle se lit dans `exercise_sessions` (10/20 arrondi).
- `classroom_session_days` n'a pas d'heure : aucune notion d'heures de classe en base.
- La distinction « Prépare interros » (1-2 exercices) / « Prépare devoirs » (≥ 3) vit dans une requête d'affichage (`DEVOIRS_FROM = 3`) : le Lot 0 doit la remonter dans une constante partagée plutôt que la dupliquer.
- Le chantier `app-android` (Q5 à Q11) avait déjà fixé : textes sobres, abonnement qui suit la connexion, et non sa durée de session.
- Le programme d'arrière-plan porte déjà les caches de `hors-connexion` : on y ajoute deux écouteurs, sans changer de version de cache.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Notifications des enseignants (résumés, élève qui rejoint, résultats) | Élèves seulement (porteur, 2026-11-16) | à ouvrir |
| Notifications dans la coque Android (FCM) | Web Push seulement (porteur) | chantier FCM, ADR-0070 |
| Préférences par motif | Interrupteur global d'abord | si les retraits le justifient |
| Saisie d'une interrogation datée par l'enseignant | Aucune table ; hors périmètre | à ouvrir si « préparer une interro » s'avère trop rare |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
