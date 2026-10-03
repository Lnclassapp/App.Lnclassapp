# Plan d'exécution — Politique de cache : moins d'allers-retours jusqu'au serveur

> Cycle : [optimisation](../../workflows/optimisation.md) — **un lot = un levier = un chiffre**, lots classés par ratio gain/risque, arrêt dès la cible atteinte ; un lot devenu inutile se **ferme**.
> Format des lots : [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Mesure « avant » et leviers : [memo](memo.md). Politique proposée : [ADR-0075](../../decisions/adr/0075-politique-de-cache-reglee-sur-les-allers-retours.md).
> **Décisions du porteur du 2026-10-03** ([memo](memo.md#décisions-du-porteur-2026-10-03)) : A et B refusés (« garder » les UDR-0010, 0018 et l'ADR-0049), donc **fermés** ; C fermé avec B ; D activé par le porteur ; R étudié, Develop et Staging d'abord, après la mesure depuis Abidjan. **Aucun lot de code ne reste.**

## Graphe

```
Lot 0 — Bench et décision (fait en cadrage : 3 scripts, mesure « avant », ADR-0075 proposé)
  ↓
  ├─✗ Lot A — Activité récente rendue avec la page   FERMÉ (porteur : garder UDR-0010, UDR-0018)
  ├─✗ Lot B — Connexion et déconnexion hors Turbo     FERMÉ (porteur : garder ADR-0049)
  │     ✗ Lot C — `immutable` sur les assets           FERMÉ (non mesurable ici, dépendait de B)
  │
  ├─► Lot D — Cloudflare : Early Hints + Tiered Cache  (porteur, tableau de bord Cloudflare)
  └─► Lot R — Région europe-west4 : application ET PostgreSQL ensemble
        mesure Abidjan « avant » → Develop → mesure → Staging → mesure → production
```

Ordre par gain/risque au cadrage : A → B → D → R → C. Après les décisions du porteur, il reste **D** (sans code, premières visites) puis **R** (le seul levier sur toutes les pages, mais une migration de base).

## Contrat d'exécution de chaque lot

1. **Le bench reproductible existe** et produit la valeur *avant* : `script/perf/count_round_trips.rb` (requêtes en série, lots A et B), `script/perf/measure_browser.cjs` (lots C, D, R), `script/perf/measure_network.rb` (lot R). Ils sont versionnés (Lot 0).
2. **Les tests de non-régression fonctionnelle sont verts avant le levier** : le lot ne change rien à ce que l'écran affiche à la fin du chargement.
3. **Un seul levier**, puis le bench relancé (**3 exécutions, médiane**), avec le chiffre noté dans le memo.
4. **Gain nul ou marginal → le pas est annulé**, et le journal dit pourquoi. Une complexité ajoutée sans gain mesuré se retire.

Les lots A et B étant fermés, `count_round_trips.rb` sert de **plafond** : aucun parcours ne doit dépasser ses requêtes en série d'aujourd'hui (ADR-0075 §4.2). Les lots D et R se mesurent avec `measure_browser.cjs` et `measure_network.rb`.

> **Le chantier ne se clôt pas sans mesure après** : même machine, même volume, même méthode, au moins 3 exécutions, médiane, tests fonctionnels verts. **Sans chiffre après, la PR est rejetée.**

---

## Lot 0 — Bench et décision *(fait pendant le cadrage)*

- **Couche**       : outillage + documentation
- **Fichiers**     : `script/perf/measure_network.rb`
                     `script/perf/measure_browser.cjs`
                     `script/perf/count_round_trips.rb`
                     `docs/chantiers/politique-cache/memo.md` · `journal.md` · `plan.md`
                     `docs/decisions/adr/0075-politique-de-cache-reglee-sur-les-allers-retours.md` · `docs/decisions/adr/README.md`
- **Dépend de**    : —
- **Test associé** : les trois scripts, lancés 3 fois chacun (journal, « Protocole ») ; `bin/rubocop script/perf`
- **Done quand**   : le tableau « Mesure avant » du memo est rempli de valeurs mesurées, la ligne d'Abidjan exceptée (question 1, bloquante pour R seul)

### Activation (documentation Cloudflare, lue le 2026-10-03)

Le dépôt n'a aucun accès à la zone `lnclass.com` : le connecteur Cloudflare de la session ne couvre que la plateforme développeur (Workers, D1, KV, R2). Deux bascules, dans le tableau de bord de la zone :

1. **Early Hints** : **Speed** › **Settings**, onglet **Content Optimization**, *Early Hints* sur **On** ([doc](https://developers.cloudflare.com/cache/advanced-configuration/early-hints/)). Gratuit.
2. **Tiered Cache** : **Caching** › **Tiered Cache**, activer, topologie **Smart Tiered Cache** ([doc](https://developers.cloudflare.com/cache/how-to/tiered-cache/)). Gratuit. L'indication de région cloud ne s'applique pas : elle ne vise qu'AWS, GCP, Azure et Oracle.

Ce que Cloudflare exige pour émettre un `103`, et que nos pages remplissent : une adresse sans extension, une réponse 200, 301 ou 302, et des en-têtes `Link` en `rel=preload` (Rails les envoie déjà pour la feuille de style, le script et la police). Les indications sont gardées par adresse, sans la chaîne de requête. Elles ne contiennent que des adresses d'assets publics : aucune donnée de session. Le `103` n'est émis qu'en HTTP/2 et HTTP/3, et seuls les navigateurs Chromium (Chrome 94 et plus) s'en servent.

Vérification après activation : `curl -sv --http2 https://lnclass.com/login 2>&1 | grep '< HTTP'` doit montrer `HTTP/2 103` avant `HTTP/2 200`, à partir de la deuxième requête sur une adresse. Le proxy du conteneur de mesure peut masquer le `103` : dans ce cas, on vérifie dans l'onglet Réseau de Chrome.

---

## Lot A — Activité récente rendue avec la page — *fermé*

> **Fermé le 2026-10-03 par le porteur** : l'UDR-0010 et l'UDR-0018 sont gardées, avec leur frame différé. Fiche conservée pour mémoire.


- **Couche**       : delivery + ui
- **Fichiers**     : `app/controllers/classroom/student_homes_controller.rb`
                     `app/views/classroom/student_homes/show.html.erb`
                     `app/controllers/teams/homes_controller.rb`
                     `app/views/teams/homes/show.html.erb`
                     `test/controllers/classroom/student_homes_controller_test.rb`
                     `test/controllers/teams/homes_controller_test.rb`
                     `docs/decisions/udr/0010-accueil-eleve.md` · `docs/decisions/udr/0018-accueil-equipe.md` *(amendements)*
- **Dépend de**    : Lot 0 ; accord du porteur sur les amendements des UDR (question 3)
- **Test associé** : `student_homes_controller_test.rb` et `homes_controller_test.rb` (la page contient l'activité, sans `turbo-frame[src]`) ; `test/system/role_homes_test.rb` inchangé et vert
- **Done quand**   : `count_round_trips.rb` donne **« Clic vers l'accueil élève » 2 → 1**, **« Clic vers l'accueil équipe » 2 → 1** et **« Ouverture de lnclass.com » 3 → 2**, sur 3 exécutions. Le p95 serveur de `/students` et `/teams` reste **< 100 ms** (ADR-0067), mesuré avec `measure_screens.rb` (`PERF_ONLY=student_home,teams_home`) au volume de `script/perf/dataset.rb`

## Lot B — Connexion, inscription et déconnexion hors Turbo — *fermé*

> **Fermé le 2026-10-03 par le porteur** : l'ADR-0049 est gardé, avec le rechargement du document à chaque nouvelle session. Fiche conservée pour mémoire.


- **Couche**       : ui + delivery
- **Fichiers**     : `app/views/identity/sessions/new.html.erb`
                     `app/views/identity/teacher_registrations/new.html.erb`
                     `app/views/identity/pending_teacher_registrations/new.html.erb`
                     `app/views/classroom/joins/_signup_form.html.erb` · `app/views/classroom/joins/new.html.erb`
                     `app/views/shared/navigation/_header.html.erb` · `app/helpers/navigation_helper.rb` *(lien de déconnexion → formulaire)*
                     `app/views/identity/second_factor_enrollments/new.html.erb` · `app/views/identity/second_factors/new.html.erb` · `app/views/identity/pending_accounts/show.html.erb`
                     `app/helpers/components_helper.rb` *(seulement si `ui_button` doit savoir rendre un formulaire)*
                     `test/integration/content_security_policy_test.rb`
                     `docs/decisions/adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md` *(amendement)*
- **Dépend de**    : Lot 0 ; accord du porteur sur l'amendement de l'ADR-0049 (question 4)
- **Test associé** : `content_security_policy_test.rb` (nouveau cas : connexion et déconnexion hors Turbo, nouveau nonce dans le document d'arrivée, sans `turbo-visit-control`) ; `test/system/shared/csp_turbo_navigation_test.rb` inchangé et vert ; un PIN refusé ré-affiche le formulaire avec son message (422)
- **Done quand**   : `count_round_trips.rb` donne **« Connexion enseignant » 3 → 2**, **« Déconnexion » 3 → 2** et **« Connexion élève » 4 → 3** (puis **2** une fois A fusionné), sur 3 exécutions, aucune violation de CSP. Le rechargement forcé reste pour les renouvellements de session depuis une modale (ADR-0055), qui ne sont pas touchés

## Lot C — `immutable` sur les assets digérés — *fermé*

> **Fermé le 2026-10-03.** Sa clause de fermeture s'applique : WebKit n'est pas installable dans le conteneur de mesure (`playwright install` y est proscrit), et Chromium ne revalide pas les sous-ressources au rechargement. Le gain, un aller-retour vers Cloudflare au rechargement de connexion sous Safari, n'est donc pas mesurable. Il se rouvre si quelqu'un mesure les revalidations sur un iPhone (inspecteur web de Safari).


- **Couche**       : infrastructure (configuration)
- **Fichiers**     : `config/environments/production.rb`
- **Dépend de**    : Lot B (sans rechargement forcé, il reste peu de rechargements à servir)
- **Test associé** : `measure_browser.cjs` étendu à WebKit (Playwright) : nombre de requêtes de revalidation (304) au rechargement d'une page
- **Done quand**   : au rechargement d'une page sous WebKit, **les revalidations d'assets passent de N à 0**, au même point de mesure. **Si WebKit ne peut pas être installé, ou si N vaut déjà 0 : le lot est fermé**, et le journal dit pourquoi

## Lot D — Cloudflare : Early Hints et Tiered Cache *(action du porteur, hors dépôt)*

- **Couche**       : périphérie (tableau de bord Cloudflare, zone `lnclass.com`)
- **Fichiers**     : aucun dans le dépôt ; le journal note la date et les deux réglages activés
- **Dépend de**    : Lot 0 ; accès du porteur à la zone (question 5)
- **Test associé** : `measure_browser.cjs`, ligne « première (cache vide) »
- **Done quand**   : le `DOMContentLoaded` médian d'une première visite de `/` et de `/login` baisse d'**au moins 30 %** (782 et 871 ms avant), au même point de mesure, sur 3 exécutions. Sinon les réglages sont désactivés

## Lot R — Région : application et PostgreSQL en `europe-west4` *(décision du porteur, hors code)*

- **Couche**       : infrastructure Railway (environnements Develop, Staging, puis production)
- **Fichiers**     : aucun dans le dépôt ; `docs/decisions/adr/0075-…` §4.3 passe à « Accepté » avec la région retenue et la mesure qui la justifie
- **Dépend de**    : la mesure « avant » depuis Abidjan, sur l'environnement concerné ; une fenêtre de maintenance. Ordre : Develop, puis Staging, mesurés, puis production
- **Test associé** : `measure_network.rb` et `measure_browser.cjs` lancés depuis la Côte d'Ivoire, avant et après, 3 fois chacun ; `/up` en 200 ; comptes de lignes par table identiques avant et après
- **Done quand**   : depuis Abidjan, **le surcoût d'une requête jusqu'au serveur passe sous 150 ms** et le **chargement d'une page déjà visitée sous 500 ms** (`load`, médiane), mesurés sur Staging puis sur la production. Le `x-runtime` de `/` et de `/login` reste sous 10 ms, ce qui prouve que l'application et la base sont dans la même région. Aucune perte de données

### Étude (porteur : « oui », 2026-10-03)

**État au 2026-10-03.** Dans les trois environnements, tout est en `asia-southeast1-eqsg3a` : l'application (1 réplica), PostgreSQL 18 (1 réplica, volume `postgres-volume` de 5 000 Mo provisionnés) et le bucket Railway d'Active Storage (région `sin`).

**Ce que dit Railway** ([docs, « Regions »](https://docs.railway.com/deployments/regions#impact-of-region-changes)) : changer la région d'un service **sans volume** se fait sans interruption. Un service **avec volume** voit ses données migrées, et il est **interrompu pendant toute la migration**, dont la durée dépend de la taille du volume.

**⚠️ Changement en attente sur Develop.** Un changement non appliqué (patch créé le 2026-10-03 à 20:36 UTC) déplace **l'application seule** vers `europe-west4-drams3a`. Appliqué tel quel, il laisserait PostgreSQL à Singapour : chaque requête SQL traverserait l'Europe et l'Asie, sur des pages qui en font 4 à 25. Develop deviendrait bien plus lent qu'aujourd'hui. **La base doit être dans le même changement.**

**Déroulé proposé, environnement par environnement** (Develop, puis Staging, puis production) :

1. **Avant** : `measure_network.rb` et `measure_browser.cjs` depuis Abidjan sur l'environnement (3 fois). Relever le nombre de lignes de chaque table (`SELECT relname, n_live_tup FROM pg_stat_user_tables` après `ANALYZE`, ou `count(*)` sur les tables métier).
2. **Sauvegarde** : un `pg_dump` de la base. Facultatif sur Develop, **obligatoire en production**.
3. **Un seul changement** : PostgreSQL **et** l'application en `europe-west4-drams3a`, appliqués ensemble pendant la fenêtre. Interruption attendue pendant la migration du volume.
4. **Vérification** : `/up` en 200, nombre de lignes identique, connexion d'un compte de test. Le `x-runtime` des pages publiques reste sous 10 ms.
5. **Après** : les mêmes mesures depuis Abidjan, 3 fois, comparées à l'étape 1. Si le gain n'y est pas, on revient à Singapour : c'est le même changement en sens inverse, avec la même interruption.
6. **Bucket** : il reste à Singapour dans un premier temps. Il ne sert qu'aux photos de profil (servies par l'application, gardées par le navigateur, ADR-0060) et aux fichiers d'import (lus par un job). On mesure `GET /accounts/:id/photo` après la migration. Un bucket européen, avec copie des objets, ne se fait que si cette mesure le demande (chantier à part, ADR-0047).

---

## Dispatch

```
Vague 1 : Lot 0                 → fait (cadrage)
Vague 2 : Lot D ‖ Lot R         → le porteur (Cloudflare ; Railway), hors dépôt ;
                                  mesures « après » rejouées ici dès qu'un réglage ou une région change
Lots A, B, C                    → fermés, aucun agent de code
```

Aucun agent de code n'est lancé : les seuls lots ouverts sont hors du dépôt. Une seule PR pour le chantier, vers `Develop` : documentation, scripts de mesure et ADR-0075.

## Vérification de collision

Doublons vérifiés mécaniquement (`awk … | sort | uniq -d` : aucune sortie).

| Fichier | Lot propriétaire |
|---|---|
| `script/perf/*` | Lot 0 |
| `docs/chantiers/politique-cache/*` | Lot 0 (l'orchestrateur reporte les chiffres des lots) |
| `docs/decisions/adr/0075-…` · `docs/decisions/adr/README.md` | Lot 0 |
| `docs/decisions/udr/0010-…` · `docs/decisions/udr/0018-…` | Lot A |
| `docs/decisions/adr/0049-…` | Lot B |
| `app/helpers/navigation_helper.rb` · `app/helpers/components_helper.rb` | Lot B |
| `config/environments/production.rb` | Lot C |

Aucun lot ne touche `config/routes.rb`, `config/locales/*.yml` ni `app/views/layouts/`. Si le lot A ou B a besoin d'une clé de traduction, il s'arrête : le fichier remonte au Lot 0.

## Portes de sortie

- [x] `memo.md` : métrique nommée, **valeur avant chiffrée**, volume de données précisé, cible chiffrée *(sauf la ligne d'Abidjan : bloque le lot R seul)*
- [x] Protocole de mesure écrit et reproductible par quelqu'un d'autre
- [x] Explorer coût rendu : où part réellement le temps (pas une hypothèse)
- [ ] ADR écrit si un contrat change (callbacks contournés, dénormalisation, cache, port modifié) *(ADR-0075 proposé ; amendements de l'ADR-0049 et des UDR-0010 et 0018 avec leurs lots)*
- [x] Bench versionné, produisant la valeur avant
- [ ] Tests de non-régression fonctionnelle verts **avant** le premier levier
- [ ] Un lot = un levier = un chiffre
- [ ] Chaque levier sans gain mesuré a été **annulé**, pas conservé
- [ ] Bench après : même machine, même volume, même méthode, ≥ 3 exécutions, médiane
- [ ] Tableau `Mesures` complété (Avant / Cible / Après)
- [ ] **Challenger a relancé le bench lui-même** et obtenu le gain annoncé
- [ ] Résultat fonctionnel strictement identique (aucun écran, aucune sortie modifiés)
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] `journal.md` : leviers abandonnés et pourquoi — c'est la partie la plus réutilisable

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur (un PIN refusé), mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce cycle, il **relance lui-même les bancs** (`count_round_trips.rb`, `measure_browser.cjs`, et `measure_network.rb` depuis la Côte d'Ivoire pour le lot R) et doit obtenir le gain annoncé, sinon la PR ne passe pas.
