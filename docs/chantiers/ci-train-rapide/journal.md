# Journal — Un train plus rapide sur GitHub

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-05 | Trois parts unitaires | Le chemin critique est `unit:1/2` (226 s) ; 3 parts ≈ 155 s chacune. | ADR-0107 §9 |
| 2026-11-05 | 7 parts de leçons, pas 6 | Mesure : ≈ 56 s fixes + 22 s de mise en place par part ; 6 parts ≈ 181 s (chemin critique), 7 parts ≈ 167 s et 19 tâches, une place libre sous la limite de 20. | ADR-0107 §9 |
| 2026-11-05 | B empilé sur A, C seul | A et B modifient les mêmes lignes de `ci.yml` et de la garde. | — |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- La limite de tâches simultanées du compte GitHub est de **20** : 20 tâches partent ensemble, la 21e attend (runs 41921296454 et 41917971824).
- Une part `lecons` passe ≈ 27 s dans son premier test (démarrage de Chrome, référentiel) avant la première leçon : c'est un coût fixe par part, qui plaide contre trop de parts.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | ADR-0107 §9 (amendement) |
| **UDR produits** | — |
