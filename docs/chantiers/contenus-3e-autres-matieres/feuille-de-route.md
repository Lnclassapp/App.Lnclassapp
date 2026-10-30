# Feuille de route — Leçons de 3ème en SVT, Physique-Chimie, Histoire-Géographie, Français et EDHC, et leurs figures

> Programme (`docs/workflows/programme.md`) : il ne produit pas de code. Chaque vague ouvre son chantier `docs/chantiers/<slug>/` (memo, prd, plan), avec la ligne `Programme : contenus-3e-autres-matieres`, sa PR et sa mise en production.
> Seule la vague qui s'ouvre est détaillée en lots, dans le `plan.md` de son chantier.

## Les vagues

Ordre choisi par le porteur (grill, revu après le premier plan) : **FR, HG, SVT, PC, EDHC**.

```
Vague 1  contenus-3e-francais            script aligné sur l'import + prompt par matière + 10 leçons → PR (aucun code déployé)
  ↓
Vague 2  contenus-3e-histoire-geographie frise, carte (3 fonds), schéma, courbe  + 10 leçons → PR, train, production
  ↓
Vague 3  contenus-3e-svt                 planches (8 de SVT)                     + 10 leçons → PR, train, production
  ↓
Vague 4  contenus-3e-physique-chimie     tracé optique, molécule, planches (3)   + 10 leçons → PR, train, production
  ↓
Vague 5  contenus-3e-edhc                aucune sorte nouvelle (schéma, carte, graphique déjà là) + 10 leçons → documentation
```

| Vague | Chantier | Sortes de figures livrées | Leçons | Porte de sortie |
|---|---|---|---|---|
| 1 | `contenus-3e-francais` | aucune ; `valider.rb` accepte les types de questions que l'import accepte déjà (rédigée, appariement…) et avertit sous 50 % de questions corrigées automatiquement | 10 de Français | les 10 fichiers passent `valider.rb` sans avertissement, relus, envoyés au porteur ; prompt généralisé aux 5 matières |
| 2 | `contenus-3e-histoire-geographie` | `timeline`, `map` (`cote_d_ivoire`, `africa`, `world`), `diagram`, `stat_chart` `line`  | 10 d'HG | code en production ; les 10 fichiers s'importent en brouillon en production et leurs figures sont `ready` |
| 3 | `contenus-3e-svt` | `plate` et ses 8 planches de SVT | 10 de SVT | idem ; planches relues par un enseignant de SVT sur captures |
| 4 | `contenus-3e-physique-chimie` | `optics`, `molecule`, planches `dynamometer`, `electrolyser`, `eudiometer` | 10 de PC | idem ; planches relues par un enseignant de PC |
| 5 | `contenus-3e-edhc` | aucune | 10 d'EDHC | les 10 fichiers passent `valider.rb`, relus, envoyés au porteur |

**Dépendances réelles.** La vague 5 ne dépend que de la vague 2 (schéma, carte de Côte d'Ivoire) : elle peut partir dès que la vague 2 est en production, sans attendre SVT et PC, si le porteur le décide. Les vagues 3 et 4 sont indépendantes l'une de l'autre (elles se partagent seulement `plate` : la vague 3 crée le module, la vague 4 ajoute ses planches).

**Réutilisation.** Une sorte livrée par une vague est réutilisée telle quelle par les suivantes. Une vague qui a besoin de changer la forme d'une sorte déjà livrée rouvre la décision (amendement de l'ADR), jamais en silence dans son lot.

## Registre des décisions de fondation

| Décision | Options | Recommandation | Bloque | Tranchée par | Statut |
|---|---|---|---|---|---|
| Sortes de figures nouvelles, leurs paramètres, leurs listes fermées | voir l'ADR §3 | A : sortes à identifiants fermés | vagues 2, 3, 4 | ADR-0117 | Accepté (porteur, 2026-10-30) |
| Dessin des sortes nouvelles (catégories teinte + motif, numérotation de repli) | — | — | vagues 2, 3, 4 | UDR-0142 | Accepté (porteur, 2026-10-30) |
| Textes de Français : œuvres et droits | textes originaux · une œuvre · plusieurs œuvres en courtes citations | plusieurs œuvres, courtes citations référencées, textes longs du domaine public ou originaux (porteur) | vague 1 | memo, grill | Tranché |

## Registre des contradictions

| Sources | Écart | Tranché par |
|---|---|---|
| ADR-0116 §4.2 (« liste fermée de 5 sortes ») ↔ besoin des matières | la liste est trop courte | ADR-0117, qui amende ADR-0116 §4.2 |
| `valider.rb` (4 types à choix) ↔ import (tous les types de question) | le script refuse des questions que l'import accepte | vague 1 : le script reprend la règle de l'import (`Entities::Assessment::Question`) |
| CLAUDE.md « une PR par chantier » ↔ « matière par matière » | une seule PR ne livre pas matière par matière | programme : un chantier, donc une PR, par matière |

## Portes du programme

- [x] Vague 1 livrée : 10 fichiers de Français envoyés au porteur (#373)
- [x] ADR et UDR des figures acceptés avant le Lot 0 de la vague 2 (porteur, 2026-10-30)
- [x] Vagues 2 à 4 : 10 fichiers chacune, figures `ready` à 390 px et sur ordinateur (captures envoyées) (#374, #376, #377)
- [ ] Vagues 2 à 4 : code en production — reste ouverte tant que le train `Staging` → `main` n'est pas passé
- [x] Vague 5 livrée (#375)
- [x] 50 leçons rangées dans `docs/contenus/lecons-traitees/3eme/`, README des contenus à jour
- [x] `journal.md` du programme clos (2026-10-30)

## Challenger empirique — par vague, non négociable

Un rôle **distinct de celui qui a écrit le code** exécute : il importe en brouillon une leçon de la vague, ouvre sa fiche de révision à 390 px et sur ordinateur, vérifie que chaque figure est `ready` et lisible, fait varier un curseur ; puis il importe un fichier dont une figure est incohérente (lieu inconnu, partie inconnue) et constate le refus `figure_invalid`. **Il ne relit pas le code, il le met à l'épreuve.**
