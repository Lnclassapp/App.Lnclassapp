# Journal — Paramétrage et confirmation des notifications par l’équipe

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## À trancher

- [ ] 2026-11-25 · parametrage-notifications · Grill 2 sans réponse : un motif validé part-il vers les élèves devenus concernés après la validation ? — appliqué : non, liste figée à la validation (ce que l'équipe a vu = ce qui part), relue avant l'envoi ; autres : motif ouvert toute la journée, revalidation d'un complément ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications · Grill 7 sans réponse : l'équipe valide le motif entier, par établissement, ou élève par élève ? — appliqué : motif entier, avec la répartition par établissement affichée ; autres : case par établissement, élève par élève ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications · Heure limite de validation — appliqué : jusqu'à la fermeture de la dernière fenêtre du jour (20 h) ; après, refus ; autres : midi ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications · La règle « 4 h entre deux envois » (`PUSH_MIN_INTERVAL_HOURS`) — appliqué : retirée ; le porteur a fixé un plafond de 10 par jour et par élève (2026-11-25), la variable n'est plus lue ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications · Écart minimal entre deux notifications d'un même élève, avec le plafond de 10 par jour — appliqué : un motif par passage de la tâche (15 min) ; autres : 30 min, 1 h ; recommandé : 1 h si la tuile du Pilotage montre des élèves qui coupent les notifications.
- [ ] 2026-11-25 · parametrage-notifications (Lot 0) · Port des réglages : l'ADR §4.2 ne prévoit pas la purge de `push_motive_setting_changes` (90 jours, §4.1) — appliqué : méthode additive `purge_changes_before(before:)` sur `PushMotiveSettingRepositoryPort`, à appeler par `PurgePushData` (Lot A) ; autres : purge par requête directe dans le job ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot 0) · Modèles Orm : le plan les place à `app/infrastructure/orm/push_*.rb` ; la règle d'or 2 (namespace par contexte) et les modèles `push_*` existants imposent `app/infrastructure/orm/communication/` (`Orm::Communication::PushMotiveSetting`, `…PushMotiveSettingChange`, `…PushApproval`, `…PushApprovalRecipient`) — appliqué : orm/communication/ ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot 0) · Clé de libellé du menu : l'UDR §3.1 écrit `shared.navigation.destinations.push_settings` ; la convention du fichier est `shared.navigation.<clé>` — appliqué : `shared.navigation.push_settings` ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot D) · Le plan ne cite pas `AuthoredMessagesQuery` (`Row`, colonne `push_requested`) ni `test/domain/entities/communication/message_test.rb` (contrat des membres), mais la cloche de `_row` et le contrat de l'entité les exigent — appliqué : ajout minimal dans ces deux fichiers (aucun autre lot ne les touche) ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot D) · La case reste cochée dans le brouillon puis la parution : `push_requested` est relu à chaque enregistrement, sans effet de bord tant que l'annonce n'est pas publiée ; modifier une annonce déjà publiée et cocher la case la rend candidate dans les 48 h de sa parution — appliqué : tel quel ; autres : figer la case après publication ; recommandé : appliqué.
- [x] 2026-11-25 · parametrage-notifications · Grill 5 : qu'est-ce qui distingue « À valider » d'« Automatique » une fois que les motifs non validés partent seuls à 17 h ? — appliqué : « À valider » apparaît le matin dans le plan du jour, l'équipe le valide (départ 12 h) ou le retire, sans geste il part à 17 h ; autres : revenir sur 17 h (rien ne part sans geste), deux modes seulement (Automatique retirable, Coupé) ; recommandé : appliqué. → Porteur : un motif est automatique tant que sa case est cochée dans l'administration.
- [ ] 2026-11-25 · parametrage-notifications (Lot A) · Filtre `push_requested` de l'annonce : demandé au Lot A par l'orchestrateur, mais le plan (tableau des fichiers) l'attribue au Lot D — appliqué : laissé au Lot D (`push_candidates/announcement.rb`), le Lot A ne le touche pas pour éviter un conflit ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot A) · Tests existants adaptés hors fiche : `push_candidates_test.rb` (6 → 7 sources), `push_data_eraser_test.rb` — appliqué : modifiés dans le commit du lot ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot B) · Pluriel de `teams.push_settings.history.approval` : le Lot 0 l'a écrit « %{count} élèves » (chaîne simple), une validation d'un seul élève s'affiche « 1 élèves » — appliqué : texte du Lot 0 inchangé (clé gelée) ; autres : clé pluralisée (`one`/`other`) au Lot 0 ou à la clôture ; recommandé : pluraliser à la clôture.
- [ ] 2026-11-25 · parametrage-notifications (Lot B) · Tests système non lancés dans ce worktree (chromedriver 147 pour Chrome 158 ; un chromedriver 158 téléchargé n'a pas pu être exécuté) : `test/system/teams/push_settings_test.rb` est écrit mais jamais joué, et `script/ci/test_timings.yml` n'a pas son entrée (`system_budget_test` rouge) — appliqué : à jouer par le vérificateur (`bin/system-changed`) puis enregistrer la durée ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot C) · Ligne d'historique après validation : le partial `teams/push_settings/_history_entry` du Lot B n'existe pas encore et son contrat de variables n'est pas figé — appliqué : `create.turbo_stream.erb` rend sa propre `<li>` (texte `teams.push_settings.history.approval`), à remplacer par le partial du Lot B à l'intégration ; autres : attendre le Lot B ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot C) · Validation d'un motif devenu automatique ou sans élève concerné au moment du clic : l'UDR §3.4 ne prévoit pas ce cas et les textes sont gelés — appliqué : rien n'est écrit, toast d'information « Rien à valider aujourd'hui » (clé `teams.push_plans.show.empty.title`) ; autres : toast d'erreur dédié (nouvelle clé) ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot C) · Élève sans classe principale active dans le plan du jour — appliqué : compté sous l'établissement « — » ; autres : l'exclure du plan (mais il partirait quand même après validation) ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications (Lot C) · `yarn build:css` impossible (Corepack bloqué par le proxy) : les contrôleurs sont testés avec des `application.css`/`application.js` vides (ignorés par git) ; aucun test système lancé (le plan n'en prévoit pas pour le Lot C).
> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- …

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
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
