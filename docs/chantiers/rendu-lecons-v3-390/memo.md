# Memo — Rendu des leçons v3 à 390 px

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-02 |
| **Branche** | `fix/rendu-lecons-v3-390` |
| **Programme** | — |

---

## Symptôme

Vérification à l'écran des leçons v3 (Tle et 1ère), page du cours, compte élève :

1. « Prépare interros » : les blocs « À retenir : » affichent `**…**` en clair (« l'**intégrale** », « **diploïde** ») ; la fiche de révision rend le même texte en gras.
2. À 390 px la page défile à l'horizontale : « Calcul intégral » Tle D (435 px), « Limites et continuité » (408 px, libellé `.ps-question-label`), « Énergie cinétique » 1ère C (516 px, « À retenir » de la notion 2).
3. `script/contenus/valider.rb` laisse passer une réponse acceptée en double une fois normalisée (« insaturée » / « insaturee ») que l'import refuse (`duplicate_accepted`).

## Reproduction

Importer les leçons (`db/seeds/demo/lecons_completes.rb`), ouvrir `/courses/calcul-integral` et `/courses/limites-et-continuite-4` en élève à 390 px ; `ruby script/contenus/valider.rb` sur `cbf4eaed^:…/1ere-c/physique-chimie/generalites-sur-les-composes-organiques.json`.

## Cause

1. `_sheet.html.erb` écrivait `box_text` tel quel ; la fiche passe par `sheet_text` (gras, italique, formules, tout échappé).
2. Les formules centrées défilent déjà dans `.katex-display`, mais l'énoncé d'une question est un élément flex (`min-width: auto`) qui reste aussi large que la formule ; les formules en ligne (`white-space: nowrap`) du « À retenir » et de « Je m'entraîne » n'avaient pas de cadre.
3. Le validateur ne lisait pas la clé `practice` (« Je m'entraîne »), que l'import valide avec les règles de structure des exercices ; il ignorait aussi `blank` (cases d'une question).

## Portée

Toutes les leçons v3 ; aucune donnée à réparer (le contenu fautif est déjà corrigé, `cbf4eaed`).

## Hors périmètre

- Les autres règles de forme de `practice` (énoncé, nombre de questions) : le validateur n'applique que la structure de chaque question.
- « Énergie cinétique » 1ère C (516 px) : non reproduit en local après la mise à jour de Develop ; couvert par les mêmes règles, à reconfirmer à l'écran.

## Preuves

Test rouge puis vert : `test/integration/catalog/prepare_interros_test.rb`, `test/script/contenus/valider_test.rb` ; test système `test/system/catalog/long_formulas_test.rb` (jugé en CI : pas de pilote Chrome compatible dans l'environnement de l'agent). Captures 390 px et ordinateur, avant/après, décrites dans la PR (jamais commitées).
