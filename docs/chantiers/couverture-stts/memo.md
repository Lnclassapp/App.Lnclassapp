# Memo — Une branche de la mesure des M4A jamais couverte

| | |
|---|---|
| **Type de cycle** | bugfix (tests) |
| **Statut** | livré, clos |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `fix/couverture-stts` |
| **Programme** | — |

---

## Symptôme

Suite complète de `bin/ci-quiet` (niveau train), jouée pour la PR de dépendances #361 sur `Develop` fusionné : couverture des branches 99,98 % (5120 / 5121), sous le minimum de 100 %. La branche manquante : le refus d'une table `stts` trop courte pour son en-tête, dans la mesure de la durée d'un M4A. La suite complète de la prochaine PR vers `Staging` serait rouge, quelle que soit la PR.

## Cause

Le test « an stts box without its header is unreadable » construit une piste sans boîte `stsz`. Le nombre d'échantillons se lit avant la table `stts` : la piste est refusée faute de `stsz`, et le refus de la table trop courte n'est jamais atteint. Le test passait pour une autre raison que celle qu'il nomme. Le code est conforme.

## Correctif retenu

Donner une boîte `stsz` à la piste du test : le refus vient alors de la table `stts` trop courte. Aucun code applicatif touché.

## Portes de sortie

- [x] La branche atteinte par le test (couverture de la ligne : 1) ; le fichier entier vert
- [x] `bin/ci-quiet` vert, ligne de preuve dans la PR
