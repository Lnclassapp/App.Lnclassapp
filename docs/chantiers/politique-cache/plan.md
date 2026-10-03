# Plan d'exécution — Politique de cache : moins d'allers-retours jusqu'au serveur

> Cycle : [optimisation](../../workflows/optimisation.md) — **un lot = un levier = un chiffre**, lots classés par ratio gain/risque, arrêt dès la cible atteinte ; un lot devenu inutile se **ferme**.
> Format des lots : [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Mesure « avant » et leviers : [memo](memo.md). Politique proposée : [ADR-0069](../../decisions/adr/0069-politique-de-cache-reglee-sur-les-allers-retours.md).
> **Rien n'est lancé** tant que le porteur n'a pas répondu aux questions du memo : A attend l'accord sur les UDR-0010 et 0018, B l'accord sur l'ADR-0049, R la mesure depuis Abidjan.

## Graphe

```
Lot 0 — Bench et décision (fait en cadrage : 3 scripts, mesure « avant », ADR-0069 proposé)
  ↓
  ├─► Lot A — Activité récente rendue avec la page (UDR-0010, UDR-0018)   ┐ code, en parallèle
  └─► Lot B — Connexion et déconnexion hors Turbo (ADR-0049)              ┘ (fichiers disjoints)
        ↓
      Lot C — `immutable` sur les assets (à fermer si non mesurable)

  ⋯ hors dépôt, à tout moment, par le porteur :
  Lot D — Cloudflare : Early Hints + Tiered Cache
  Lot R — Région : application + PostgreSQL en europe-west4  (attend la mesure depuis Abidjan)
```

Ordre par gain/risque : **A** (la page la plus ouverte par l'élève et par l'équipe, risque faible) → **B** (parcours rare, car la session est permanente ; risque moyen) → **D** (sans code) → **R** (le seul levier sur toutes les pages, mais une migration de base) → **C** (marginal).

## Contrat d'exécution de chaque lot

1. **Le bench reproductible existe** et produit la valeur *avant* : `script/perf/count_round_trips.rb` (requêtes en série, lots A et B), `script/perf/measure_browser.cjs` (lots C, D, R), `script/perf/measure_network.rb` (lot R). Ils sont versionnés (Lot 0).
2. **Les tests de non-régression fonctionnelle sont verts avant le levier** : le lot ne change rien à ce que l'écran affiche à la fin du chargement.
3. **Un seul levier**, puis le bench relancé (**3 exécutions, médiane**), avec le chiffre noté dans le memo.
4. **Gain nul ou marginal → le pas est annulé**, et le journal dit pourquoi. Une complexité ajoutée sans gain mesuré se retire.

La connexion d'un élève dépend des deux lots A et B. Chaque lot est mesuré sur ses propres parcours ; la connexion d'un élève est mesurée une fois A et B fusionnés (4 → 2).

> **Le chantier ne se clôt pas sans mesure après** : même machine, même volume, même méthode, au moins 3 exécutions, médiane, tests fonctionnels verts. **Sans chiffre après, la PR est rejetée.**

---

## Lot 0 — Bench et décision *(fait pendant le cadrage)*

- **Couche**       : outillage + documentation
- **Fichiers**     : `script/perf/measure_network.rb`
                     `script/perf/measure_browser.cjs`
                     `script/perf/count_round_trips.rb`
                     `docs/chantiers/politique-cache/memo.md` · `journal.md` · `plan.md`
                     `docs/decisions/adr/0069-politique-de-cache-reglee-sur-les-allers-retours.md` · `docs/decisions/adr/README.md`
- **Dépend de**    : —
- **Test associé** : les trois scripts, lancés 3 fois chacun (journal, « Protocole ») ; `bin/rubocop script/perf`
- **Done quand**   : le tableau « Mesure avant » du memo est rempli de valeurs mesurées, la ligne d'Abidjan exceptée (question 1, bloquante pour R seul)

---

## Lot A — Activité récente rendue avec la page

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

## Lot B — Connexion, inscription et déconnexion hors Turbo

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

## Lot C — `immutable` sur les assets digérés

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
- **Fichiers**     : aucun dans le dépôt ; `docs/decisions/adr/0069-…` §4.3 passe à « Accepté » avec la région retenue et la mesure qui la justifie
- **Dépend de**    : la mesure « avant » depuis Abidjan (question 1) ; la décision du porteur et une fenêtre de maintenance (question 2). Ordre : Develop, puis Staging, mesurés, puis production
- **Test associé** : `measure_network.rb` et `measure_browser.cjs` lancés depuis la Côte d'Ivoire, avant et après, 3 fois chacun ; `bin/rails test` vert sur l'environnement migré ; `/up` en 200
- **Done quand**   : depuis Abidjan, **le surcoût d'une requête jusqu'au serveur passe sous 150 ms** et le **chargement d'une page déjà visitée sous 500 ms** (`load`, médiane), mesurés sur Staging puis sur la production, sans perte de données (comptes de lignes identiques avant et après la migration)

---

## Dispatch

```
Vague 1 : Lot 0                 → fait (cadrage)
Vague 2 : Lot A ‖ Lot B         → 2 agents, worktrees isolés, dès les accords du porteur
          Lot D, Lot R          → le porteur, hors dépôt, sans attendre la vague 2
Vague 3 : Lot C                 → 1 agent, après B (ou fermé)
```

```bash
git worktree add ../lnclass-politique-cache-lot-a -b perf/politique-cache-lot-a perf/politique-cache
git worktree add ../lnclass-politique-cache-lot-b -b perf/politique-cache-lot-b perf/politique-cache
```

Chaque agent travaille avec des chemins **absolus** (`git -C <worktree>`), ne touche **aucun fichier hors de son champ `Fichiers`** et remonte s'il en a besoin. Une seule PR pour le chantier, vers `Develop`.

## Vérification de collision

Doublons vérifiés mécaniquement (`awk … | sort | uniq -d` : aucune sortie).

| Fichier | Lot propriétaire |
|---|---|
| `script/perf/*` | Lot 0 |
| `docs/chantiers/politique-cache/*` | Lot 0 (l'orchestrateur reporte les chiffres des lots) |
| `docs/decisions/adr/0069-…` · `docs/decisions/adr/README.md` | Lot 0 |
| `docs/decisions/udr/0010-…` · `docs/decisions/udr/0018-…` | Lot A |
| `docs/decisions/adr/0049-…` | Lot B |
| `app/helpers/navigation_helper.rb` · `app/helpers/components_helper.rb` | Lot B |
| `config/environments/production.rb` | Lot C |

Aucun lot ne touche `config/routes.rb`, `config/locales/*.yml` ni `app/views/layouts/`. Si le lot A ou B a besoin d'une clé de traduction, il s'arrête : le fichier remonte au Lot 0.

## Portes de sortie

- [x] `memo.md` : métrique nommée, **valeur avant chiffrée**, volume de données précisé, cible chiffrée *(sauf la ligne d'Abidjan : bloque le lot R seul)*
- [x] Protocole de mesure écrit et reproductible par quelqu'un d'autre
- [x] Explorer coût rendu : où part réellement le temps (pas une hypothèse)
- [ ] ADR écrit si un contrat change (callbacks contournés, dénormalisation, cache, port modifié) *(ADR-0069 proposé ; amendements de l'ADR-0049 et des UDR-0010 et 0018 avec leurs lots)*
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
