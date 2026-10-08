# Journal — Tests instables : cache de l'accueil de la direction et texte alternatif du blog

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

### Rapport de cause — (1) AD-23, `direction_home_query_test.rb:199`

- **Chaîne** : le test pose `read_at = Time.current` (l. 191), puis `home(cache:)` → `Queries::School::DirectionHomeQuery#call` → `@cache.fetch(key, expires_in: CACHE_TTL) { read(...) }` (`app/infrastructure/queries/school/direction_home_query.rb:26`). `ActiveSupport::Cache` fixe l'expiration à l'**écriture** (`Time.now.to_f + expires_in`), donc après la lecture en base.
- **Cause** : `test/infrastructure/queries/school/direction_home_query_test.rb:191` — l'instant de référence précède l'écriture ; si la première lecture dure plus d'une seconde (machine chargée), l'entrée vit encore à `read_at + 5 min 01 s` et l'assertion « 2 classes » lit 1.
- **Trou de test** : le test suppose une première lecture instantanée ; aucun test ne fige l'horloge pendant l'écriture.
- **Couche** : le test seul. Le code de production est correct.

### Rapport de cause — (2) texte alternatif tronqué, `blog_management_test.rb`

- **Chaîne** (piles capturées sur `focusin`) : `app/javascript/controllers/rich_text_editor_controller.js:124` `this.editor.insertFile(ready)` (après la réduction asynchrone, l. 114-121) — ou l. 168 `attachment.setAttributes(...)` à la fin de l'envoi, ou l'aperçu préchargé interne de Trix (`trix.esm.js:6896-6900`) → Trix `CompositionController.render` (10906-10918) → `compositionControllerWillSyncDocumentView` : `selectionManager.lock()` → `compositionControllerDidSyncDocumentView` → `SelectionManager.unlock` → `setLocationRange(lockedLocationRange)` (10415-10421) → `setDOMRange` → `selection.addRange()` : Chromium donne le focus à `trix-editor`.
- **Cause** : Trix 2.1.19 restaure sa dernière sélection après chaque redessin sans vérifier que le focus est dans l'éditeur (`updateCurrentLocationRange`, 10502-10503, ne met à jour la position que si la sélection y est). Le contrôleur de l'application ne protège pas le focus des autres champs.
- **Trou de test** : le parcours n'attend pas la fin de l'insertion et de l'envoi de l'image du texte avant de taper (l. 106-108) ; `fill_in` tape 27 caractères en quelques dizaines de ms, donc la course n'apparaît que sous charge ; le test ne vérifie ni le focus ni le corps du texte.
- **Mis hors de cause** : remplacement du champ (`_form.html.erb:76-77`, jamais remplacé), `cover_picker_controller.js`, `image_alts_controller.js`, Turbo et le morphing.
- **Reproduction déterministe** : retenir la réduction (`canvas.toBlob`) ou la réponse de l'envoi (`load` du XHR) et la relâcher au 12e caractère de `cover_alt` : 4 cas sur 4 rouges (dont frappe à 100 ms par touche), témoin sans image vert.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Articles du blog dont le texte aurait reçu des caractères destinés à un autre champ | Indiscernables automatiquement | Relecture des brouillons par l'équipe |
| Deux lancements de tests simultanés dans le même dossier partagent les bases des workers | Outillage (memo, hors périmètre) | à ouvrir si cela se reproduit |
| Signaler à Trix la restauration de sélection hors focus | Externe | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
