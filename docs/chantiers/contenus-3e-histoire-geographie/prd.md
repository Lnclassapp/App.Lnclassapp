# PRD — Leçons de 3ème en Histoire-Géographie, et leurs figures (frise, carte, schéma, courbe)

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Reprend le PRD cadre du programme ([`../contenus-3e-autres-matieres/prd.md`](../contenus-3e-autres-matieres/prd.md)) pour les sortes et la matière de cette vague.

## 1. Contexte

Les 10 premières leçons d'Histoire-Géographie de 3ème sont vides. La vague ajoute les sortes `timeline`, `map` (fonds `cote_d_ivoire`, `africa`, `world`), `diagram` et la courbe `stat_chart` `line`, puis rédige les 10 leçons au format v3 et les livre en fichiers prêts à importer.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer les 10 fichiers en brouillon, relire, publier | Importer une figure mal formée ou qui cite un identifiant hors liste |
| Student | Lire la fiche et faire les exercices d'une leçon publiée, figures comprises | Voir une leçon en brouillon |
| Teacher | Donner les exercices à sa classe | Modifier la leçon |
| Parent, SchoolStaff | Rien de nouveau | — |

Aucune règle d'autorisation nouvelle (ADR-0116).

## 3. Parcours utilisateur

### Chemin nominal

1. Le code de la vague est en production ; le porteur a reçu les 10 fichiers.
2. L'équipe importe un fichier ; la leçon est créée en brouillon.
3. La fiche de révision s'ouvre : frises, cartes, schémas et courbes se dessinent (`ready`) ; le curseur d'une frise la zoome.
4. L'équipe publie ; l'élève révise.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Carte avec un lieu, une aire ou une route hors du fond | `figure_invalid` sur le chemin du paramètre, à l'import et au script |
| Aire sans catégorie, catégorie au-delà de la légende, légende absente | `figure_invalid` |
| Frise : `end ≤ start`, plus de 200 graduations, événement ou période hors bornes, `from ≥ to` | `figure_invalid` |
| Schéma : identifiant répété, arête vers un nœud absent, arbre à deux racines ou à cycle, cycle de moins de 3 nœuds | `figure_invalid` |
| Fond de carte introuvable ou identifiant inconnu côté navigateur | État `error`, description visible |
| Sorte `plate`, `optics` ou `molecule` | Refusée (sorte inconnue) : vagues 3 et 4 |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Sortes de figures d'Histoire-Géographie

  Scénario: CA-1 chaque sorte nouvelle bien formée est acceptée
    Étant donné une figure timeline, une map de chaque fond, un diagram de chaque layout et un stat_chart line, bien formés
    Quand ils sont contrôlés par le domaine
    Alors aucune erreur n'est rendue

  Scénario: CA-2 une incohérence est refusée de la même façon par l'import et par le script
    Étant donné une frise dont un événement est avant le début
    Ou une carte dont un lieu n'existe pas dans son fond
    Ou un schéma en arbre à deux racines
    Quand le fichier est contrôlé par l'import et par le script
    Alors les deux rendent figure_invalid sur le même chemin

  Scénario: CA-3 les identifiants des fonds sont les mêmes dans le domaine et dans les modules de rendu
    Quand on compare les aires et les lieux de chaque fond, côté domaine et côté lib/figures/maps
    Alors ils sont identiques

  Scénario: CA-4 chaque sorte se dessine
    Étant donné une figure de chaque sorte de la vague
    Quand la page s'affiche
    Alors la figure est dans l'état ready et sa description n'est plus visible que des lecteurs d'écran

  Scénario: CA-5 le curseur d'une frise la zoome
    Étant donné une frise avec un curseur sur start
    Quand l'élève déplace le curseur
    Alors les graduations et les événements dessinés changent

  Scénario: CA-6 un identifiant inconnu côté navigateur ne dessine rien
    Étant donné une carte dont le fond ou un lieu est inconnu du module (injecté dans la page)
    Quand la page s'affiche
    Alors la figure est dans l'état error et sa description reste visible

  Scénario: CA-7 les modules restent sûrs et légers
    Quand on inspecte lib/figures et lib/figures/maps
    Alors aucun module n'écrit de balisage, ne charge de ressource ni ne porte de couleur en dur
    Et chaque fond pèse 150 Ko au plus

  Scénario: CA-8 catégories lisibles sans la couleur
    Étant donné une carte à trois catégories
    Alors les catégories 1 à 3 ont chacune leur teinte en aplat, les catégories 4 à 6 leur motif, et la légende les reprend

Fonctionnalité: Les 10 leçons d'Histoire-Géographie

  Scénario: CA-9 chaque leçon passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chaque fichier de docs/contenus/lecons-traitees/3eme/histoire-geographie/
    Alors il sort sans erreur ni avertissement

  Scénario: CA-10 les leçons suivent la progression
    Alors les 10 premières leçons de 3ème de la progression HG 2026-2027 ont chacune un fichier version 3 au même intitulé exact

  Scénario: CA-11 la moitié des questions au moins est corrigée automatiquement
    Alors chaque leçon a au moins 50 % de questions à choix
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `FigureKinds` (+ `timeline`, `map`, `diagram`, `stat_chart` `line`) ; `FigureCatalogs` (identifiants des 3 fonds) ; cohérence par sorte dans `Figure` |
| Infrastructure | aucune ; l'import valide par le domaine |
| Delivery | aucune route, aucun contrôleur |
| UI | `figure_controller.js` (liste blanche, création asynchrone) ; `lib/figures/{timeline,map,diagram}.js`, `lib/figures/maps/{cote_d_ivoire,africa,world}.js`, `stat_chart.js` (courbe) |
| Contenus | `script/contenus/fonds_de_carte.rb` ; 10 fichiers v3 |

## 6. Décisions rattachées

- ADR-XXXX-figures-des-matieres-de-3eme (§4.1 à §4.3, menace) — accepté.
- UDR-XXXX-figures-des-matieres-de-3eme — accepté. Aucune vue nouvelle.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Leçons v3 d'HG en 3ème | 0 | 10 | |
| Sortes de figures | 5 | 8 (+ courbe) | |
| Poids max d'un fond de carte | — | ≤ 150 Ko | |
