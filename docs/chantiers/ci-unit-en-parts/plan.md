# Plan d'exécution — La suite unitaire en parts sur GitHub

Un seul levier, donc un seul lot.

## Lot A — Deux parts unitaires, couverture fusionnée

- **Couche**       : CI (`config/`, `.github/`, `script/ci/`, `test/`)
- **Fichiers**     : `config/ci.rb` (groupe `unit` découpé comme `system`)
                     `.github/workflows/ci.yml` (tirage `unit:1/2`, `unit:2/2` ; envoi des `.resultset.json` ; tâche `coverage` ; verdict `ci`)
                     `test/coverage_profile.rb` (profil SimpleCov partagé), `test/test_helper.rb` (`COVERAGE_PART`)
                     `script/ci/coverage_collate` (fusion, nombre de parts exigé, seuil)
                     `script/ci/test_timings.yml` (durées des fichiers unitaires, pour équilibrer)
                     `test/guards/ci_plan_test.rb` · ADR-0064 §8 · ADR-0107 §8
- **Dépend de**    : —
- **Test associé** : `test/guards/ci_plan_test.rb` (les parts jouent exactement la suite entière ; `coverage` fusionne 2 résultats avec le seuil ; `ci` l'attend)
- **Done quand**   : sur GitHub, chaque tâche `unit unit:k/2` < 300 s (visé < 180 s) contre 316 s coupée avant, et `coverage` affiche 100 % / 100 % sur la fusion, médiane de 3 exécutions.

## Contrat d'exécution

1. Bench : les durées par tâche de la CI GitHub (avant : run 41911503446).
2. Non-régression : la suite entière locale, seuil 100 % compris (`bin/ci-quiet`, niveau train) ; la fusion locale des deux parts donne le même 100 %.
3. Un levier, mesure, et retrait si le gain est nul.

**Le chantier ne se clôt pas sans mesure après** (même runner, même suite, ≥ 3 exécutions, médiane).

## Portes de sortie

- [x] `memo.md` : métrique nommée, **valeur avant chiffrée**, volume de données précisé, cible chiffrée
- [x] Protocole de mesure écrit et reproductible par quelqu'un d'autre
- [x] Explorer coût rendu : où part réellement le temps (pas une hypothèse)
- [x] ADR écrit si un contrat change (ADR-0064 §8, ADR-0107 §8)
- [ ] Bench versionné, produisant la valeur avant
- [ ] Tests de non-régression fonctionnelle verts **avant** le premier levier
- [x] Un lot = un levier = un chiffre
- [ ] Chaque levier sans gain mesuré a été **annulé**, pas conservé
- [ ] Bench après : même machine, même volume, même méthode, ≥ 3 exécutions, médiane
- [ ] Tableau `Mesures` complété (Avant / Cible / Après)
- [ ] **Challenger a relancé le bench lui-même** et obtenu le gain annoncé
- [ ] Résultat fonctionnel strictement identique (aucun écran, aucune sortie modifiés)
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] `journal.md` : leviers abandonnés et pourquoi
