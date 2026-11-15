# Journal — Contrôleurs Stimulus bornés

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-15 | La règle s'écrit dans `docs/guide/conventions.md` §7, sans ADR | Règle de forme (rang 2) : aucune architecture, aucun port, aucun modèle ne change ; évite un numéro et une ligne d'index de plus pendant que d'autres sessions en prennent | Non |
| 2026-11-15 | Marqueur `sessionStorage` plutôt que `history.replaceState` | `replaceState` retirerait l'ancre, mais une redirection 301 en cache repart d'une nouvelle entrée : il ne borne pas la boucle. Le marqueur survit à la redirection | Non |
| 2026-11-15 | Sans `sessionStorage` utilisable, `hash_redirect` ne redirige pas | Sans marqueur, rien ne borne : mieux vaut la page de la leçon (l'ancre y reste lisible) qu'une boucle possible | Non |

## Audit de `app/javascript/` (98 fichiers JS dont 53 contrôleurs ; `lib/` et `offline/` compris)

Cherché : `MutationObserver`, `ResizeObserver`, `location.replace|assign`, `Turbo.visit`, `requestSubmit`, `frame.reload()`, écouteurs Turbo, minuteries, `connect()` sans garde.

| Contrôleur | Forme | Verdict |
|---|---|---|
| `hash_redirect` | `location.replace` dans `connect()` | **Corrigé** (marqueur) |
| `math` | `MutationObserver` imbriqué | Déjà corrigé (#628, registre + `takeRecords`) ; pas de test JS (voir à trancher) |
| `modal` | `MutationObserver` sur `open`, `syncOpen` modifie `open` | Borné par l'état : la 2ᵉ passe trouve la boîte non modale et sort |
| `catalog/paper_table` | `ResizeObserver` qui change une classe | Borné : une mesure par image (`requestAnimationFrame`), mesure faite sans la classe |
| `prepare_sheet` | `ResizeObserver` → `scrollIntoView` | Borné : coupé à 2 s ou au premier geste de l'élève |
| `figure` | `ResizeObserver` → `fit()` pose `--figure-text` | Non clairement non borné : voir à trancher |
| `teams/import_status` | `setTimeout` qui se réarme à chaque rechargement du frame | Borné par l'état de l'import, mais sans plafond de durée : voir à trancher |
| `generation_poll` | `setInterval` + échéance | Borné (échéance) |
| `autosubmit` | `requestSubmit` sur `input` | Borné : drapeau `sending`, dernière valeur mémorisée |
| `offline/start` | `Turbo.visit` / `location.assign` | Borné : sur clic, hors ligne, une fois |
| `assignment_batch` | écoute `turbo:render` / `morph` / `frame-render` | Sans boucle : `render()` ne produit pas ces événements |
| `theme`, `signup_steps`, `class_picker`, `phone_digits`, `pin_match`, `revision_more`, `lib/assessment/copy_sheet` | écoute `turbo:morph` | Sans boucle : le traitement ne déclenche pas de morph (`copy_sheet` émet `input`/`change` au rétablissement du brouillon : non relu en détail au-delà de `autosubmit`, qui ne réagit qu’à un code de 6 chiffres) |
| `search`, `classroom/*`, `school/drena_schools`, `generation_poll` | `frame.reload()` | Sur action de l'utilisateur ou par minuterie bornée |
| autres (`dropdown`, `info_tip`, `carousel`, `audio`, `toast`, …) | écouteurs `scroll` / `resize` | Placement ou état local, aucune écriture qui les relance |

**Rien à corriger de plus** : aucun autre contrôleur n'est clairement non borné.

## À trancher

- [x] 2026-11-15 · controleurs-stimulus-bornes · (fait en session 2, lot 1) Test JS du `math_controller` : la règle exige un test du nombre d'actions, `math` n'en a pas (la boucle de #628 n'est couverte que par la CI `lecons`) — appliqué : aucun code touché, dette notée ici ; autres : écrire le test (deux instances imbriquées, DOM simulé, KaTeX réel ou simulé) dans une PR dédiée ; recommandé : l'écrire.
- [ ] 2026-11-15 · controleurs-stimulus-bornes · `figure` : `ResizeObserver` observe le cadre et `fit()` y pose `--figure-text`, qui peut changer la taille du texte de la figure et donc, en théorie, celle du cadre. Le navigateur coupe seul une boucle de `ResizeObserver` (erreur « loop completed with undelivered notifications »), mais rien ne la borne dans le code — appliqué : rien ; autres : ne rappeler `fit()` que si le rapport arrondi change ; recommandé : cette garde, avec un test.
- [x] 2026-11-15 · controleurs-stimulus-bornes · (fait en session 2, lot 2 : 600 rechargements, arrêt silencieux) `teams/import_status` : le suivi recharge le frame toutes les secondes tant que l'import est en cours, sans plafond. Un import resté « importing » pour toujours (job mort) fait interroger le serveur sans fin tant que l'onglet reste ouvert — appliqué : rien ; autres : plafond de durée comme `generation_poll` ; recommandé : un plafond (par exemple 10 minutes) puis un message.
- [ ] 2026-11-15 · controleurs-stimulus-bornes · `hash_redirect` sans `sessionStorage` (navigation privée stricte) ne redirige plus : l'ancienne adresse `#fiche-de-revision` garde la page de la leçon au lieu de mener à la fiche — appliqué : ne pas rediriger (prudent, pas de boucle) ; autre : redirection sans marqueur ; recommandé : l'option appliquée.
- [ ] 2026-11-15 · controleurs-stimulus-bornes · `bundle-audit` échoue sur `Develop` comme sur cette branche : puma 8.0.2 a de nouveaux avis (GHSA-r885-m39c-939g, -rf6g-xhmp-gm7v, -x646-wp7c-h9mg, -xw3h-pgr9-3vg7), correctif `>= 8.0.3`. `Gemfile.lock` n'est pas touché par cette PR — appliqué : rien (hors chantier) ; autre : monter puma dans une PR dédiée ; recommandé : la monter.
- [ ] 2026-11-15 · controleurs-stimulus-bornes · `teams/import_status` : l'arrêt silencieux gêne l'enseignant qui regarde la page — après 10 min la page affiche encore « en cours » sans plus se mettre à jour, rien n'indique que le suivi a cessé (un rechargement de la page le relance) — appliqué : arrêt silencieux, dernier état affiché, aucune interface inventée ; autre : message « Le suivi s'est arrêté, rechargez la page » (UDR à écrire) ; recommandé : ce message.

## Ce qui a dérapé

- Le dépôt local avait 27 commits de retard sur `origin/Develop` : `hash_redirect_controller.js` y était absent. Mise à jour par fast-forward avant de commencer.
- Environnement de session sans Ruby 3.4.9, sans Postgres démarré ni rôle `dev-rails`, avec un chromedriver 147 pour un Chrome 153 et sans assets compilés : installés ou contournés pour lancer `bin/ci-quiet` (hors dépôt).
- `node_modules` absent : `corepack enable` puis `yarn install --immutable` pour lancer les tests Node.

## Ce qu'on a appris sur la codebase

- Les tests JS de contrôleurs se font sans navigateur : `Object.create(Controller.prototype)` et valeurs Stimulus simulées (`Object.defineProperties`), `window` posé sur `globalThis`. Ils tournent dans `config/ci.rb` (étape « Tests: Node »).

## Session 2 — `fix/controleurs-stimulus-bornes-2`

- **Lot 1 · `math_controller`** : `test/javascript/math_controller.test.js` (4 tests). `MutationObserver` simulé (file par observateur, `takeRecords()`, livraison asynchrone), KaTeX réel, deux éléments imbriqués autour d'une feuille commune ; chaque rendu réécrit la feuille, comme KaTeX réécrit le texte. Affirme le nombre exact de rendus : 2 à la connexion (un par instance, aucun en cascade), 1 à l'arrivée de contenu sous l'élément intérieur (l'extérieur écarte ces mutations-là), 1 pour une mutation hors de l'élément rendu (la borne n'avale pas le vrai contenu), 0 après `disconnect`. Preuve : `settle()` neutralisé → 3 tests sur 4 échouent (60 rendus au lieu de 2, arrêtés par la fin de l'attente) ; borne remise → 4 sur 4.
- **Lot 2 · `teams/import_status`** : plafond de `MAX_POLLS = 600` rechargements (1 s chacun, soit 10 min) par instance du contrôleur ; au plafond le minuteur ne se réarme plus et le dernier état reste affiché (décision de l'orchestrateur : ni écran ni message). Test `test/javascript/teams_import_status_controller.test.js` (4 tests, horloge simulée) : exactement 600 requêtes puis aucune de plus sur 1 200 s de plus ; le premier pose `src`, les suivants rechargent ; arrêt dès `done` ; `disconnect` annule. Preuve : garde retirée → 1 800 requêtes au lieu de 600, test rouge ; remise → vert.
