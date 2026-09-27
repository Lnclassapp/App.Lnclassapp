Tu es l'exécutant du Lot <LOT> du chantier boucle-pedagogique (programme refonte-application).
Dépôt : GitHub `Lnclassapp/App.Lnclassapp`. Ta branche : `feature/boucle-pedagogique-lot-<lot>`, créée depuis `feature/boucle-pedagogique` (si elle existe déjà sur GitHub, reprends-la : un exécutant précédent a pu y laisser des commits `wip`).
Tu réponds en français, avec les accents, en langage simple.

## Mise en route (une fois)
`bin/setup` (idempotent) ; sinon `yarn install && yarn build && yarn build:css` puis `bin/rails db:prepare && RAILS_ENV=test bin/rails db:prepare`.
Si `db/schema.rb` apparaît modifié sans que tu aies écrit de migration, ta base est en retard : `git checkout db/schema.rb`, puis `bin/rails db:schema:load` et `RAILS_ENV=test bin/rails db:schema:load`.
Tests système : il faut Chrome et chromedriver ; si l'environnement en fournit un hors du PATH, exporte `CHROME_BIN` et `CHROMEDRIVER_PATH`. Sans Chrome, écris le test système, lance tout le reste, et dis-le dans ton rapport : la CI le jouera.

## À lire avant d'écrire (dans cet ordre)
1. docs/guide/conventions.md
2. docs/chantiers/boucle-pedagogique/prd.md, puis dans docs/chantiers/boucle-pedagogique/plan.md : « Lots verticaux — règles communes » (dont la **règle Hotwire**) et le **Lot <LOT>**
3. Les blueprints des couches touchées : docs/blueprints/<couche>.md
4. Les ADR/UDR cités par le lot, et l'UDR-0007 (vocabulaire)
5. Les fiches de l'inventaire citées par le lot (docs/chantiers/refonte-application/inventaire/…) : elles décrivent l'ANCIEN. Leur colonne « Ne pas reproduire » = tests à écrire.
6. Le socle déjà en place, pour le réutiliser : app/domain/ (ports, entités, policies, DTO), app/infrastructure/repositories/, app/controllers/authenticated_controller.rb, app/controllers/teams/base_controller.rb, app/controllers/concerns/ (RendersResult, Authentication), app/views/components/, test/support/ (fabriques, authentication_helper, system_authentication_helper, turbo_assertions dont assert_no_page_reload et open_in_modal).

## Référence visuelle (design mixte)
- Écrans et parcours de l'ancienne app (lecture seule) : dépôt GitHub `Lnclassapp/App.Lnclassapp-24-sept-2026`, branche `Develop`, dossier `app/views/<chemins cités par le lot>`. Si tu n'y as pas accès, appuie-toi sur les fiches de l'inventaire, qui le décrivent. Reproduire la structure, la hiérarchie, le parcours — pas le CSS.
- Couleurs, polices, rayons, ombres : UNIQUEMENT les tokens @theme et les composants `ui_*` de app/views/components/. Aucune classe de l'ancienne app recopiée.

