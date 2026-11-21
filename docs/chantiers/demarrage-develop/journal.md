# Journal — demarrage-develop

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-21 | Semer en tâche de fond après `/up`, un seul `db:prepare` (celui de `bin/docker-entrypoint`) | Seul le semis fait varier le démarrage (26 s à 16 min) ; le sortir du chemin de `/up` borne le pire cas | Non : ordre de démarrage de deux environnements de test, aucun contrat applicatif |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-21 · demarrage-develop · Un semis en échec sur Develop ou Staging doit-il encore arrêter le conteneur ? Avant, `db:seed || exit 1` coupait le site (boucle de redémarrage) ; désormais l'échec s'écrit « [démarrage] semis en échec » dans les journaux et le site reste servi — appliqué : journaliser, site servi ; autres : arrêter le conteneur ; recommandé : journaliser (un site en 502 ne dit pas pourquoi aux testeurs)
- [ ] 2026-11-21 · demarrage-develop · Pendant le semis en tâche de fond (quelques secondes à un quart d'heure), Develop sert les leçons et le jeu de la version précédente, sous le même plafond CPU — appliqué : accepté ; autres : arrêter le site pendant le semis ; recommandé : accepté

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- L'API Hostinger ne garde que les 300 dernières lignes par service : le début d'un démarrage long est perdu. D'où le repère `[démarrage] conteneur démarré <UTC>` écrit par l'entrypoint et lu par `script/mesure/demarrage`.
- Ruby 3.4.13 absent de ruby-build : définition copiée de 3.4.9 avec la somme SHA-256 officielle (index de cache.ruby-lang.org), compilée ~10 min ; rôle PostgreSQL `dev-rails` à créer pour les tests.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Le chargement des leçons garde déjà une empreinte par leçon (« unchanged ») : sans changement, le semis de Develop coûte ~26 s sous 0,4 CPU ; c'est le rechargement de leçons et le rattrapage de l'activité simulée qui durent.
- Les dates des lignes « [build] » de Hostinger sont à l'heure locale du VPS (UTC+1), celles des journaux en UTC.

## Leviers abandonnés et pourquoi

- **Ne rejouer leçons et jeu qu'au changement d'une empreinte globale** : économise ~26 s dans le cas sans changement, rien dans le pire cas (des leçons ont changé) ; inutile une fois le semis hors du chemin de `/up`.
- **Semer dans un job Solid Queue au démarrage** : même effet, mais touche l'application et la production ; l'entrypoint de `test.yaml` suffit et n'atteint pas la production.

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
