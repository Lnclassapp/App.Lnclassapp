# Journal — Environnements de PR sur Railway

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-21 | La migration de `railway.json` passe après les lots 0, B, C | `railway.ts` n'est pas lu au déploiement : il s'applique en ligne de commande, connecté au projet, et décrit tout le projet. Écrit à la main, il risque de supprimer un service ; la connexion du porteur à Railway ne marche pas | non |
| 2026-10-21 | Reconnaître une PR par une variable de Develop, pas par la forme du nom Railway | Le nommage des environnements de PR n'est pas documenté par Railway | oui, ADR-0108 §3 |
| 2026-10-21 | Une réponse servie derrière le mot de passe ne part jamais `public` | Revue sécurité : Thruster met en cache les réponses `public` et les ressert sans mot de passe (vérifié avec thruster 0.1.27) | oui, ADR-0108 §4 |
| 2026-10-21 | Le démarrage d'un environnement de PR l'écrit au journal, avec un avertissement sans mot de passe | Revue des échecs silencieux : une variable scellée sur Develop fermait la PR sans aucune trace | oui, ADR-0108 §4 |
| 2026-10-21 | Non retenu : limiter `PrEnvironment.active?` à `RAILS_ENV=production` pour Puma | Le seul chemin trouvé est `railway run bin/dev` lié à un environnement de PR (worker absent, adaptateur `solid_queue` du développement). Personne ne lance le développement contre une PR ; le correctif changeait le contrat gelé du Lot 0 et trois tests | non |

## Essai sur Railway

Essai du 2026-10-22, PR #279 (la PR #278 avait reçu un environnement vide, voir « Ce qui a dérapé »). Réglages : PR Environments et Bot PR Environments activés, base Develop ; `PR_BASE_ENVIRONMENT=Develop` et `PR_ACCESS_PASSWORD` sur le service web de Develop ; Serverless. Constaté depuis l'API Railway, le journal de déploiement et `curl` :

| Vérification | Attendu | Constaté |
|---|---|---|
| Environnement créé à l'ouverture de la PR | oui, à partir de Develop | oui : `App.Lnclassapp-pr-279`, services web et Postgres, déploiement SUCCESS en 3 min |
| Pré-déploiement | `db:prepare db:seed` vert, « 3 établissements, 63 classes… » au journal | oui : « 3 établissements, 63 classes, 63 enseignants, 2555 élèves » |
| Journal de démarrage | `[config] PR environment (base Develop, name …): password required…` | oui ; aucun processus Solid Queue au démarrage |
| Adresse sans mot de passe | demande de mot de passe (401) ; `/up` répond | oui : 401 sans mot de passe ou avec un mauvais, 200 avec le bon, `/up` 200 ; asset `cache-control: private`, 401 sans mot de passe après un appel authentifié |
| Connexion `0531000001` / 2468 | accueil enseignant | oui : 303 vers `/teachers`, « Accueil · Enseignant », « Bonjour, Junior » |
| Veille | service endormi 10 minutes après la dernière visite | oui : « Sleeping » environ 15 minutes après la dernière visite ; au réveil, 502 puis 200 |
| Stockage de fichiers | bucket propre à la PR, pas celui de Develop | oui : `BUCKET_NAME` différent de celui de Develop |
| Fermeture de la PR | environnement supprimé | oui : l'environnement vide de la PR #278 a disparu à sa fermeture |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **« Pas d'environnement pour les robots » excluait toutes les PR de Claude.** Railway compte comme PR de robot une PR ouverte par l'application GitHub de Claude, même au nom du porteur : la PR #278 a reçu un environnement vide, sans service. Bot PR Environments est donc activé ; contrepartie : les PR de Dependabot ou d'autres robots ont aussi le leur.
- **Les variables n'étaient pas posées** sur le service web de Develop, alors que le réglage semblait fait : sans elles, l'environnement de PR aurait tourné comme une production ouverte, sans données de test. À vérifier par lecture (`railway variable list`), pas par souvenir.
- **Develop ne s'était pas redéployé** après les fusions des PR #275 et #276 : il tournait encore le 2026-10-22 sur le commit de la PR #274. Déployé à la main sur `738af3bf` (SUCCESS). Cause non trouvée : à surveiller à la prochaine fusion.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Railway (documentation du 2026-10-21) : `railway.json` n'est plus lu après le 2026-12-01 ; les bases d'une PR partent vides ; les variables scellées ne sont pas copiées dans les PR ; aucun filtre des PR par branche cible ; aucune variable ne signale un environnement de PR.
- En production, `seeds: false` (`config/database.yml`) empêche `db:prepare` de semer : seul le `db:seed` du pré-déploiement sème, une fois par déploiement d'une PR. L'idempotence sert aux redéploiements (chaque commit poussé).
- Les leçons complètes (`db/seeds/demo/lecons_completes.rb`, demandé par le porteur le 2026-10-22) : 198 sur 213 importées par la vraie chaîne et publiées en environ 70 s sur une base neuve, 4 s rejouées. L'import accepte 50 fichiers par envoi (ADR-0068).
- Les `limits_concurrency` des jobs reposent sur Solid Queue : en `:async`, ils ne s'appliquent pas (ADR-0108 §5).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Lot A, fin : `railway config apply` sur Develop, puis retrait de `railway.json` | `.railway/railway.ts` est écrit (2026-10-22, sortie de `railway config migrate` pour production, Staging et Develop, réunie). `railway config plan` : production et Staging « already up to date » ; Develop, 1 changement (`healthcheckTimeout` null → 120, celui de `railway.json` ; `startCommand` "" → null). L'application écrit dans Railway : au porteur (`railway config apply` sur Develop). Piège : lancé derrière `timeout`, le CLI se croit trop ancien (le SDK lit sa version par `$_`). **Échéance : 2026-12-01** | ce chantier |
| 15 leçons de `docs/contenus/lecons-traitees/1ere-a` refusées par l'import (`series_not_allowed` : série « A » en 1ère, où le référentiel n'a que A1, A2, C, D) | Correction du contenu, hors de ce chantier : choisir A1 ou A2, ou ouvrir la série A en 1ère | contenus |
| Lot D : supprimer l'environnement d'une PR de promotion | Conditionnel : à observer à la prochaine promotion Develop → Staging | ce chantier, si besoin |
| Mise en veille effective, stockage de fichiers propre à chaque PR | Non vérifiables hors Railway | première PR d'essai, par le porteur |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