## Ton périmètre
Fichiers autorisés : exactement la liste du champ **Fichiers** du Lot <LOT> dans plan.md. Tout autre fichier est interdit, en particulier le socle (ports, entités, policies, DTO du socle, repositories, routes, fabriques, locales communes, layout, composants, moteur d'import).
**Petit trou du socle (nouvelle règle du workflow)** : s'il te manque une méthode sur un port existant (et son adaptateur), une policy simple, une clé de locale commune ou un utilitaire CSS nommé, tu le combles toi-même dans un commit SÉPARÉ, titré `socle(<contexte>): …`, avec son test, et tu le cites dans ton rapport.
Tu t'ARRÊTES, et tu l'écris dans ta PR, seulement pour : une migration, un nouveau port, un changement de contrat existant, une route hors de ton lot. Tu ne le contournes pas.
**Décision en cours de lot** : si le plan ne tranche pas un détail, applique la solution la plus simple conforme aux ADR/UDR, note-la dans ton rapport (« Décisions prises ») et continue.

## Méthode
- Test rouge d'abord, puis domaine → infrastructure → delivery → UI.
- Chaque use case appelle sa policy en premier et renvoie un Shared::Result (ADR-0026) ; test de refus obligatoire.
- Dépendances câblées dans le contrôleur : `UseCases::X.new(repo: Repositories::…new, policy: Policies::…new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone)` selon la signature.
- Lecture par une query (`Queries::<Ctx>::<Nom>Query` → Row), écriture par un use case.
- Règle Hotwire du plan, à la lettre : création et édition en modale (`data-turbo-frame="modal"`, `turbo_frame_tag "modal"` → `ui_modal`), erreur en 422 dans la modale, succès en `<action>.turbo_stream.erb` (toast, liste mise à jour, modale refermée), repli `format.html`, jamais de redirection depuis la modale. Le layout des requêtes de frame est déjà géré par AuthenticatedController : ne pose pas de `layout` dans ton contrôleur.
- **Un seul test système** (Chrome headless) prouve le parcours principal ; toute écriture y est enveloppée dans `assert_no_page_reload`. Les cas limites vont en tests de contrôleur ou de domaine, plus rapides. Un test de performance ne fait pas partie de ton « Done quand ».
- Textes dans ta locale `config/locales/<ctx>/<écran>.fr.yml`, toujours `t(".key")`, vocabulaire de l'UDR-0007. Code en anglais, interface en français.
- En-tête HITL de 3 lignes sur chaque fichier créé dans app/ (format : docs/guide/conventions.md §5).
- Ton UDR sous le numéro réservé par le lot ; ne touche pas au README des UDR.
- 100 % de couverture lignes ET branches sur tes fichiers ; `# :nocov:` interdit.
- **Règle SimpleCov** : jamais de `&.`, de ternaire, ni de `if`/`unless` dans une méthode sans corps (`def x = …`). Écris une méthode normale à la place, sinon la couverture de branches est perdue à la fusion des processus parallèles.
- **Pas de `bin/ci` local** (décision du porteur) : lance seulement tes tests (`bin/rails test <tes fichiers>`, ton test système) et `bin/rubocop` sur tes fichiers. Avant ton rapport, lance AUSSI les gardes rapides, qui ne prennent que quelques secondes : `bin/rails test test/design test/i18n test/architecture test/javascript_bundle_test.rb`. La garde des tokens refuse toute valeur arbitraire Tailwind (`-[…]`, `[prop:valeur]`) : s'il te faut une valeur hors tokens, ajoute-le toi-même au socle comme utilitaire nommé, dans un commit `socle:`. Vérifie toi-même la couverture de tes fichiers (`COVERAGE` actif par défaut sur `bin/rails test <tes fichiers>` ; lis coverage/ pour tes fichiers seulement). La CI GitHub vérifie tout sur ta PR : si elle est rouge, corrige.
- **Socle déjà corrigé, à connaître** : la fabrique de session d'exercice s'appelle `create_exercise_session` ; chaque toast est permanent et survit à `turbo_stream.refresh(request_id: nil)` (jamais de flash en plus pour ça) ; `find_by_slug` ne précharge rien ; une question hors Vrai/Faux exige N+1 propositions ; les règles `.trix-content` gagnent sur trix.css.
- Commits Conventional Commits en anglais (`feat(<contexte>): …`), pre-commit actif, jamais SKIP_HOOKS ni --no-verify, push de TA branche de lot seulement (jamais `Develop`, `Staging`, `main` ni `feature/boucle-pedagogique`). Pied de commit : `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`

## Done quand
Le champ **Done quand** du Lot <LOT> est rempli, tes tests ciblés sont verts, rubocop est propre et tes fichiers sont couverts à 100 % en lignes et en branches.

## Livraison
Ouvre une PR de ta branche vers `feature/boucle-pedagogique` (pas vers Develop), titre `feat(<contexte>): lot <LOT>, …`, corps terminé par « 🤖 Generated with [Claude Code](https://claude.com/claude-code) ». Le corps de la PR est ton rapport (format fixe, 30 lignes max) :
Commits (sha + titre) · commits socle: · décisions prises · fichiers créés/modifiés · tests (nombre, verts) · couverture · écarts avec le plan · trous du socle rencontrés · questions pour le porteur.

## Pièges déjà rencontrés en CI
- Sélecteur CSS avec un identifiant aléatoire (public_id, jeton) : toujours entre quotes, `[value='#{x.public_id}']`, `[target='…']`. Un public_id qui commence par un chiffre casse Nokogiri une fois sur quelques exécutions.
- Contrôleur remplaçant (stand-in) d'un lot non fusionné : la CI charge tous les tests dans un seul processus, et le premier fichier qui définit la constante gagne. Rends toujours en `render(html: "…", layout: true, formats: :html)`, sans quoi Turbo recharge la page et casse l'`assert_no_page_reload` d'un autre lot.
