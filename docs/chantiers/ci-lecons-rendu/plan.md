# Plan — ci-lecons-rendu

Décision du porteur (2026-11-12) : au train, on ne rend **que les leçons nouvelles ou modifiées** (2 ou 3 parts pour une vague) ; sans leçon changée, **2 leçons témoins au plus**. Les 223 leçons ne sont plus toutes rejouées à chaque train.

## Lot A — Rendu ciblé au train (un levier, un chiffre)

**Fichiers** : `.github/workflows/ci.yml` (job `plan`, job `lecons`), `test/system/catalog/lesson_rendering_test.rb` (`Selection.call`), `test/guards/ci_plan_test.rb`, un fichier versionné des 2 leçons témoins (`script/ci/lecons_temoins.txt`, un chemin par ligne).

1. Job `plan`, étape `changes` : à partir de la liste `files` déjà lue (fichiers de la PR), garder les `docs/contenus/lecons-traitees/*/*/*.json` présents dans l'arbre (un fichier supprimé ne se rend pas). Sorties nouvelles :
   - `lecons_files` : la liste séparée par des virgules ; vide → le contenu de `script/ci/lecons_temoins.txt` ;
   - `lecons_parts` : tableau JSON `[1..n]`, n = max(1, ⌈nombre de fichiers / 10⌉) (10 leçons au plus par part : décision du porteur du 2026-11-12 ; ≈ 20 s par leçon + ≈ 50 s d'installation, soit ≈ 250 s au pire).
   - Lecture du diff impossible → comportement prudent : liste vide côté sélection = les témoins **et** un avertissement `::warning::` dans le journal (pas d'échec silencieux).
2. Job `lecons` : `name: lecons ${{ matrix.part }}/${{ needs.plan.outputs.lecons_count_parts }}` (ou équivalent), `matrix.part: ${{ fromJSON(needs.plan.outputs.lecons_parts) }}`, env `LECONS: ${{ needs.plan.outputs.lecons_files }}`, `LECONS_PART: ${{ matrix.part }}/<n>`. `timeout-minutes: 5`, `fail-fast: false`, un seul processus : inchangés.
3. `Selection.call` : `LECONS=<liste>` accepte aussi `LECONS_PART` (découpage glouton existant `part`, appliqué à la liste nommée). `LECONS=tout` reste disponible à la main.
4. Témoins : 2 leçons v3 qui couvrent formules KaTeX, figures, tableau/QCM et feuilles (choisies et justifiées dans le commentaire du fichier).
5. Commentaire du job `lecons` dans `ci.yml` : remplacer l'historique des 24/32 parts par la règle ci-dessus et la mesure avant.
6. Tests : `ci_plan_test.rb` vérifie la matrice dynamique (issue de `plan`), `LECONS_PART` = `${{ matrix.part }}/<n>`, 5 min, un processus ; test de `Selection` : liste nommée + `LECONS_PART` découpe, les témoins existent et sont v3.

**Done quand** : la tâche `lecons` d'un train sans leçon changée coûte **1 part, ≤ 3 min de machine** (avant : 32 parts, 98,7 min) ; un train avec N leçons changées en coûte ⌈N/10⌉ parts, chacune < 5 min ; tests de garde verts ; aucun défaut détecté n'est retiré de la vérification.

## Contrat d'exécution

1. Mesure avant : dans `memo.md` (run #541, `cf0483e70`).
2. Non-régression : `test/guards/ci_plan_test.rb` et les tests de sélection de `lesson_rendering_test.rb` verts avant et après ; les tests « fichier piégé » inchangés.
3. Un seul levier (ce lot).
4. Mesure après : le prochain train vers `Staging`, même protocole (`gh api …/check-runs`), complété dans `memo.md` ; localement, les 2 témoins rendus 3 fois, médiane.

**Le chantier ne se clôt pas sans la mesure après.**

## Portes de sortie

- [x] `memo.md` : métrique nommée, valeur avant chiffrée, volume précisé, cible chiffrée
- [x] Protocole de mesure écrit et reproductible par quelqu'un d'autre
- [x] Où part le temps : ≈ 20 s par leçon × 223, ≈ 49 s d'installation × 32 parts
- [ ] ADR écrit si un contrat change : ce que prouve un train change (ADR-0107 amendé) → `ADR-XXXX-ci-lecons-rendu-cible`
- [ ] Bench versionné, produisant la valeur avant (commande `gh api` du memo)
- [ ] Tests de non-régression fonctionnelle verts avant le levier
- [ ] Un lot = un levier = un chiffre
- [ ] Bench après : même méthode, ≥ 3 exécutions, médiane
- [ ] Tableau `Mesures` complété (Avant / Cible / Après)
- [ ] Challenger a relancé le bench lui-même
- [ ] Résultat fonctionnel identique (aucun écran modifié)
- [ ] rubocop · tests · brakeman : au vert
- [ ] `journal.md` : leviers abandonnés et pourquoi
