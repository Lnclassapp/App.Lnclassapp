# Memo — La perf des imports et les CI répétées ralentissent chaque PR

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-19 |
| **Branche** | `perf/ci-perf-a-la-demande` |

## Le problème

La CI GitHub est coupée (ADR-0069) : chaque PR se prouve par un `bin/ci` local, sur un conteneur de 4 cœurs. Il dure environ 16 min et rien ne s'y parallélise de plus : tests unitaires et système occupent déjà 4 processus, et deux étapes jouées ensemble se bloquent sur la base de test (5 `Deadlocked` sur #237, un test de perf à 70 s pour 60 s sur #262).

Deux pertes évitables :

1. **La perf des imports tourne à chaque `bin/ci`**, même quand la PR ne touche ni les imports, ni les jobs, ni la base. Sur GitHub, un run partiel la laisse déjà de côté ; la promotion vers `Staging` la rejoue toujours (ADR-0039, ADR-0069 §9).
2. **La CI complète est rejouée à chaque lot poussé.** Sur #237, deux `bin/ci` complets (39bd16ad, puis 30ba2b44 après les corrections de revue) : le premier ne prouvait déjà plus rien.

## Mesure avant

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Étape « Tests: Import performance » | Conteneur cloud 4 cœurs, #237 (locales, vues, tests, un contrôleur Stimulus) | 1 min 31 s | < 1 s quand la PR ne touche pas les chemins de la perf | sortie de `bin/ci` (`tmp/ci.log`) |
| `bin/ci` complet | Même conteneur, #237 (39bd16ad) | 16 min 19 s | ≈ 14 min 50 s | idem |
| `bin/ci` complets par PR | #237, reprise du 2026-10-19 | 2 (≈ 32 min) | 1, sur le head final | journal de session |

## Hors périmètre

- La CI GitHub : la perf y suit déjà le tirage (run complet ou partiel), et `CI=true` la joue comme avant.
- Les tests unitaires et système, qui restent complets dans `bin/ci`.
- Rallumer la CI GitHub (`CI_ENABLED`) : décision du porteur, non retenue ici.
