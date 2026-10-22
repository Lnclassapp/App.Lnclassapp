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

Première PR d'essai ouverte le 2026-10-22, après les réglages du porteur (Bot PR Environments désactivés ; `PR_BASE_ENVIRONMENT`, `PR_ACCESS_PASSWORD` sur Develop ; Serverless). À constater sur son environnement :

| Vérification | Attendu | Constaté |
|---|---|---|
| Environnement créé à l'ouverture de la PR | oui, à partir de Develop | |
| Pré-déploiement | `db:prepare db:seed` vert, « 3 établissements, 63 classes… » au journal | |
| Journal de démarrage | `[config] PR environment (base Develop, name …): password required…` | |
| Adresse sans mot de passe | demande de mot de passe (401) ; `/up` répond | |
| Connexion `0531000001` / 2468 | accueil enseignant | |
| Veille | service endormi 10 minutes après la dernière visite | |
| Stockage de fichiers | bucket propre à la PR, pas celui de Develop | |
| Fermeture de la PR | environnement supprimé | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Railway (documentation du 2026-10-21) : `railway.json` n'est plus lu après le 2026-12-01 ; les bases d'une PR partent vides ; les variables scellées ne sont pas copiées dans les PR ; aucun filtre des PR par branche cible ; aucune variable ne signale un environnement de PR.
- En production, `seeds: false` (`config/database.yml`) empêche `db:prepare` de semer : seul le `db:seed` du pré-déploiement sème, une fois par déploiement d'une PR. L'idempotence sert aux redéploiements (chaque commit poussé).
- Les `limits_concurrency` des jobs reposent sur Solid Queue : en `:async`, ils ne s'appliquent pas (ADR-0108 §5).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Lot A : migration de `railway.json` vers `.railway/railway.ts` | Demande `railway config migrate`, connecté au projet ; la connexion du porteur à Railway ne marche pas. **Échéance : 2026-12-01** | ce chantier, seconde PR |
| Lot D : supprimer l'environnement d'une PR de promotion | Conditionnel : à observer à la prochaine promotion Develop → Staging | ce chantier, si besoin |
| Mise en veille effective, stockage de fichiers propre à chaque PR | Non vérifiables hors Railway | première PR d'essai, par le porteur |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
