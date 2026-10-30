# ADR-XXXX : Six sortes de figures et une courbe s'ajoutent à la liste fermée, pour les leçons de 3ème hors mathématiques
<!-- index
titre: Figures des matières de 3ème (frise, carte, schéma, tracé optique, planche, molécule)
statut: Accepté
problematique: Les leçons de SVT, Physique-Chimie, Histoire-Géographie et EDHC ont besoin de figures que les cinq sortes des mathématiques ne dessinent pas.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/contenus-3e-autres-matieres` |
| **Remplace** | — ; amende ADR-0116 §4.2 (liste des sortes, formes des éléments) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

ADR-0116 a fermé la liste des figures sur cinq sortes, toutes mathématiques (géométrie, repère, droite graduée, graphique, solide), et prévu qu'« une sorte nouvelle = un amendement de cet ADR ». Les 10 premières leçons de 3ème de la progression nationale en SVT, Physique-Chimie, Histoire-Géographie, Français et EDHC demandent des frises, des cartes, des schémas d'organes, des marches de rayons et des formules de molécules. Le porteur a tranché (memo, grill) : on constitue la base de figures dont ces leçons ont besoin, et les fonds de carte suivent la progression nationale (Côte d'Ivoire, Afrique, monde).

L'inventaire, leçon par leçon, est au §4.1. Le Français n'a besoin d'aucune sorte nouvelle : il part le premier, importable avec le code en production.

## 2. Moteurs de décision

- **Rédaction par l'IA, sans coordonnée inventée.** Une IA place mal un point sur une carte ou un organe sur un schéma. Les figures nommées (carte, planche) prennent des **identifiants d'une liste fermée** ; seules les figures abstraites (frise, schéma fléché, molécule) prennent des valeurs, et leur mise en page est calculée.
- **Rien n'est dessiné par une leçon.** Comme en ADR-0116 : un module de rendu par sorte, aucune image importée, aucun code propre à une leçon.
- **Contrôle avant import.** Tout identifiant inconnu, toute incohérence est refusée par l'import et par `valider.rb` avec la raison `figure_invalid` (parité inchangée).
- **Poids.** Rien dans le JS commun (ADR-0114) ; un fond de carte n'est chargé que par une page qui a une carte.
- **Lisible au téléphone et sans la couleur.** Une zone de carte ou une partie d'organe se lit aussi par un motif ou un numéro, pas seulement par la teinte.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| **A. Sortes nouvelles à identifiants fermés (retenue)** | Correct par construction, contrôlable, lisible ; même chemin de rendu que les maths | Dessin des planches et données des fonds à produire et maintenir |
| B. Images importées (PNG/SVG) par leçon | Aucune sorte à coder | Retirées par ADR-0116 (menace d'un fichier importé, pas d'interaction, 50 images à produire et relire) |
| C. Tout dessiner avec `geometry` et `coordinate_plane` | Aucun code | Une carte ou un cœur en segments est faux et illisible ; aucune légende |
| D. Une sorte « SVG libre » écrite par l'IA | Souple | Contenu actif dans une figure, impossible à valider ; rejeté par la menace d'ADR-0116 |

## 4. Décision

Option A. La liste fermée d'ADR-0116 §4.2 passe de 5 à **11 sortes** avec `timeline`, `map`, `diagram`, `optics`, `plate`, `molecule`, et `stat_chart` gagne `chart: "line"`. Les règles communes d'ADR-0116 (12 figures par leçon au plus, `description` de 150 à 600 caractères, 0 à 4 curseurs sur une clé numérique de premier niveau déclarée réglable, textes ≤ 60 caractères) s'appliquent sans changement.

### 4.1 Inventaire des 50 leçons (ce qui justifie chaque sorte)

| Matière | Leçon (rang) | Figures prévues |
|---|---|---|
| SVT | 1 Aliments et l'Homme | `diagram` (classes d'aliments), `stat_chart` pie (ration) |
| | 2 Digestion | `plate` appareil digestif, `diagram` (transformation des aliments) |
| | 3 Le sang | `plate` frottis sanguin, `stat_chart` pie (composition) |
| | 4 Transfusion | `diagram` (donneurs et receveurs ABO, Rhésus) |
| | 5 Circulation | `plate` cœur, `plate` circulation double |
| | 6 Grossesses précoces | `plate` appareil reproducteur féminin, `timeline` en jours (cycle) |
| | 7 VIH | `plate` virus, `stat_chart` line (évolution), `diagram` (transmission) |
| | 8 Caractéristiques d'un sol | `plate` profil de sol, `stat_chart` bars (granulométrie) |
| | 9 Relations sols-plantes | `plate` racine et poils absorbants, `diagram` |
| | 10 Dégradation des sols | `diagram` (causes → conséquences) |
| PC | 1 Masse et poids | `coordinate_plane` (P = m·g), `plate` dynamomètre |
| | 2 Les forces | `coordinate_plane` vecteurs |
| | 3 Équilibre à deux forces | `coordinate_plane` vecteurs |
| | 4 Travail et puissance | `coordinate_plane`, `stat_chart` bars |
| | 5 Énergie mécanique | `stat_chart` bars (Ec, Ep), `coordinate_plane` |
| | 6 Électrolyse et synthèse de l'eau | `plate` électrolyseur, `plate` eudiomètre, `molecule` |
| | 7 Les alcanes | `molecule` (formules développées, chaîne réglable) |
| | 8 Les lentilles | `optics` lentille |
| | 9 Défauts de l'œil | `optics` œil (myopie, hypermétropie, correction) |
| | 10 Oxydation des corps purs simples | `molecule`, `diagram` |
| HG | 1 Impérialisme et colonisation en CI | `map` Afrique et CI, `timeline` |
| | 2 Atouts du développement de la CI | `map` CI (zones naturelles, ports, villes), `stat_chart` |
| | 3 Accession de la CI à l'indépendance | `timeline` |
| | 4 Secteurs d'activités de la CI | `map` CI (zones de cultures, industries), `stat_chart` pie |
| | 5 Crises sociopolitiques de l'Afrique indépendante | `map` Afrique, `timeline` |
| | 6 Crise rwandaise (1990-1994) | `map` Afrique, `timeline` |
| | 7 Problèmes du développement de la CI | `stat_chart` line, `diagram` |
| | 8 Deuxième guerre mondiale | `map` monde, `timeline` |
| | 9 Étude économique de l'Afrique | `map` Afrique, `stat_chart` |
| | 10 L'ONU | `diagram` arbre (organes), `timeline`, `map` monde |
| EDHC | 1 à 10 | `diagram` (organigrammes, étapes du scrutin, circuit de l'impôt), `stat_chart`, `map` CI (aires culturelles, leçon 10) |
| Français | 1 à 10 | aucune sorte nouvelle ; pas de figure, ou `diagram` seulement si la sorte est en production quand la leçon part |

La liste des planches (§4.2, `plate`) et des fonds (§4.2, `map`) est exactement celle de cet inventaire. Une planche ou un fond nouveau est un amendement de cet ADR.

### 4.2 Sortes, paramètres et formes des éléments

| `kind` | Paramètres | Forme d'un élément | Réglables |
|---|---|---|---|
| `timeline` | `start`, `end` (nombres −3000..2100), `step` (1..500), `unit` (`year`, `month`, `day`), `periods` (≤ 8), `events` (≤ 16) | `periods` : `{"from","to","label"}` · `events` : `{"at","label"}` | `start`, `end` |
| `map` | `base` (`cote_d_ivoire`, `africa`, `world`), `areas` (≤ 40), `places` (≤ 20), `routes` (≤ 10), `legend` (≤ 6 textes) | `areas` : `{"id","category"}` · `places` : `{"id","label"?}` · `routes` : `{"from","to","label"?}` | aucun |
| `diagram` | `layout` (`flow`, `tree`, `cycle`), `direction` (`down`, `right`), `nodes` (≤ 12), `edges` (≤ 16), `legend` (≤ 4 textes) | `nodes` : `{"id","label","category"?}` · `edges` : `{"from","to","label"?}` | aucun |
| `optics` | `mode` (`lens`, `eye`), `lens` (`convergent`, `divergent`), `focal` (0.5..20, cm), `object_distance` (0.5..60, cm), `object_height` (0.5..10, cm), `defect` (`none`, `myopia`, `hyperopia`), `correction` (`none`, `convergent`, `divergent`) | dimensions seules | `focal`, `object_distance`, `object_height` |
| `plate` | `plate` (liste fermée ci-dessous), `labels` (≤ 12), `highlight` (≤ 4 identifiants), `numbering` (`names`, `numbers`) | `labels` : `{"part","text"?}` | aucun |
| `molecule` | `mode` (`alkane`, `custom`), `carbons` (1..10), `display` (`developed`, `semi_developed`, `raw`), `atoms` (≤ 20), `bonds` (≤ 24) | `atoms` : `{"id","element","x","y"}` (x, y entiers 0..12, `element` parmi C, H, O, N, Cl, Fe, Na) · `bonds` : `["a","b",ordre]` (ordre 1..3) | `carbons` |
| `stat_chart` | inchangé, `chart` gagne `line` | inchangé | aucun |

**Cohérence contrôlée (`figure_invalid`)**, en plus des bornes :

- `timeline` : `end > start` ; `(end − start) / step ≤ 200` ; chaque `at`, `from`, `to` dans `[start, end]` et `from < to`.
- `map` : chaque `id` d'`areas` et de `places`, chaque `from`/`to` de `routes`, appartient au fond `base` ; `category` entier de 1 à la taille de `legend` ; `legend` obligatoire dès qu'une aire est donnée.
- `diagram` : identifiants uniques ; chaque arête relie deux nœuds existants ; `tree` a une seule racine et aucun cycle ; `cycle` a au moins 3 nœuds ; `category` de 1 à la taille de `legend`.
- `optics` : `mode: "lens"` exige `lens`, `focal`, `object_distance`, `object_height` ; `mode: "eye"` exige `defect` ; `correction` n'est permise qu'en mode œil.
- `plate` : chaque `part` et chaque `highlight` appartient à la planche ; parties uniques.
- `molecule` : `mode: "alkane"` exige `carbons` et `display` ; `mode: "custom"` exige `atoms` et `bonds`, identifiants uniques, liaisons entre atomes existants, et chaque atome a une valence respectée (C 4, H 1, O 2, N 3, Cl 1 ; Fe et Na non contrôlés).

**Listes fermées** (identifiants en `snake_case`, libellés français dans le module de rendu) :

- **Planches** (`plate`) : `digestive_system`, `blood_smear`, `heart`, `double_circulation`, `female_reproductive_system`, `hiv_virus`, `soil_profile`, `root_hairs`, `dynamometer`, `electrolyser`, `eudiometer`. Chacune déclare ses parties (ex. `digestive_system` : `mouth`, `oesophagus`, `stomach`, `liver`, `gallbladder`, `pancreas`, `small_intestine`, `large_intestine`, `rectum`, `anus`, `salivary_glands`).
- **Fonds** (`map`) : `cote_d_ivoire` — les 14 districts, les zones naturelles (`dense_forest`, `savanna`, `coastal_strip`, `mountain_west`), les grandes villes et les ports ; `africa` — les 54 États (code ISO 3166 alpha-3 en minuscules) et leurs capitales ; `world` — les États (alpha-3), les continents, et les lieux de la deuxième guerre mondiale et de l'ONU cités par l'inventaire.

Le domaine porte les **identifiants** (Ruby pur) ; le module de rendu porte le **dessin** (tracés, positions). Un test vérifie que les deux listes sont identiques.

### 4.3 Données des fonds de carte

- Source : **Natural Earth** (domaine public) — 1:10m pour la Côte d'Ivoire, 1:50m pour l'Afrique, 1:110m pour le monde. Si Natural Earth n'a pas les 14 districts ivoiriens, **geoBoundaries** ADM1 (CC BY 4.0), avec l'attribution écrite dans la légende de la carte.
- Projection et simplification faites **une fois, hors de l'application**, par un script de `script/contenus/` versionné ; le résultat est un module JS de données (`app/javascript/lib/figures/maps/<fond>.js`) : des chemins SVG déjà projetés, aucun calcul géographique dans le navigateur.
- Budget : **150 Ko au plus par fond** avant compression ; chargé par `import()` seulement quand une carte de ce fond est affichée.

### Menace écrite d'abord (fichier importé)

Le fichier importé reste un JSON écrit par une IA ou une personne de l'équipe (ADR-0116). Ce qui change : des textes plus nombreux dans les figures (libellés de nœuds, d'événements, de parties). Parades, inchangées et étendues :

- Tout texte est écrit par `textContent`, jamais par `innerHTML` (test de structure existant, étendu aux nouveaux modules et à `lib/figures/maps/`).
- Les identifiants (`plate`, `part`, `id` de carte) sont comparés à une liste fermée côté serveur **et** côté navigateur : un identifiant inconnu ne crée aucun nœud.
- Les données de fond sont du code versionné, jamais lues dans le fichier importé ; aucun module ne charge une ressource réseau (test existant).
- Les nombres sont bornés ; `diagram` et `timeline` calculent leur mise en page avec un nombre d'éléments borné (pas de boucle non bornée).

## 5. Conséquences

### 🟢 Positives

- Les 40 leçons de SVT, PC, HG et EDHC ont les figures que demande la progression nationale, interactives quand c'est utile (lentille, chaîne carbonée, zoom d'une frise).
- Les planches et les cartes servent ensuite aux niveaux suivants sans code nouveau, tant que la planche ou le fond existe.
- Une figure nommée est juste par construction : l'IA choisit « le foie », pas un point.

### 🔴 Coûts consentis

- **Onze planches à dessiner** à la main en SVG, et à faire relire par un enseignant de SVT ou de PC : c'est le poste le plus long et le plus subjectif du chantier.
- **Trois fonds de carte** à préparer et à garder : une frontière qui change se corrige dans le script et le module, pas dans les leçons.
- Six modules de rendu de plus à maintenir et à tester au téléphone.
- Les leçons de SVT, PC, HG et EDHC ne s'importent qu'après la mise en production de ce code ; le Français part avant.
- La liste fermée grossit : chaque planche ou fond nouveau repasse par un amendement.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/catalog/figure_kinds.rb — Ruby pur : les 11 sortes, leurs paramètres et leurs clés réglables
# app/domain/entities/catalog/figure_catalogs.rb — Ruby pur : PLATES (planche → parties), MAP_BASES (fond → aires, lieux)
# app/domain/entities/catalog/figure.rb — <kind>_errors pour les 6 sortes nouvelles
# app/javascript/controllers/figure_controller.js — KINDS et RANGE_PARAMS étendus
# app/javascript/lib/figures/<kind>.js — un module par sorte ; lib/figures/maps/<fond>.js — les fonds
# script/contenus/fonds_de_carte.rb — fabrique les modules de fond à partir des sources (§4.3)
```

## 7. Comment vérifier que la décision est respectée

- `FiguresStructureTest` : les modules de `lib/figures/` sont exactement les 11 sortes plus `svg` ; aucun `innerHTML`, aucune ressource réseau, aucune couleur en dur, y compris sous `lib/figures/maps/`.
- Test de parité des listes fermées : les planches et leurs parties, les fonds et leurs identifiants, sont les mêmes dans le domaine et dans les modules de rendu.
- Test de parité import ↔ `valider.rb` : chaque incohérence du §4.2 rend `figure_invalid` des deux côtés.
- Test système par sorte : la figure se dessine (`data-figure-state="ready"`), un curseur la redessine, un identifiant inconnu laisse la description.
- Taille de chaque `lib/figures/maps/<fond>.js` ≤ 150 Ko (test).
