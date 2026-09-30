# Journal — La CI épuise le quota de minutes GitHub Actions

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-30 | **Les leviers sont lancés sans le « Je lance les leviers ? » explicite.** Le porteur, avant d'aller dormir : « si besoin prend des décisions et fait moi le recap après ». | Rien n'est fusionné dans `Develop` : tout reste sur `perf/ci-quota`, en PR brouillon. | — |
| 2026-09-30 | **Lots A et B écrits d'une traite**, en deux leviers mesurables séparément. | Ils touchent le même fichier (`ci.yml`) et le même job `ci`. Leurs chiffres restent séparables : A se mesure sur une PR de chantier, B sur une promotion. | — |
| 2026-09-30 | **La preuve d'arbre sert aussi hors promotion**, sur le runner de la machine : un re-run ou le push de fusion sur `Develop` d'un arbre déjà testé ne rejoue rien. | Le push sur `Develop` teste presque toujours l'arbre que sa PR vient de tester. Le rejouer occupe la machine pour rien et retarde les autres PR. | ADR-0069 §4 |
| 2026-09-30 | **Une PR qui ne touche que des documents ne publie pas de preuve.** | Elle n'a rien vérifié. Une promotion de cet arbre rejouera la suite, sur la machine, sans coût. | ADR-0069 §6 |
| 2026-09-30 | **`PGPORT` lu par `config/database.yml`**, pas `DATABASE_URL`. | `bin/setup` prépare la base `development` : avec `DATABASE_URL`, elle aurait pointé sur la base de test. | ADR-0069 §4.7 |
| 2026-09-30 | **Les scripts de preuve et de relance tournent sur le Ruby du système** (Ubuntu 22.04 : Ruby 3.0), sans syntaxe plus récente. `install` pose le paquet `ruby`. | Le job `proof` doit répondre avant tout `setup-ruby` (il décide si la suite tourne), et le service de relance tourne hors de tout job. | — |
| 2026-09-30 | **`.github/actions/setup/action.yml` inchangé**, contrairement au plan. | `install` pose `libpq-dev` : le test `dpkg -s` de l'action passe, et le `sudo apt-get` n'est jamais atteint. Pas de changement sans gain. | — |
| 2026-09-30 | **Deux instances du runner par défaut** (`--instances 2`). | 4 cœurs, mémoire inconnue : chaque part système lance `nproc` navigateurs. Le nombre juste se fixe à la mesure (lot E). | — |
| 2026-09-30 | **Relectures `security-reviewer` et `silent-failure-hunter` sur le diff : constats corrigés dans ce chantier.** PostgreSQL publié sur `127.0.0.1` seulement (il l'était sur toutes les interfaces de la machine) ; jeton d'enregistrement lu au clavier et passé par l'environnement ; empreinte SHA-256 du runner obligatoire ; root n'exécute plus `svc.sh` ni aucun fichier de `github-runner` (unités systemd `lnclass-runner-<n>` écrites par le script) ; service de relance sous `DynamicUser`, script à root, jeton vérifié avant installation ; `rerun_expired` sort en 1 sur une réponse illisible au lieu de « rien à relancer », et ne relance jamais un run qui contient un vrai test rouge ; `check` exige root et lit le journal du runner (« Listening for Jobs ») ; un fichier renommé compte sous ses deux noms pour la règle « documents seulement » ; verdict `ci` : `skipped` accepté seulement si `code == "false"`. | Chaque constat avait un scénario concret, vérifié par l'agent ou par la lecture du code. Trois nouvelles gardes : ports sur la boucle locale, `PGPORT` pour tout job avec base, runner de `ci`. | ADR-0069 §4.6, §4.7 |
| 2026-09-30 | **La preuve qui n'a jamais eu de runner arrête le run** : `changes` ne tourne que si `proof` a réussi, et `ci` passe alors sur GitHub (1 minute) pour rendre un rouge immédiat. | Sinon `changes`, puis `ci`, attendaient chacun 24 h de plus : le run finissait à 72 h, hors de la fenêtre de relance de 48 h. `tested_tree` ne lève plus rien (même sans `gh`), donc un `proof` en échec veut dire « jamais exécuté ». | ADR-0069 §4.1 |
| 2026-09-30 | **Non corrigé, laissé au porteur** : le groupe `docker` équivaut à root, et les PR de Dependabot tournent sur un runner non éphémère. | Les fermer demande Docker *rootless*, une machine virtuelle ou des runners éphémères : un choix d'infrastructure, pas un correctif. Le guide et l'ADR disent désormais honnêtement ce que l'isolation protège. | ADR-0069 §5 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Le quota a été épuisé par une décision chiffrée d'avance.** L'ADR-0064 et le plan de `ci-rapide` annonçaient « ≈ 2,5 × plus de minutes » et demandaient au porteur de surveiller le quota. Personne ne l'a surveillé, et le quota a tenu moins d'une journée. Une mise en garde écrite dans un plan ne protège de rien : il faut une garde qui échoue. C'est pourquoi `ci_plan_test.rb` refuse désormais un job sur `ubuntu-latest`.
- **Aucune mesure « après » n'a pu être prise cette nuit.** Le script `install` crée un utilisateur et des services systemd : il ne s'exécute pas dans le conteneur de l'agent, qui l'a refusé à juste titre. Tout ce qui se mesure attend la machine du porteur.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- **Où part le coût (2026-09-29, run [36409044736](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36409044736), 14 jobs, 29 minutes facturées).** Travail utile (`bin/ci`) : 852 s. Plancher des 12 jobs de la matrice : 408 s, soit conteneur PostgreSQL 14 à 28 s (`Initialize containers`), Ruby et Node 10 à 15 s (`./.github/actions/setup`), checkout 1 à 2 s. Arrondi à la minute : + 8 minutes (21 min réelles → 29 facturées). Jobs `changes` et `ci` : 5 s chacun, 1 minute facturée chacun. Fichier et ligne qui portent le coût : `.github/workflows/ci.yml`, la matrice `tests.strategy.matrix.group` (10 jobs avec PostgreSQL) et les déclencheurs `on.push.branches` (45 % des runs).
- **Un runner auto-hébergé doit avoir une locale UTF-8.** Sous `LANG` vide (US-ASCII), la garde de pureté du domaine lève `invalid byte sequence in US-ASCII` en lisant les fichiers accentués. Les images GitHub fixent `LANG=C.UTF-8` ; `install` l'écrit dans le `.env` de chaque instance.
- **GitHub échoue un job resté 24 h sans runner**, sans réglage possible : d'où le service de relance (lot D) pour tenir 48 h.
- **`ruby/setup-ruby` n'installe ses Ruby précompilés que dans `/opt/hostedtoolcache`** : `install` crée ce dossier et le déclare dans `RUNNER_TOOL_CACHE`.
- **L'API de facturation par run ne répond rien d'utile** : `GET /actions/runs/<id>/timing` renvoie `total_ms: 0` pour tous les runs de ce dépôt. Seuls les horodatages des jobs permettent de compter.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Les chiffres « après » de chaque lot (3 runs, médiane) | Ils se mesurent sur le runner installé, sur la machine du porteur | ce chantier, dès le lot 0 fait |
| Lot E : horloge < 3 min | Dépend de la mesure du lot A | ce chantier, fermé si A tient déjà < 3 min |
| Isolation forte du runner (Docker *rootless*, VM ou runners éphémères) ; PR de Dependabot | Choix d'infrastructure du porteur (voir décisions ci-dessus) | à ouvrir si le porteur le décide |
| Actions tierces épinglées par tag (`ruby/setup-ruby@v1`, `actions/setup-node@v4`), pas par SHA | Touche tous les workflows, hors du levier de ce chantier | à ouvrir |
| La règle « documents seulement » accepte un `.md` n'importe où (`app/…/x.md`) | Antérieur au chantier (ADR-0064) | à ouvrir |
| Le cache Bundler et `node_modules` sont retéléchargés à chaque job : `actions/checkout` nettoie l'espace de travail | À mesurer d'abord (lot E) ; un cache local sur la machine serait le levier suivant | ce chantier, lot E |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
