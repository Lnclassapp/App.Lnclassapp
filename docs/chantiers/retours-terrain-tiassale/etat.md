# État — retours-terrain-tiassale

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-21 · **Vague** : 1 · **Où on en est** : vague 1 fusionnée dans `Develop` ; rien vers `Staging` ni `main`

## Lots

| Chantier | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|
| Cadrage et playbook ville (D5) | `claude/keen-keller-127bnu` | #664 | `ac5c6fb` | fusionné (`91c72bf`) |
| Ruby 3.4.13 et brakeman 8.1.1 (hors programme, bloquant commun) | `chore/ruby-3-4-13` | #666 | `0c761a8` | fusionné (`0ea6871`) |
| `entree-eleve-unifiee` (D1, D2) · ADR-0141, UDR-0176 | `feature/entree-eleve-unifiee` | #668 | `5cb9542` | fusionné (`dc5308b`) |
| `recherche-etablissement` (D3) · ADR-0142, UDR-0177 | `feature/recherche-etablissement` | #665 | `db5e511` | fusionné (`f2d8bb2`) |
| `partage-classe-k-factor` (D4) · ADR-0143, UDR-0178 | `feature/partage-classe-k-factor` | #667 | `d47cb2d` | fusionné (`f3c78c9`) |

## Décisions

Prises :
- D1 à D5 du [memo](memo.md), 2026-11-20, par le porteur.
- Ruby 3.4.9 → 3.4.13 : Brakeman 8.1.1 signale la CVE-2026-132825 et `--ensure-latest` bloquait la CI de toutes les branches. Décidé par le porteur le 2026-11-21.
- Routage des modèles (ADR-0104) rappelé aux sessions par le porteur le 2026-11-21 : exécution sur Sonnet, vérifications sur Haiku, revues et arbitrage sur Opus.
- Points réversibles des `## À trancher` des trois journaux : tranchés par l'orchestrateur le 2026-11-21, sur l'option prudente appliquée.

Ouvertes, pour le porteur (voir les journaux) :
- `recherche-etablissement` : la direction garde son code d'établissement (droits).
- `recherche-etablissement` : **sécurité**, dette antérieure. Sans JavaScript, « Continuer » de la cascade élève, hors mode entrée, envoie le code secret en GET. Un `/bugfix` est recommandé.

## Écarts de la session

- #664 a été fusionnée sans l'agent `fusionneur` (documentation seule).
- #666 et #665 ont été fusionnées par l'orchestrateur avec une preuve `bin/ci-quiet` portant sur un SHA antérieur, l'empreinte étant identique (« already proven »). Pour #665, le delta (journal seul) a été vérifié par `git diff`. Pour #666, il ne l'a pas été : le SHA prouvé n'existait plus après la réécriture du commit. `bin/ci-quiet` rejoue la ligne stockée et ne réécrit pas le SHA : à corriger dans l'outil.
- La CI locale de #667 a tourné sous Ruby 3.4.9 (construction de 3.4.13 refusée dans son bac à sable). La suite complète en 3.4.13 tournera au train vers `Staging`.

## Prochaine action

Recette sur `Develop` (`bin/tester-pr`, 390 px et ordinateur) des trois parcours. Ensuite, le train vers `Staging`, quand le porteur le décide.

## Prompt de reprise

```
Orchestrateur de retours-terrain-tiassale. Lis docs/chantiers/retours-terrain-tiassale/etat.md. La vague 1 est fusionnée dans Develop. Pose au porteur les deux décisions ouvertes (code d'établissement de la direction ; /bugfix du code secret en GET), puis prépare la recette et le train vers Staging s'il le demande.
```
