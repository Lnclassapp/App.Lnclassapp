# Journal — Paramétrage et confirmation des notifications par l’équipe

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## À trancher

- [x] 2026-11-25 · parametrage-notifications · Grill 2 sans réponse : un motif validé part-il vers les élèves devenus concernés après la validation ? — appliqué : non, liste figée à la validation (ce que l'équipe a vu = ce qui part), relue avant l'envoi ; autres : motif ouvert toute la journée, revalidation d'un complément ; recommandé : appliqué. → Porteur (2026-11-27) : pas de liste figée ; un motif validé reste ouvert toute la journée et part aussi vers les élèves devenus concernés après la validation, relu avant l'envoi. « Tant que le motif est activé, les notifications partent » : case cochée ou validé, à chaque passage de 15 min, vers tous les élèves concernés au moment du passage, dans les fenêtres et sous le plafond de 10 par jour et par élève ; pas d'écart minimal en plus. Appliqué (ADR-0147, amendement du 2026-11-27).
- [ ] 2026-11-25 · parametrage-notifications · Grill 7 sans réponse : l'équipe valide le motif entier, par établissement, ou élève par élève ? — appliqué : motif entier, avec la répartition par établissement affichée ; autres : case par établissement, élève par élève ; recommandé : appliqué.
- [x] 2026-11-25 · parametrage-notifications · Heure limite de validation — appliqué : jusqu'à la fermeture de la dernière fenêtre du jour (20 h) ; après, refus ; autres : midi ; recommandé : appliqué. → Porteur (2026-11-27) : 20 h, inchangé ; avec les nouvelles fenêtres, la limite suit la fermeture de la dernière fenêtre du jour : 20 h 20 du lundi au samedi, 20 h le dimanche.
- [ ] 2026-11-25 · parametrage-notifications · La règle « 4 h entre deux envois » (`PUSH_MIN_INTERVAL_HOURS`) — appliqué : retirée ; le porteur a fixé un plafond de 10 par jour et par élève (2026-11-25), la variable n'est plus lue ; recommandé : appliqué.
- [x] 2026-11-25 · parametrage-notifications · Écart minimal entre deux notifications d'un même élève, avec le plafond de 10 par jour — appliqué : un motif par passage de la tâche (15 min) ; autres : 30 min, 1 h ; recommandé : 1 h si la tuile du Pilotage montre des élèves qui coupent les notifications. → Porteur (2026-11-27) : un motif par passage (15 min), inchangé ; plafond de 10 par jour.
- [ ] 2026-11-25 · parametrage-notifications (Lot 0) · Port des réglages : l'ADR §4.2 ne prévoit pas la purge de `push_motive_setting_changes` (90 jours, §4.1) — appliqué : méthode additive `purge_changes_before(before:)` sur `PushMotiveSettingRepositoryPort`, à appeler par `PurgePushData` (Lot A) ; autres : purge par requête directe dans le job ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot 0) · Modèles Orm : le plan les place à `app/infrastructure/orm/push_*.rb` ; la règle d'or 2 (namespace par contexte) et les modèles `push_*` existants imposent `app/infrastructure/orm/communication/` (`Orm::Communication::PushMotiveSetting`, `…PushMotiveSettingChange`, `…PushApproval`, `…PushApprovalRecipient`) — appliqué : orm/communication/ ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot 0) · Clé de libellé du menu : l'UDR §3.1 écrit `shared.navigation.destinations.push_settings` ; la convention du fichier est `shared.navigation.<clé>` — appliqué : `shared.navigation.push_settings` ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot D) · Le plan ne cite pas `AuthoredMessagesQuery` (`Row`, colonne `push_requested`) ni `test/domain/entities/communication/message_test.rb` (contrat des membres), mais la cloche de `_row` et le contrat de l'entité les exigent — appliqué : ajout minimal dans ces deux fichiers (aucun autre lot ne les touche) ; recommandé : appliqué.
- [x] 2026-11-25 · parametrage-notifications (Lot D) · La case reste cochée dans le brouillon puis la parution : `push_requested` est relu à chaque enregistrement, sans effet de bord tant que l'annonce n'est pas publiée ; modifier une annonce déjà publiée et cocher la case la rend candidate dans les 48 h de sa parution — appliqué : tel quel ; autres : figer la case après publication ; recommandé : appliqué. → Porteur (2026-11-27) : la case est figée après publication ; modifier une annonce publiée ne peut plus la cocher ni la rendre candidate. Appliqué : `UpdateMessage` garde la valeur publiée, le formulaire la montre désactivée.
- [x] 2026-11-25 · parametrage-notifications · Grill 5 : qu'est-ce qui distingue « À valider » d'« Automatique » une fois que les motifs non validés partent seuls à 17 h ? — appliqué : « À valider » apparaît le matin dans le plan du jour, l'équipe le valide (départ 12 h) ou le retire, sans geste il part à 17 h ; autres : revenir sur 17 h (rien ne part sans geste), deux modes seulement (Automatique retirable, Coupé) ; recommandé : appliqué. → Porteur : un motif est automatique tant que sa case est cochée dans l'administration.
- [ ] 2026-11-25 · parametrage-notifications (Lot A) · Filtre `push_requested` de l'annonce : demandé au Lot A par l'orchestrateur, mais le plan (tableau des fichiers) l'attribue au Lot D — appliqué : laissé au Lot D (`push_candidates/announcement.rb`), le Lot A ne le touche pas pour éviter un conflit ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot A) · Tests existants adaptés hors fiche : `push_candidates_test.rb` (6 → 7 sources), `push_data_eraser_test.rb` — appliqué : modifiés dans le commit du lot ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot B) · Pluriel de `teams.push_settings.history.approval` : le Lot 0 l'a écrit « %{count} élèves » (chaîne simple), une validation d'un seul élève s'affiche « 1 élèves » — appliqué : texte du Lot 0 inchangé (clé gelée) ; autres : clé pluralisée (`one`/`other`) au Lot 0 ou à la clôture ; recommandé : pluraliser à la clôture.
- [ ] 2026-11-25 · parametrage-notifications (Lot B) · Tests système non lancés dans ce worktree (chromedriver 147 pour Chrome 158 ; un chromedriver 158 téléchargé n'a pas pu être exécuté) : `test/system/teams/push_settings_test.rb` est écrit mais jamais joué, et `script/ci/test_timings.yml` n'a pas son entrée (`system_budget_test` rouge) — appliqué : à jouer par le vérificateur (`bin/system-changed`) puis enregistrer la durée ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot C) · Ligne d'historique après validation : le partial `teams/push_settings/_history_entry` du Lot B n'existe pas encore et son contrat de variables n'est pas figé — appliqué : `create.turbo_stream.erb` rend sa propre `<li>` (texte `teams.push_settings.history.approval`), à remplacer par le partial du Lot B à l'intégration ; autres : attendre le Lot B ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot C) · Validation d'un motif devenu automatique ou sans élève concerné au moment du clic : l'UDR §3.4 ne prévoit pas ce cas et les textes sont gelés — appliqué : rien n'est écrit, toast d'information « Rien à valider aujourd'hui » (clé `teams.push_plans.show.empty.title`) ; autres : toast d'erreur dédié (nouvelle clé) ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot C) · Élève sans classe principale active dans le plan du jour — appliqué : compté sous l'établissement « — » ; autres : l'exclure du plan (mais il partirait quand même après validation) ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot C) · `yarn build:css` impossible (Corepack bloqué par le proxy) : les contrôleurs sont testés avec des `application.css`/`application.js` vides (ignorés par git) ; aucun test système lancé (le plan n'en prévoit pas pour le Lot C).
- [x] 2026-11-27 · parametrage-notifications · Fenêtres d'envoi — décision du porteur (2026-11-27) : heure d'Abidjan, du lundi au samedi 12 h 20 – 14 h et 18 h – 20 h 20 ; le dimanche 9 h – 20 h. L'heure limite de validation suit la fermeture de la dernière fenêtre du jour (20 h 20 en semaine, 20 h le dimanche). Appliqué : `SendingWindow` en minutes, textes du plan du jour, ADR-0147 et UDR-0187.
- [ ] 2026-11-27 · parametrage-notifications (retouche) · Passage de 12 h 20 : la tâche passe à :00, :15, :30, :45, le premier envoi de midi partirait à 12 h 30 — appliqué : une tâche récurrente de plus à 12 h 20 du lundi au samedi (`deliver_push_notifications_at_noon_opening`), même job, un seul passage à la fois ; autres : décaler tous les passages à :05, :20, :35, :50 (18 h partirait à 18 h 05), accepter 12 h 30 ; recommandé : appliqué.
> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- …

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- 2026-11-27 · #735 · Décisions du porteur : motif validé ouvert toute la journée (pas de liste figée), fenêtres 12 h 20 – 14 h et 18 h – 20 h 20 (dimanche 9 h – 20 h) avec un passage à 12 h 20, case « Prévenir les élèves » figée après publication.
- 2026-11-27 · config · Envoi ouvert sur ordre du porteur : `PUSH_DELIVERY_ENABLED` passé à vrai dans le `.env` Hostinger de develop, staging et production (seule cette ligne changée, compose inchangé), conteneurs recréés et sains.

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- 2026-11-27 · Production coupée environ 10 min (Cloudflare 526) à l'ouverture de l'envoi. Cause : après les redéploiements de develop et de staging, le projet Hostinger `traefik-72ah` (arrêté jusque-là) tournait et tenait le port 80 ; le Caddy de production n'a pas pu démarrer et tout le projet `lnclass` est resté « Created ». Rétabli en arrêtant `traefik-72ah` puis en démarrant `lnclass` ; le simple « démarrer » n'a pas recréé le script de sauvegarde (`backup` en boucle), un redéploiement complet du même compose et du même `.env` l'a remis. À retenir : avant de redéployer la production, vérifier que `traefik-72ah` est arrêté (liste des projets Docker du VPS) et ne jamais se contenter de « démarrer » après un échec.
- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

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

- Lot R : refus d'un compte d'équipe désactivé non testé : aucun motif existant dans les tests d'équipe (pas de colonne de statut sur `users`).
