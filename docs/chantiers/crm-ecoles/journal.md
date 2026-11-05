# Journal — CRM des écoles

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-05 | Lot 0 : routes du suivi sous `namespace :teams` (`teams_school_*`, param `:school_public_id`), relances en `teams_follow_up_*`, port `GenerationRepositoryPort#mark_failed` (et non `fail`, qui masque `Kernel#fail`) | Les noms `school_*` existent déjà pour la fiche ; les UDR citent `teams_school_follow_up_path` et `teams_follow_ups_path` | Non (contrat gelé par le Lot 0) |
| 2026-11-05 | Lot B : numéro facultatif (colonne nullable), normalisé par `Entities::Identity::Contact.normalize` (espaces, +225 acceptés) ; WhatsApp = `https://wa.me/225` + les 10 chiffres (le 0 reste, comme dans l'UDR) ; retrait d'un contact d'une autre école = 404 ; pas de test système (budget dépassé), tout prouvé au niveau contrôleur | Colonne nullable ; UDR §Contacts ; consigne de l'orchestrateur | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot 0 : `port_contracts_test` exige un adaptateur par port ; résolu par des adaptateurs squelettes (`NotImplementedError, "Lot X"`) livrés par le Lot 0 et repris par les Lots A, B, C, G.
- Lot 0 : les échecs du port de modèle de langage ne pouvaient pas être des codes de `Shared::Result` (liste fermée) ; décidé : `failure(:unavailable, errors: { reason: … })`, ADR modèles de langage mis à jour.

- Lot C : contrats du Lot 0 incohérents entre eux. `Entities::Crm::Interaction` et `Entities::Crm::Contact` n'exposent que `public_id`, alors que `crm_follow_ups.interaction_id` et `crm_interactions.contact_id` sont des clés étrangères entières. Le lot n'a donc ni lien relance -> échange (`interaction_id` reste nul) ni lien échange -> contact (le nom du contact choisi est copié dans `contact_name`). À trancher avant la clôture (ajouter `id` aux entités, ou clés publiques dans les ports) ; aucun écran du lot ne dépend de ces liens.
- Lot C : le dépôt de contacts est encore le squelette du Lot B (`NotImplementedError`) ; la modale en a besoin pour son sélecteur d'interlocuteur. Les tests du lot le remplacent par un faux (`define_method`, restauré au `teardown`) : à retirer à la fusion du Lot B.
- Lot C : aucune action d'audit `crm.*` pour un échange (liste fermée posée par le Lot 0) : le journal est lui-même la trace. Le nom de l'auteur vient de `AssignableMembersQuery` (admin/field non anonymisés), « Ancien membre » sinon. Un champ radio `required` est arrêté par le navigateur : le test système de l'erreur serveur passe par une date de relance passée.
- Lot C : 23 tests écrits (6 domaine, 3 dépôt, 12 contrôleur, 2 système), tous rouges avant le code (dépôt : `NotImplementedError "Lot C"` ; contrôleur : frame vide).
- Les agents ont une limite de 5 heures : elle a coupé les Lots C et H le 4 au soir ; ils ont repris le 5 au matin, avec environ une demi-journée de retard.
- Lot G : le test rouge avant le code n'a pas été vu pour l'adaptateur ni pour le dépôt (écart à la règle).
- Lot G : `test/javascript/generation_poll_controller.test.js` n'est lancé par aucune commande de la CI.
- Lot D : un squelette du Lot 0 cassait `ui_page_header` (`back:` attend `{label:, href:}`) ; un 422 en Turbo Stream exige `Accept: text/vnd.turbo-stream.html, text/html` dans les tests ; un template partagé entre contrôleurs se rend par `render template:`.
- Lot H : dans un test système, le serveur tourne dans un autre fil (file `:inline` et `cattr_accessor` pour le faux modèle) ; dans `Data.define`, les constantes se qualifient.
- Garde `system_budget_test` : le budget de 15 s du chantier est dépassé (24,9 s après C, D et H) ; décision du porteur attendue.
- Lot 0 : le compteur de `models_test` n'a pas suivi les cinq tables crm ; vu au Lot E, corrigé au Lot 0 bis.
- Lot 0 bis, correction 1 (liens par identifiant public) : le contrat d'entités du Lot 0 (seulement `public_id`) ne pouvait pas remplir `contact_id` ni `interaction_id`. Les ports prennent `contact_public_id:` et `interaction_public_id:`, les dépôts les résolvent (même école) ; un inconnu donne `:not_found`. `RecordInteraction` transmet `contact_public_id:` (remplace `contact_id:`, jamais utilisé). `interactions_controller.rb` (Lot C) passe `contact_public_id:`, testé.
- Lot 0 bis, correction 2 : « Réessayer » était un lien GET vers des routes POST (404), et `generations#show` ne passait aucun `retry_href`. `ui_error_state(retry_method:)` pose `data-turbo-method` (GET par défaut) ; le partial `_generation` réessaie en POST par défaut (ce qui répare aussi `briefings/create.turbo_stream`) ; une table `ASSISTANTS` du contrôleur donne la route par type.
- Lot 0 bis, correction 3 : la vue prête du sondage est celle du type (table `ASSISTANTS`, clé `ready`), sinon le texte générique. Les Lots I, J et K ajoutent leur ligne.
- Contrat de `Crm::GenerationJob` pour les Lots I à K : `messages(generation)`, `model_name`, `max_tokens`, `json?`, `content_for(text)`, `language_model` surchargeable, `perform(public_id)` ; une génération finie est ignorée ; l'audio est purgé dans un `ensure`.
- Lot 0 bis, correction 4 : `Generation#created_at` (facultatif à la construction, pour ne casser aucun appel) alimente « Préparée il y a X » ; une réponse vide ou que `content_for` refuse est `invalid_response`, plus `provider_error`.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Préparer un worktree neuf (bases par worktree, assets absents) : `bin/rails db:create db:schema:load` (développement), `RAILS_ENV=test bin/rails db:create db:schema:load`, `yarn install --immutable`, `yarn build`, `yarn build:css`. Sans les assets, tout test qui rend un layout échoue sur « application.css not found ». Après une migration, `db/schema.rb` reformate trois anciennes contraintes `check` (PG16) : les remettre à l'identique avant de committer.
- `bin/system-changed` sur une branche de lot : `BASE=feature/crm-ecoles` (la base par défaut est `origin/Develop`).
- `test/architecture/port_contracts_test.rb` exige un adaptateur par port, `test/db/schema_constraints_test.rb` une liste fermée de cascades : tout nouveau port ou toute clé en cascade passe par ces deux gardes.
- Un frame paresseux dont le contrôleur n'existe pas fait lever `MissingController` à tout test système qui ouvre la page : le Lot 0 pose un squelette pour chaque adresse qu'il charge ou lie.
- Lot F : l'étape affichée dépend de l'usage, pas d'une colonne : filtrer par étape calcule l'usage de toutes les écoles filtrées (3 requêtes, constantes), puis pagine ; sans filtre d'étape, seul l'usage de la page est lu. `SchoolsQuery::Row` reste inchangé (ses tests le comparent) : le suivi voyage dans `Page#crm`, par `public_id`. La ligne re-rendue par Turbo Stream (modifier, désactiver, supprimer) relit ses cellules du suivi, sinon elle se décale. Le menu « Codes » (sélection de masse) s'efface quand un filtre d'étape ou de responsable est actif : ces filtres ne font pas partie de la sélection de masse.

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
