# Memo — Deux outils de CI en retard sur leurs règles

| | |
|---|---|
| **Type de cycle** | correction |
| **Statut** | livré |
| **Ouvert le** | 2026-10-28 |
| **Branche** | `fix/outils-ci-budgets` |

## Le problème

Relevé pendant les Lots E et F de `contenu-en-blocs` :

1. **`bin/check-asset-budget` plafonne le JavaScript commun à 60 Ko gzip**, alors que l'ADR-0114 l'a relevé à 61 Ko et que `test/javascript_bundle_test.rb` dit 61. Un point d'entrée entre 60 et 61 Ko passe le test mais fait échouer l'étape « Assets: Budget ».
2. **`script/ci/record_timings` perd la durée du premier test système d'une exécution.** Capybara écrit « starting Puma... » sur la même ligne que le nom du test ; la durée arrive trois lignes plus bas et n'est rattachée à rien. Sur `course_sheet_browser_test.rb` : 10,33 s notées pour 15,58 s réelles. Le budget de la suite système (ADR-0069 §9) se calcule sur ces durées.

## Hors périmètre

- Réenregistrer les durées déjà dans `script/ci/test_timings.yml` : elles se corrigent au prochain enregistrement de chaque fichier.
- Le plafond lui-même : il reste celui de l'ADR-0114.
