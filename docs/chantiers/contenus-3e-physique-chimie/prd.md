# PRD — Les 10 premières leçons de Physique-Chimie de 3ème, tracé optique, molécule et planches de PC

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Vague 4 du programme [`contenus-3e-autres-matieres`](../contenus-3e-autres-matieres/prd.md) : ses critères transverses s'appliquent, pour les sortes `optics`, `molecule` et les planches `dynamometer`, `electrolyser`, `eudiometer`.

## 1. Contexte

La vague ajoute les sortes de figures `optics` et `molecule` et trois planches de la sorte `plate` (créée par la vague 3), exactement selon ADR-XXXX-figures-des-matieres-de-3eme §4.2 et UDR-XXXX-figures-des-matieres-de-3eme §3, puis rédige les 10 premières leçons de Physique-Chimie de 3ème en fichiers v3 prêts à importer.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer les fichiers en brouillon, relire, publier | Importer une figure `optics`, `molecule` ou `plate` incohérente |
| Student | Réviser une leçon publiée, faire varier lentille et chaîne carbonée, faire ses exercices | Voir une leçon en brouillon |
| Teacher | Donner les exercices de la leçon | Modifier la leçon |
| Parent, SchoolStaff | Rien de nouveau | — |

Aucune règle d'autorisation nouvelle (ADR-0116).

## 3. Parcours utilisateur

### Chemin nominal

1. L'équipe importe une leçon de PC en brouillon ; ses figures sont acceptées.
2. Elle ouvre la fiche de révision : la lentille se dessine avec ses trois rayons, OA' et γ affichés ; l'alcane se dessine et se nomme.
3. Un curseur sur la distance de l'objet ou le nombre de carbones redessine la figure et annonce la nouvelle mesure.
4. L'équipe publie ; l'élève révise.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| `optics` en mode `lens` sans `focal` (ou sans `lens`, `object_distance`, `object_height`) ; mode `eye` sans `defect` ; `correction` hors mode œil | `figure_invalid` à l'import et au script, même chemin |
| `molecule` `alkane` sans `carbons` ou `display` ; `custom` sans `atoms`/`bonds`, identifiant dupliqué, liaison vers un atome absent, valence dépassée (C 4, H 1, O 2, N 3, Cl 1) | `figure_invalid` des deux côtés |
| `plate` PC citant une partie absente de sa planche | `figure_invalid` des deux côtés |
| Objet au foyer d'une lentille convergente | Rayons émergents parallèles, « image à l'infini » affiché et annoncé |
| Identifiant de planche inconnu du module | État `error`, description visible |
| Calcul faux dans une leçon | Corrigé avant livraison (relecture IA qui refait chaque calcul) |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Tracé optique

  Scénario: une lentille convergente forme une image réelle calculée
    Étant donné une figure optics lens convergent de focale 4 cm, objet à 12 cm, haut de 2 cm
    Quand la fiche s'affiche
    Alors la figure est ready, avec 3 rayons particuliers et les foyers F et F'
    Et elle affiche OA' = 6 cm et γ = −0,5, image réelle, renversée, réduite

  Scénario: le curseur de la distance redessine et annonce
    Étant donné la même figure avec un curseur sur object_distance
    Quand l'élève amène l'objet à 2 cm
    Alors l'image devient virtuelle, droite, agrandie (OA' = −4 cm, γ = 2), dessinée en tirets
    Et la nouvelle mesure est annoncée au relâchement

  Scénario: un objet au foyer donne une image à l'infini
    Quand l'objet est à 4 cm d'une lentille convergente de focale 4 cm
    Alors la figure reste ready et affiche « image à l'infini »

  Scénario: une lentille divergente donne toujours une image virtuelle
    Étant donné une lentille divergente de focale 4 cm et un objet à 12 cm
    Alors la figure affiche OA' = −3 cm et γ = 0,25, image virtuelle, droite, réduite

  Scénario: le mode œil montre le défaut et sa correction
    Étant donné un œil myope sans correction
    Alors les rayons convergent avant la rétine
    Et avec une lentille divergente devant l'œil, ils convergent sur la rétine
    Et un œil hypermétrope converge après la rétine, corrigé par une lentille convergente

Fonctionnalité: Molécules

  Scénario: un alcane se dessine et se nomme
    Étant donné une figure molecule alkane de 3 carbones en formule développée
    Alors elle dessine 3 C, 8 H et 10 liaisons, et affiche « propane » et C₃H₈

  Scénario: le curseur carbons change la chaîne
    Quand l'élève amène carbons à 1 puis à 10
    Alors la figure affiche « méthane » (CH₄, aucune liaison C–C) puis « décane » (C₁₀H₂₂) et annonce le nom

  Scénario: les formules semi-développée et brute
    Alors display semi_developed écrit CH₃–CH₂–CH₃ et display raw écrit C₃H₈

  Scénario: une molécule custom respecte la valence
    Étant donné une molécule custom d'eau (O lié à deux H)
    Alors elle est acceptée et dessinée
    Et un carbone à 5 liaisons ou un hydrogène à 2 liaisons est refusé figure_invalid à l'import et au script

Fonctionnalité: Planches de Physique-Chimie

  Scénario: les trois planches se dessinent et se légendent
    Étant donné une figure plate de chacune des planches dynamometer, electrolyser, eudiometer
    Alors elle est ready, chaque étiquette relie sa partie, et numbering numbers n'affiche que des numéros

  Scénario: les listes de parties sont identiques des deux côtés
    Alors les parties de chaque planche de PC sont les mêmes dans le domaine et dans le module de dessin

  Scénario: une partie inconnue est refusée
    Étant donné une planche electrolyser qui cite la partie « piston »
    Alors l'import et le script rendent figure_invalid sur le même chemin

Fonctionnalité: Les 10 leçons de Physique-Chimie

  Scénario: les leçons suivent la progression nationale
    Alors les 10 premières leçons de 3ème de la progression 2026-2027 ont chacune un fichier version 3 au même intitulé exact
    Et aucun fichier version 1 ne reste dans lecons-traitees/3eme/physique-chimie

  Scénario: chaque leçon livrée passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 10 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: les calculs sont justes
    Étant donné chaque valeur numérique d'une leçon (poids, force, travail, puissance, énergie, OA', γ, masses de réactifs)
    Quand une relecture indépendante la recalcule
    Alors elle trouve la même valeur et la même unité SI
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `FigureKinds` : `optics`, `molecule` (paramètres et réglables de l'ADR §4.2) ; cohérence `optics` et `molecule` dans `Figure` ; parties des 3 planches de PC dans la liste fermée des planches |
| Infrastructure, Delivery | aucun changement |
| UI | `lib/figures/optics.js`, `lib/figures/molecule.js`, 3 modules de planche sous `lib/figures/plates/` ; liste blanche du contrôleur |
| Contenus | sections `optics` et `molecule` (et planches de PC) de la consigne de rédaction ; 10 fichiers v3 |

## 6. Décisions rattachées

- ADR-XXXX-figures-des-matieres-de-3eme (accepté) : formes et cohérence de `optics`, `molecule`, `plate`. La vague l'applique sans l'amender ; les parties des 3 planches de PC, que l'ADR laisse à la vague, sont fixées dans `plan.md`.
- UDR-XXXX-figures-des-matieres-de-3eme (acceptée) : dessin des sortes. Aucune vue nouvelle.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Leçons v3 de PC en 3ème | 0 | 10 | |
| Sortes de figures livrées par la vague | 0 | 2 + 3 planches | |
