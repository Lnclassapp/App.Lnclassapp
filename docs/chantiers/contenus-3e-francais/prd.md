# PRD — Les 10 premières leçons de Français de 3ème

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Vague 1 du programme [`contenus-3e-autres-matieres`](../contenus-3e-autres-matieres/prd.md) : ses critères transverses s'appliquent.

## 1. Contexte

Le contrôle des fichiers de leçon refuse des questions que l'import accepte (rédigée, appariement, ordre…). La vague l'aligne sur l'import, généralise la consigne de rédaction aux 5 matières, puis rédige les 10 premières leçons de Français de 3ème en fichiers v3 prêts à importer.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer les fichiers en brouillon, relire, publier | Importer un fichier que l'import refuse (règles inchangées) |
| Student | Réviser une leçon publiée, faire ses exercices, rédiger ses réponses | Voir une leçon en brouillon |
| Teacher | Donner les exercices, corriger les questions rédigées | Modifier la leçon |

Aucune règle d'autorisation nouvelle (ADR-0116, ADR-0115).

## 3. Parcours utilisateur

### Chemin nominal

1. Le rédacteur produit une leçon avec la consigne, pour une matière donnée.
2. Il lance le contrôle : aucune erreur, aucun avertissement.
3. Une relecture IA indépendante relit le fond ; les corrections sont faites, le contrôle relancé.
4. Le porteur reçoit le fichier ; l'équipe l'importe en brouillon et publie.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Question d'un type connu de l'import mais mal construite (rédigée sans corrigé, appariement sans paire…) | Le contrôle rend `question_structure` au même chemin que l'import |
| Type de question inconnu | `invalid_value` sur `question_type`, comme l'import |
| Barème, unité, début de phrase ou critères mal typés | `schema`, comme l'import |
| Moins de 50 % des questions d'une leçon corrigées automatiquement | Avertissement du contrôle, avec le pourcentage |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Le contrôle reprend les règles de l'import pour les questions

  Scénario: chaque type de question bien formé est accepté des deux côtés
    Étant donné une leçon dont les questions couvrent les types written, matching, ordering, fill_blank, numeric et select, bien formés
    Quand elle est contrôlée par l'import et par le script
    Alors aucune erreur n'est rendue

  Scénario: une question mal construite est refusée de la même façon des deux côtés
    Étant donné une question rédigée sans corrigé, ou avec des propositions
    Ou un barème hors bornes, des critères sur une question à choix, une unité hors d'une question numeric
    Ou un type de question inconnu, ou un appariement sans paire
    Quand la leçon est contrôlée par l'import et par le script
    Alors les deux rendent le même ensemble de [chemin, raison]

  Scénario: la part de questions corrigées automatiquement est contrôlée
    Étant donné une leçon dont moins de la moitié des questions sont corrigées automatiquement
    Quand le script la contrôle
    Alors il avertit en donnant la part trouvée
    Et une leçon à 50 % ou plus ne reçoit pas cet avertissement

Fonctionnalité: Les 10 leçons de Français

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 de Français en 3ème
    Alors ses 10 premières leçons ont chacune un fichier version 3 au même intitulé exact dans lecons-traitees/3eme/francais
    Et aucun fichier version 1 n'y reste

  Scénario: chaque leçon livrée passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 10 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: une leçon s'importe et se révise
    Étant donné un des fichiers importé en brouillon
    Quand l'équipe ouvre sa fiche de révision à 390 px et sur ordinateur
    Alors les 4 blocs de chaque notion s'affichent
    Et une question rédigée peut être faite
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | aucun changement : réutilisation de `Entities::Assessment::Question.structure_errors_for` et de `AUTO_GRADED` des types |
| Infrastructure | aucun changement |
| Delivery, UI | aucun changement |
| Script | `script/contenus/valider.rb` : règles de question de l'import, avertissement des 50 % |
| Contenus | `prompt-redaction.md` et `prompt-redaction-lot.md` par matière ; 10 fichiers v3 de Français |

## 6. Décisions rattachées

- Aucun ADR : pas de port, de table ni de contrat nouveaux ; le script reprend une règle existante du domaine (ADR-0115, ADR-0116).
- Aucune UDR : aucune vue créée ni modifiée.
