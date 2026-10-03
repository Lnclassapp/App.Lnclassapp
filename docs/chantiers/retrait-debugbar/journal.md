# Journal — Retrait de debugbar

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-03 | Retrait complet de la gem, pas de contournement | Décision du porteur : « retire debugbar du repo » | Non : aucun ADR n'en faisait une décision (aucun ADR ne cite `debugbar`) |
| 2026-10-03 | `config.action_cable.disable_request_forgery_protection` retiré de `development.rb` **et** de `test.rb` : Action Cable revient au défaut de Rails | Les deux lignes n'existaient que pour la gem (« required by Debugbar », « Avoid Debugbar overriding this setting ») ; l'application n'ouvre aucun canal (aucun `turbo_stream_from`) | Non |
| 2026-10-03 | Test de reproduction au niveau configuration (`EnvironmentProbe` en développement + `Bundler.locked_gems` en test), pas au niveau requête | Le défaut ne se produit qu'en développement, où aucun test ne tourne ; ce qui le prévient, c'est l'absence de la gem et de ses middlewares, et c'est ce que le test garde | Non |
| 2026-10-03 | `prd.md` et `pr-faq.md` du gabarit retirés | Un bugfix n'a pas de PRD ; le comportement attendu est celui de Rails sans la gem | Non |

## Ce qui a dérapé

- Rien de notable. La reproduction à la main a marché du premier coup avec le compte élève des seeds de développement (`0100000001`, PIN `2468`).
- La suppression de `config/initializers/debugbar.rb`, mise en index par `git rm` avant le premier commit, est partie dans `docs(docs): open the retrait-debugbar chantier` au lieu de `chore(deps): drop the debugbar gem`. Sans effet (l'initialiseur était gardé par `defined?(Debugbar)`), l'historique poussé n'a pas été réécrit. Leçon : `git status` avant chaque commit, pas seulement les fichiers qu'on ajoute.
- Le hook `.githooks/pre-commit` n'est pas branché dans ce worktree (`core.hooksPath` non défini, configuration partagée avec le dépôt principal) : il a été lancé à la main avant chaque commit.

## Ce qu'on a appris sur la codebase

- **Chaîne de la panne** : `Debugbar::TrackCurrentRequest#call` → `RequestBuffer.push` (tampon en mémoire du processus) → `ActionCable.server.broadcast("debugbar_channel", RequestBuffer.to_h)` à **chaque** requête. Une seule chaîne binaire (`ASCII-8BIT`) dans le tampon, déposée par `GET /accounts/:id/photo`, fait lever `JSON::GeneratorError` à toutes les diffusions suivantes. Le tampon survit jusqu'au redémarrage.
- **Trou de test** : la gem était chargée en test mais désactivée (`config.enabled = Rails.env.development?`), donc ses middlewares n'existaient qu'en développement. Rien ne démarrait le développement dans la suite, sauf `development_configuration_test.rb` (ADR-0052), qui ne regardait que Solid Queue et les traductions. C'est là que le test de reproduction a été ajouté.
- La gem forçait `disable_request_forgery_protection = true` au démarrage, avec un avertissement, si l'application ne le posait pas : d'où la ligne en `test.rb`, qui ne servait qu'à faire taire la gem.
- Sans la gem, en développement, Rails n'accepte les connexions Action Cable que des origines `http(s)://localhost:<port>` ; un navigateur ouvert sur `127.0.0.1` serait refusé. Sans effet aujourd'hui (aucun canal), à savoir pour [`mise-a-jour-en-direct`](../mise-a-jour-en-direct/memo.md).

### Preuves

Test de reproduction, **rouge** avant le correctif :

```
DevelopmentConfigurationTest#test_development_boots_without_debugbar_and_keeps_Action_Cable's_default_origin_check
-{"debugbar" => false, "middleware" => [], "cable_any_origin" => false}
+{"debugbar" => true, "middleware" => ["Debugbar::TrackCurrentRequest", "Debugbar::QuietRoutes"], "cable_any_origin" => true}

DevelopmentConfigurationTest#test_the_bundle_no_longer_locks_debugbar_and_test_keeps_Action_Cable's_default_origin_check
Gemfile.lock.
Expected ["debugbar"] to be empty.

3 runs, 5 assertions, 2 failures, 0 errors, 0 skips
```

Après correctif : `3 runs, 6 assertions, 0 failures, 0 errors, 0 skips`.

Portes finales (2026-10-03) : `bin/rails test` 3079 runs, 37046 assertions, 0 failure, 0 erreur, 8 skips, couverture 100 % lignes (10056/10056) et branches (2534/2534) ; `COVERAGE=0 bin/rails test:system` 339 runs, 3962 assertions, 0 failure ; `bin/rubocop` 1198 fichiers, 0 offense ; `bin/brakeman` 0 alerte ; `bin/bundler-audit` aucune vulnérabilité ; `.githooks/pre-commit` vert.

Reproduction rejouée dans l'application (`bin/rails server -e development`, Chromium headless) :

| | Avant | Après |
|---|---|---|
| Connexion élève, `/up` | `200` | `200` |
| Envoi de la photo (`PATCH /profile/photo`) | `200` | `200` |
| Puis `/up` · `/` · `/students` | `500` · `500` · `500` | `200` · `200` · `200` |
| `JSON::GeneratorError` au journal | 4 | 0 |

`bin/rails runner -e development 'puts :ok'` → `ok`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Inventaires de `refonte-application` (`inventaire/transverse.md`, `inventaire/complements-transverse.md`) citent `/_debugbar` | Ils décrivent l'ancienne application, ce sont des relevés historiques | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-03, sur `fix/retrait-debugbar` (PR ouverte par le porteur) |
| **PR** | |
| **ADR produits** | aucun |
| **UDR produits** | aucun |
