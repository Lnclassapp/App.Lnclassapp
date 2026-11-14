# Journal — Les leçons de Physique-Chimie de 1ère C et D

> Rempli **pendant** le chantier.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-01 | 12 contenus pour 13 intitulés : C1 et D1 sont la même notion ; « Énergie potentielle » (C) et « de pesanteur » (D) restent deux leçons. | Contenus différents (élastique en C) | Non |
| 2026-11-01 | Aucune sorte nouvelle de figure. | Les situations s'y ramènent | Non |

## Points pédagogiques tranchés

> **Tranché le 2026-11-14** par le validateur pédagogique (chantier [`validation-pedagogique-agent`](../validation-pedagogique-agent/journal.md#décisions-du-validateur), ADR-XXXX-validateur-pedagogique-agent). Chaque point ci-dessous a sa décision (Confirmé, Corrigé, Retiré ou reformulé, Hors base) et sa justification dans la table de sa matière. Plus aucun point n'attend d'enseignant.

Les points sont dans la section « Points pédagogiques tranchés » du [journal du programme](../contenus-v3-tous-niveaux/journal.md#points-pédagogiques-tranchés), tranchés le 2026-11-14 par le validateur pédagogique (lignes P3), pour ne pas les tenir en double.

## Relecture indépendante (une par leçon, Opus, calculs refaits)

- Travail et puissance (translation) : 3 défauts de forme corrigés (énoncé « vitesse constante » faux, barème, étapes citées).
- Généralités : 3 défauts corrigés (question non tranchable sur un isomère de B, étape du raisonnement, énoncé de l'entraînement) ; calculs justes.
- Rotation : 10 corrections minimales (justification de W = M·θ complétée, perpendiculaires au guidon, barème, formulations) ; réponses inchangées.
- Alcanes : 10 défauts (pentane et non butane pour C5H12, décompte des O, corrections désignant une réponse par sa place, question sur les isomères) ; réponses inchangées.
- Énergie cinétique : 5 défauts dont 4 `tolerance` contenant une phrase au lieu d'un nombre (refusé à l'import, invisible de `valider.rb`) ; « référentiel galiléen » retiré.
- Alcènes et alcynes : 5 défauts (énoncés ambigus sur une seule liaison multiple, figures permutées) ; calculs justes.
- Le benzène : 9 défauts mineurs (une donnée qui donnait la réponse, renvoi à une réponse par sa place, formulations) ; réponses inchangées.
- Énergie potentielle : 2 formulations corrigées ; calculs et signes justes.
- Énergie potentielle de pesanteur : 4 défauts dont **une réponse attendue changée** (entraînement de la notion 1 : « positive / négative ») ; correction fausse d'une question, chute de « 1 s » physiquement fausse.
- Pétrole et gaz naturels : « gazole lourd » pour C14H30 corrigé, lien non vérifiable Baleine / Vridi retiré ; calculs justes.
- Énergie mécanique : 6 défauts (droites infinies donnant Ec < 0 remplacées par des segments, renvois par la place, numéros d'étapes) ; réponses inchangées.
- Quelques composés oxygénés : 6 défauts (crochets `[[…]]` du matching affichés en texte brut, faux « 3-méthyl », énoncé sans les quatre formules) ; réponses inchangées.

## Ce qui a dérapé

- `valider.rb` et le contrôle de `practice` laissent passer un champ `tolerance` qui contient une phrase : trouvé par un relecteur ; le contrôle de session le vérifie désormais. À reporter dans `valider.rb` (dette).
- Le hook de fin de session réclamait un commit à chaque tour : les lots ont été commités par groupes de leçons relues (R1 : 6 ; R2 : 3 + 1 + 4 déclinées).

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `valider.rb` ne contrôle ni `practice` ni le type de `tolerance` | La vague ne livre pas de code | Programme `contenus-v3-tous-niveaux` |
| Aucune sorte ne dessine un ressort, un circuit, un barrage ou des lignes de champ ; la parabole de l'énergie élastique est tracée en segments | Approximations dites dans les descriptions | Demande de sorte, si un enseignant la juge utile |
| Challenger empirique (import en brouillon, captures) non fait | Aucun écran modifié ; sortes déjà éprouvées | Avant publication |
