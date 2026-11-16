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

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

- Une première version du cadrage traitait deux canaux (Web Push et FCM) et un volet juridique ; le porteur a recentré le chantier le jour même sur le Web Push et reporté le volet juridique ailleurs. Réécriture du memo, du PRD, de l'ADR, de l'UDR et du plan avant le premier commit.
- Le hook d'index (`script/docs/build_index`) exige Ruby 3.4 ; la machine de session n'avait que 3.3 : Ruby compilé sur place.

## Ce qu'on a appris sur la codebase

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
