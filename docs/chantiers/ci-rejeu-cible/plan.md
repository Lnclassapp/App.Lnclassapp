# Plan d'exécution — Rejouer seulement ce qu'un changement peut casser

> Cycle optimisation : un lot = un levier = un chiffre, par gain/risque décroissant. Un lot sans gain mesuré se ferme.
> Une PR pour le chantier, base `Develop` (porteur, 2026-10-27). Lots séquentiels, un seul exécutant : B et C partagent `config/ci.rb`.

## Graphe

```
Lot A — la règle : jamais --full vers Develop (docs, agents)
Lot B — verdict par étape (bin/ci-quiet, script/ci/scope.rb, config/ci.rb)
Lot C — perf ciblée, et perf enfin sautée en local (config/ci.rb)
Lot D — délai court de l'inscription en test
Lot E — étapes en parallèle en local          → mesuré ; décision dans le memo
Lot F — découper les fichiers système lents     → mesuré ; décision dans le memo
```

---

## Lot A — La règle

- **Fichiers**     : `CLAUDE.md`, `docs/workflows/README.md`, `.claude/agents/verificateur-ci.md`
- **Done quand**   : aucun texte ne prescrit `--full` avant `Develop`

## Lot B — Verdict par étape

- **Fichiers**     : `bin/ci-quiet`, `script/ci/scope.rb`, `script/ci/plan.rb`, `config/ci.rb`, `test/config/ci_scope_test.rb`, ADR-XXXX-verdict-par-etape-de-la-ci
- **Done quand**   : après un train vert, une ligne de JavaScript ne rejoue ni la suite Rails (hors tests qui lisent le front) ni la perf — scénario S2 du memo, médiane de 3

## Lot C — Perf ciblée

- **Fichiers**     : `config/ci.rb`, `test/guards/ci_plan_test.rb`
- **Done quand**   : une ligne d'un test de perf ne rejoue que ce test (S3) ; sans écart sur `PERF_PATHS`, la perf est sautée en local (S1)

## Lot D — Délai court de l'inscription

- **Fichiers**     : `config/environments/test.rb`, deux vues `new` d'inscription, `test/support/signup_steps_helper.rb`, trois tests système, un test de contrôleur
- **Done quand**   : durée cumulée des 10 fichiers système de l'inscription en baisse (médiane de 3), CA-C4, CA-C5, CA-C6 toujours vrais

## Contrat d'exécution

1. Le bench est le protocole du memo (§ Mesure avant), commandes exactes, rejouable par un autre.
2. Non-régression verte avant le premier levier : train vert sur `16cbd82` (mesure avant n° 3).
3. Un levier, un chiffre.
4. Gain nul ou marginal : le pas est annulé, la raison écrite.

**Le chantier ne se clôt pas sans mesure après** : même machine, même méthode, ≥ 3 exécutions, médiane. Sans chiffre après, la PR est rejetée.

## Portes de sortie

- [x] `memo.md` : métrique nommée, valeur avant chiffrée, volume précisé, cible chiffrée
- [x] Protocole de mesure écrit et reproductible
- [x] Explorer coût rendu : où part réellement le temps
- [x] ADR écrit (le contrat du verdict change)
- [x] Bench versionné (protocole du memo)
- [x] Non-régression verte avant le premier levier
- [x] Un lot = un levier = un chiffre
- [ ] Chaque levier sans gain mesuré a été annulé
- [ ] Bench après : même machine, même méthode, ≥ 3 exécutions, médiane
- [ ] Tableau `Mesures` complété (Avant / Cible / Après)
- [ ] Challenger a relancé le bench lui-même
- [x] Résultat fonctionnel identique (aucun écran de production modifié : l'attribut de délai n'est rendu qu'en test)
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] `journal.md` : leviers abandonnés et pourquoi
