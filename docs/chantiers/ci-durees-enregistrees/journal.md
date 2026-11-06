# Journal — Durées système enregistrées par la CI

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-06 | Un run rouge n'enregistre pas la durée | un test qui échoue vite sous-pèserait le fichier et ouvrirait le budget | non |
| 2026-11-06 | Après un enregistrement, `bin/ci-quiet` s'arrête (sortie 1) au lieu de jouer les autres étapes | l'arbre modifié ne prouve pas HEAD : le run complet serait rejoué après le commit | non |
| 2026-11-06 | Pas de ligne de preuve quand l'arbre diffère de HEAD | la ligne nomme HEAD ; collée dans la PR, elle prouvait un commit qui n'avait pas les changements | non |
| 2026-11-06 | Le vérificateur rend « À COMMITER » quand `bin/ci-quiet` a enregistré une durée | il ne modifie ni ne commite rien : l'exécutant commite, puis on revérifie | non |

## À trancher

- …

## Ce qui a dérapé

- Les assets ne sont pas compilés dans une session neuve : `yarn build && yarn build:css` avant tout test système.

## Ce qu'on a appris sur la codebase

- La commande suggérée par la garde (`record_command`) n'avait pas `COVERAGE=0` et échouait sur le seuil de 100 %.

## Dette laissée derrière

- Aucune.
