# Journal — Aucune page au-dessus de 600 ms côté serveur

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-21 | Mesure en production locale par la pile Rack (Integration::Session) et dans Chromium à 390 px, sur le jeu standard, avec les leçons de Develop chargées | Reproductible par le challenger, sans accès à lnclass.com (proxy 403) ; reprend les comptes de `script/pages_lentes.rb` | Non |
| 2026-11-21 | Plafonds CPU de Develop simulés par cgroups (0,1 CPU base, 0,4 CPU application) | Mesurer ce que le porteur voit sur develop.lnclass.com sans toucher au VPS | Non |
| 2026-11-21 | Lot C : `PrepareSheetsQuery#call(only:)` ne construit (questions, copies, devoirs dus) que les exercices demandés ; numéro = rang dans la feuille entière ; seul `StudentAssignedSheetsQuery` le passe. | « Ma classe », médiane de 3 exécutions de `script/mesure/pages` (rôle élève) : allocations 114 963 → 54 483 (-52,6 %), p50 164,3 → 124,3 ms, p95 200,1 → 175,6 ms, SQL 91 → 91 (inchangé). Seuil de -30 % atteint. | Non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [x] 2026-11-21 · pages-sous-600ms · Relever les plafonds CPU de Develop et Staging (`deploy/hostinger/test.yaml` : base `cpus: 0.1`, application `cpus: 0.4`) ? Le VPS est à 4 % de CPU en moyenne ; `cpu_shares: 256` donne déjà la priorité à la production — appliqué : rien (infrastructure hors de ce chantier, PR à part) ; autres : base 0,5 et application 1,0 en gardant `cpu_shares: 256` ; recommandé : base 0,5 et application 1,0 (sous plafonds actuels, les pages coûtent 2 à 6 fois plus : catalogue de l'élève 49 → 298 ms p95) — tranché par le porteur, 2026-11-21 : base 0,5, application 1,0
- [ ] 2026-11-21 · pages-sous-600ms · Raccourcir le démarrage de Develop (16 min 36 s de 502 après le déploiement du 2026-11-21 : `db:prepare db:seed` avec chargement automatique des leçons et jeu standard, puis un second `db:prepare` par `bin/docker-entrypoint`, sous les plafonds) ? — appliqué : rien (constat seulement) ; autres : semer en tâche de fond après le démarrage de Puma, ou ne rejouer leçons et jeu qu'au changement de leur empreinte ; recommandé : chantier `demarrage-develop` à part, mesuré
- [ ] 2026-11-21 · pages-sous-600ms · Mesurer depuis Abidjan (commandes du memo, § « Commandes pour le porteur ») : le serveur de production répond en ~30 ms, la lenteur ressentie sur lnclass.com est entre le téléphone et le serveur — appliqué : commandes écrites ; recommandé : le porteur les lance et colle les chiffres dans ce journal

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- 2026-11-21 · #671 · plafonds CPU de Develop et Staging : base 0,1 → 0,5, application 0,4 → 1,0 (`cpu_shares` inchangé)

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Ruby 3.4.13 absent de ruby-build dans le conteneur (définition copiée de 3.4.9, compilée ~10 min) : le hook de démarrage échouait sans le dire.
- Rejouer le démarrage de Develop en local (sous plafonds) a d'abord chargé les 463 leçons absentes de la base : premier démarrage, pas comparable à celui de Develop (leçons « unchanged »). Arrêté ; seul le chiffre réel des journaux (16 min 36 s) est retenu.
- La mesure navigateur en production locale servie en HTTP : Rails se croit en HTTPS (`assume_ssl`) et refuse l'origine `http://` du formulaire ; Chromium ne laisse pas réécrire `Origin`. Connexion par `context.request.post`, une fois par rôle (limite de 5 connexions par minute).

## Leviers abandonnés et pourquoi

- **Leçon : lectures de notion en lot (lot D)** — 5 requêtes par notion à l'ouverture d'une leçon (`record_reads`), 75 ms p95 : les grouper change le contrat de `RecordEssentialRead` (ADR) pour un gain sous la cible.
- **« Ma classe » : une seule lecture pour toutes les leçons assignées** — le nombre de requêtes (91) reste proportionnel aux leçons ; le lot C a suffi (514 ms p95 sous plafonds) ; à reprendre si une mesure réelle de Develop dépasse 600 ms.
- **Service worker : `navigationPreload`** — le programme intercepte chaque navigation sans préchargement ; la mesure dans Chromium headless n'a montré aucun coût de démarrage (0–1 ms), et l'émulation réseau ne s'applique pas aux requêtes du programme : coût non prouvé, rien changé.
- **Cache de fragments ou de pages** — aucune page au-dessus de la cible en production locale ; un cache sur des pages d'élève demanderait une menace écrite (données personnelles) pour un gain non nécessaire.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Garde de requêtes (lot B) : le cache de requêtes survit d'une visite à l'autre dans un test d'intégration (compte faussé à 0), d'où `clear_query_cache` avant la visite comptée ; vérifiée en ajoutant 5 requêtes distinctes par devoir dans `StudentAssignedSheetsQuery#exercises` (« Ma classe » 53 pour un budget de 48, échec constaté, modification retirée) ; une seule requête par devoir (+3) ou un appel dupliqué à l'identique (mis en cache) passent sous la marge de 25 %.

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
