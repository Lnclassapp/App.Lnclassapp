# PRD — Les 10 premières leçons de SVT de 3ème et leurs planches

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Vague 3 du programme [`contenus-3e-autres-matieres`](../contenus-3e-autres-matieres/prd.md) : ses critères transverses s'appliquent.

## 1. Contexte

La SVT de 3ème s'apprend sur des schémas légendés que l'application ne dessine pas. La vague ajoute la sorte `plate` (planche légendée) et ses 8 planches de SVT, puis rédige les 10 premières leçons de la progression nationale 2026-2027 en fichiers v3 prêts à importer.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer les fichiers en brouillon, relire, publier | Importer une planche inconnue ou dont une partie est inconnue |
| Student | Réviser une leçon publiée, lire une planche légendée, légender une planche numérotée | Voir une leçon en brouillon |
| Teacher | Donner les exercices, corriger les questions rédigées | Modifier la leçon |

Aucune règle d'autorisation nouvelle (ADR-0116).

## 3. Parcours utilisateur

### Chemin nominal

1. Une leçon cite une planche par son identifiant, ses étiquettes par partie, en noms ou en numéros.
2. Le contrôle et l'import l'acceptent ; la fiche de révision dessine la planche, chaque étiquette reliée à sa partie par un trait de rappel.
3. En numéros, l'élève voit 1, 2, 3… sans légende et répond à la question qui lui demande de légender.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Planche inconnue | `figure_invalid` à l'import et au script ; côté navigateur, état `error`, description visible |
| Partie d'étiquette ou de surlignage absente de la planche | `figure_invalid` sur le chemin du paramètre, des deux côtés |
| Même partie étiquetée deux fois | `figure_invalid` |
| Plus de 12 étiquettes, plus de 4 surlignages, `numbering` hors `names`/`numbers` | `figure_invalid` (bornes) |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: La planche légendée

  Scénario: une planche bien formée est acceptée des deux côtés
    Étant donné une figure plate de chacune des 8 planches de SVT, avec des étiquettes et des surlignages de ses parties
    Quand le fichier est contrôlé par l'import et par le script
    Alors aucune erreur n'est rendue

  Scénario: une planche incohérente est refusée de la même façon des deux côtés
    Étant donné une planche inconnue, ou une partie inconnue de la planche, ou une partie étiquetée deux fois
    Quand le fichier est contrôlé par l'import et par le script
    Alors les deux rendent figure_invalid sur le même chemin

  Scénario: les planches et leurs parties sont les mêmes dans le domaine et dans le navigateur
    Quand on compare la liste des planches du domaine et les modules de dessin
    Alors les planches et leurs parties sont identiques

  Scénario: une planche se dessine en noms
    Étant donné une planche du cœur avec 4 étiquettes en noms et une partie surlignée
    Quand la fiche s'affiche
    Alors la figure est dans l'état ready
    Et chaque étiquette porte son texte et un trait de rappel vers sa partie
    Et la partie surlignée est remplie

  Scénario: une planche se dessine en numéros, sans légende
    Étant donné la même planche en numéros
    Quand la fiche s'affiche
    Alors les étiquettes sont 1, 2, 3, 4 et aucun nom de partie n'est écrit

  Scénario: une planche inconnue du navigateur ne dessine rien
    Étant donné une figure plate dont la planche est inconnue du module
    Quand la fiche s'affiche
    Alors la figure est dans l'état error et sa description reste visible

  Scénario: les modules de planches restent sûrs
    Quand on inspecte lib/figures/plate.js et lib/figures/plates
    Alors aucun module n'écrit de balisage, ne charge de ressource ni ne porte de couleur en dur

Fonctionnalité: Les 10 leçons de SVT

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 de SVT en 3ème
    Alors ses 10 premières leçons ont chacune un fichier version 3 au même intitulé exact dans lecons-traitees/3eme/svt
    Et aucun fichier version 1 n'y reste

  Scénario: chaque leçon livrée passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 10 fichiers
    Alors il sort sans erreur ni avertissement
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `FigureKinds` : sorte `plate` (`plate`, `labels` ≤ 12, `highlight` ≤ 4, `numbering`) ; `FigureCatalogs::PLATES` (planche → parties) ; cohérence `plate` dans `Figure` |
| Infrastructure, Delivery | aucun changement (l'import valide par le domaine) |
| UI | `lib/figures/plate.js` (commun : contrôle, étiquettes, traits de rappel, surlignage) ; `lib/figures/plates/<planche>.js` (dessin et parties d'une planche) et `plates/index.js` (la liste) ; `figure_controller.js` (liste blanche) |
| Contenus | section `plate` de `prompt-redaction.md` ; 10 fichiers v3 de SVT |

**Parties des planches** (identifiants ; libellés français dans le module de dessin) :

| Planche | Parties |
|---|---|
| `digestive_system` | `mouth`, `salivary_glands`, `oesophagus`, `stomach`, `liver`, `gallbladder`, `pancreas`, `small_intestine`, `large_intestine`, `rectum`, `anus` |
| `blood_smear` | `red_blood_cell`, `neutrophil`, `lymphocyte`, `monocyte`, `platelet`, `plasma` |
| `heart` | `right_atrium`, `left_atrium`, `right_ventricle`, `left_ventricle`, `septum`, `aorta`, `pulmonary_artery`, `superior_vena_cava`, `inferior_vena_cava`, `pulmonary_veins`, `tricuspid_valve`, `mitral_valve` |
| `double_circulation` | `right_heart`, `left_heart`, `lungs`, `organs`, `pulmonary_artery`, `pulmonary_veins`, `aorta`, `vena_cava` |
| `female_reproductive_system` | `ovary`, `oviduct`, `infundibulum`, `uterus`, `endometrium`, `cervix`, `vagina` |
| `hiv_virus` | `envelope`, `gp120`, `gp41`, `matrix`, `capsid`, `rna`, `reverse_transcriptase` |
| `soil_profile` | `litter`, `humus_horizon`, `accumulation_horizon`, `weathered_rock`, `bedrock`, `roots` |
| `root_hairs` | `collar`, `main_root`, `lateral_root`, `root_hair_zone`, `elongation_zone`, `root_cap`, `root_hair`, `soil_particle`, `soil_water` |

## 6. Décisions rattachées

- ADR-0117 (§4.2 `plate`, listes fermées) — accepté ; aucun ADR nouveau : la vague fixe les parties que l'ADR délègue à chaque planche.
- UDR-0142 (§3 `plate`) — acceptée ; aucune vue créée ni modifiée.
