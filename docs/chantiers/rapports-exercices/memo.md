# Memo — Comprendre où en est la classe sur un exercice

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `feature/rapports-exercices` |
| **Programme** | `refonte-application`, vague V3 ([feuille de route §5](../refonte-application/feuille-de-route.md#v3--suivi-pédagogique-enseignant)) : tranche « exercices » du chantier prévu `rapports-de-classe` |

---

## Le problème

Un enseignant assigne un exercice à sa classe, les élèves le font, et **l'enseignant n'en apprend rien**. Il ne sait ni combien d'élèves l'ont fait, ni si la notion est comprise, ni quelles questions ont piégé la classe, ni quels élèves décrochent. L'ancienne application avait un rapport par exercice (synthèse et détaillé), mais il est cassé, et ses chiffres étaient faux (un taux de réussite qui dépasse 100 % dès qu'un élève recommence, des badges Bronze invisibles, un cache jamais invalidé).

Le besoin du porteur (2026-10-04) : **mesurer la compréhension des exercices et présenter l'information à l'enseignant au bon moment.**

## Pour qui

- **L'enseignant (Teacher)**, après avoir assigné un exercice à une de ses classes : il veut savoir s'il peut avancer ou s'il doit revenir sur la notion.
- *(à griller : direction, équipe, élève, parent)*

## Pourquoi maintenant

La V1 (boucle pédagogique) est en production : les élèves font des exercices et des sessions s'accumulent. `rapports-de-classe` est le premier chantier de la V3, et la V5 (suivi des remédiations par l'enseignant, AS-17) en dépend.

## Hors périmètre

- Les essais au-delà du troisième et les sessions de remédiation : leur suivi relève de la V5 (AS-17).
- *(à compléter pendant le grill)*

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Les « stats sur les exercices », c'est quoi ? | Mesurer la compréhension des exercices et la présenter à l'enseignant au bon moment ; partir de ce que prévoit la V3. (porteur, 2026-10-04) | Chantier côté enseignant, tranche « exercices » de `rapports-de-classe` (AS-21, AS-22, AS-23, AS-25 candidates). Le « bon moment » devient une question de cadrage à part entière. |
| Comment se lit la compréhension ? | Chaque élève est classé selon son score en **trois couleurs** : **rouge** = en difficulté, moins de 70 % ; **jaune** = de 70 à 80 % ; **vert** = plus de 80 %. Un **cercle** prend la couleur de la catégorie dominante. **Au clic sur une catégorie**, on voit le taux de réussite des questions. (porteur, 2026-10-04) | Une lecture en trois catégories remplace les quatre KPI et les deux tableaux de l'ancien rapport. Les bornes ne sont pas celles des libellés de l'ADR-0033 (« En difficulté » < 50, « Fragile » 50-69, « Acquis » ≥ 70) : amendement d'ADR à prévoir. Le détail par question est filtré par catégorie d'élèves. |
| Les bornes des couleurs (< 70 / 70-80 / > 80) contredisent les libellés de l'ADR-0033 : laquelle garder ? | **L'ancienne règle** (porteur, 2026-10-04) : **rouge** « En difficulté » sous 50 %, **jaune** « Fragile » de 50 à 69 %, **vert** « Acquis » à 70 % et plus. 50 pile est jaune, 70 pile est vert. | Les seuils `PASS_THRESHOLD` (50) et `MASTERY_THRESHOLD` (70) de l'ADR-0033 servent tels quels : **aucun amendement d'ADR** sur le barème. Ce sont aussi les bornes de l'ancien rapport (« À réviser » / « À surveiller » / « Maîtrisé »). Tests aux bornes 49, 50, 69, 70. |
| Quel score classe l'élève : meilleur, premier ou dernier essai ? | Proposé : le premier essai terminé (la correction affichée après chaque question fait réciter le corrigé dès le deuxième essai). **Refusé par le porteur** (2026-10-04) : le premier essai cache les progrès, or montrer le progrès des élèves est l'atout de Lnclass. **Retenu : la moyenne des scores des trois premiers essais terminés** (un ou deux si l'élève n'en a pas fait plus). | La catégorie d'un élève peut bouger jusqu'à son troisième essai, puis elle est figée (sessions immuables, ADR-0054). Les essais au-delà du troisième et les sessions de remédiation ne comptent pas. Le taux par question se calcule sur ces mêmes essais : il ne peut donc pas dépasser 100 % (défaut AS-22 de l'ancienne application). Tests : 1, 2, 3 et 4 essais ; moyenne aux bornes 50 et 70. |
| Les élèves qui n'ont pas fini l'exercice, et le cercle d'une classe où 2 élèves sur 45 ont rendu ? | Proposé et **validé par le porteur** (2026-10-04) : le cercle reste **gris, avec « 2/45 »**, tant que **moins de 5 élèves** ont fini un essai ; au-delà, il prend la couleur dominante, et le compte « rendus / effectif » reste affiché. Un élève sans essai terminé n'entre dans **aucune** couleur. | Même seuil de 5 que l'espace direction (« — » sous 5 élèves ayant rendu). Le compte « rendus / effectif » fait partie de l'affichage, pas seulement la couleur. Tests à 4 et 5 élèves ayant rendu. |
| Où l'information apparaît-elle ? | Sur la carte de l'exercice, **bord bas** : les icônes de badges **à gauche**, l'icône de la statistique **à droite, isolée** des autres. (porteur, 2026-10-04) | La carte d'exercice dans la classe change : UDR obligatoire (amendement de l'UDR de la carte, ou nouvelle UDR). Les compteurs de badges (AS-25) entrent dans le périmètre. |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
