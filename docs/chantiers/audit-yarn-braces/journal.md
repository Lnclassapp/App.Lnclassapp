# Journal — L'audit Yarn bloque toute la CI sur une faille de braces sans correctif

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-03 | Ignorer l'avis `1240992` jusqu'au 2026-10-17, sous garde-fou daté | Porteur : option 1 ; aucune version corrigée, dépendance de build seulement | Non |

## Ce qui a dérapé

- Rien dans ce chantier. L'échec a été vu sur les PR #144 (blog) et #154 (retrait de debugbar), qui ne touchaient pas aux dépendances JavaScript.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Retirer la dérogation dès que `braces` publie une version corrigée (puis `yarn up braces`) | Aucune version corrigée le 2026-10-03 | Réexamen le 2026-10-17, imposé par le garde-fou |

## Clôture

| | |
|---|---|
| **Livré le** | — |
| **PR** | à venir |
