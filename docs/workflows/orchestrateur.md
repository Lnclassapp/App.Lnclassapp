# Orchestrateur court

> Une session d'orchestration découpe, lance, arbitre et fusionne ; elle ne code pas. Ce fichier fixe sa durée, l'état qu'elle laisse et ce qu'elle délègue.
> Processus maître : [`README.md`](README.md). Contrat des sessions qu'elle lance : [`contrat-de-session.md`](contrat-de-session.md).

## Pourquoi

Mesure du 2026-11-05, sur 123 sessions : un orchestrateur Opus tenu sur tout un programme a coûté 86,76 $ (1,07 M de tokens produits), une vague revient à 30 à 44 $. Une session longue relit tout son passé à chaque tour, se compacte, perd des faits (deux ADR ont pris le même numéro après une reprise), puis passe la main dans l'urgence.

## 1. Une session par vague, ou par jour

Une session d'orchestration couvre **une vague** d'un programme, ou **une journée** de travail sur un chantier, la plus courte des deux. Jamais un programme entier.

Elle passe la main dès que l'un de ces signes apparaît :

| Signe | Ce qu'on fait |
|---|---|
| La vague est fusionnée, ou la journée finie | `etat.md` à jour, fin de session |
| Première compaction du contexte | `etat.md` à jour, fin de session, la suivante repart du fichier |
| 40 commits sur la branche de la session | idem (règle de sobriété de `CLAUDE.md`) |
| Quota proche de l'épuisement | idem, avant d'être coupé |

## 2. L'état écrit : `etat.md`

L'état vit dans `docs/chantiers/<slug>/etat.md` (le chantier ou le programme orchestré), modèle dans [`_TEMPLATE/etat.md`](../chantiers/_TEMPLATE/etat.md). Il dit :

- **Où on en est** : la vague, en une ligne.
- **Les lots** : session, branche, PR, SHA de tête vérifié, état.
- **Les décisions** : prises (avec leur date et qui), et ouvertes (renvoi à `## À trancher` des journaux, pas de copie).
- **La prochaine action**, et le **prompt de reprise** à coller tel quel dans la session suivante.

Règles :

- **Toute nouvelle session d'orchestration commence par lire `etat.md`**, puis vérifie sur GitHub ce qui a bougé depuis (PR fusionnées, SHA de tête). Elle ne relit pas les transcriptions des sessions précédentes.
- **Un seul commit d'état par session**, en fin de session : `docs(<slug>): état de fin de session`. Pas de commit d'état à chaque fusion : pendant la session, l'état est dans la conversation.
- `etat.md` ne contient ni secret, ni identifiant, ni transcription : des faits et des liens.

## 3. Qui fait quoi

| Travail | Qui | Modèle |
|---|---|---|
| Cadrer, découper, trancher, arbitrer une revue, résoudre un conflit, décider une fusion qui n'est pas de routine | l'orchestrateur | **Opus** |
| Exécuter un lot | `executant-lot` | **Sonnet** |
| Vérifier la CI d'une branche | `verificateur-ci` | **Haiku** |
| **Fusionner une PR de routine** | `fusionneur` | **Sonnet** |

**Une fusion de routine** remplit toutes ces conditions, vérifiées par l'agent `fusionneur` : PR ouverte vers `Develop`, prête (pas en brouillon), sans conflit, assignée à la session qui la demande ou sans assigné, ligne de preuve `bin/ci-quiet` dans la description sur le SHA de tête actuel, aucune revue « changements demandés » en attente. Une condition manque : l'agent ne fusionne pas et rend la main avec la condition manquante. L'orchestrateur tranche.

Ne sont jamais de routine : une PR vers `Staging` ou `main`, une PR qui touche des droits, des données de production ou un secret, une PR dont le porteur a demandé à voir le résultat avant la fusion.

## 4. Fin de session

1. `etat.md` à jour (lots, PR, SHA, décisions, prochaine action, prompt de reprise).
2. Un commit, poussé (documentation seule : commit direct sur `Develop` permis par `CLAUDE.md`).
3. Le dernier message au porteur tient en trois lignes : ce qui est fusionné, ce qui tourne, la prochaine action. Pas de question (contrat de session) : les décisions ouvertes sont dans les journaux, la boîte de 12 h les relève.
