# Journal — Deux outils de CI en retard sur leurs règles

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-28 | Un test lie le plafond du script à celui de `javascript_bundle_test.rb` | L'écart est né d'un ADR qui n'a modifié qu'un des deux endroits | Non |
| 2026-10-28 | Ne pas réenregistrer les durées existantes | Chaque fichier se corrige à son prochain enregistrement ; tout réenregistrer déplacerait la base du budget de toutes les PR ouvertes | Non |

## Mesure après

| Métrique | Avant | Après | Comment mesurée |
|---|---|---|---|
| Durée lue pour `course_sheet_browser_test.rb` | 10,33 s | 15,58 s | `bin/rails test … -v`, ancien et nouveau lecteur sur le même journal |
| Plafond de « Assets: Budget » | 60 Ko | 61 Ko | `bin/check-asset-budget` |

## Ce qui a dérapé

- Rien.

## Ce qu'on a appris sur la codebase

- Le premier test système d'un processus porte le démarrage de Puma dans sa ligne `-v` : tout lecteur de ces journaux doit accepter une sortie entre le nom du test et sa durée.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Durées sous-évaluées du premier test dans `test_timings.yml` | Corrigées au prochain enregistrement de chaque fichier | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-28 |
| **PR** | à venir |
| **ADR produits** | aucun |
| **UDR produits** | aucun |
