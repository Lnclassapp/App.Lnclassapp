# Journal — Durées système enregistrées par la CI

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-06 | Un run rouge n'enregistre pas la durée | un test qui échoue vite sous-pèserait le fichier et ouvrirait le budget | non |

## À trancher

- …

## Ce qui a dérapé

- Les assets ne sont pas compilés dans une session neuve : `yarn build && yarn build:css` avant tout test système.

## Ce qu'on a appris sur la codebase

- La commande suggérée par la garde (`record_command`) n'avait pas `COVERAGE=0` et échouait sur le seuil de 100 %.

## Dette laissée derrière

- Aucune.
