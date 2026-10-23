# Journal — MVP Lnclass Teacher & Student — pilote du 27 octobre

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- 2026-10-23 — La session cloud n'avait ni gems ni base : `.claude/hooks/session-start.sh` s'arrêtait sans message sur `ls -d …/chrome-linux/chrome` (Playwright range désormais Chromium sous `chrome-linux64/`), tué par `set -o pipefail` avant `bin/setup`. Corrigé par la PR `fix/session-start-chromium` (motif `chrome-linux*`, `|| true`). Leçon : un hook `set -euo pipefail` ne doit jamais laisser un `ls` sans correspondance tuer la suite.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
