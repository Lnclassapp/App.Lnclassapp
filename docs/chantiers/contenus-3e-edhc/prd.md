# PRD — Les 10 premières leçons d'EDHC de 3ème

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Vague 5 du programme [`contenus-3e-autres-matieres`](../contenus-3e-autres-matieres/prd.md) : ses critères transverses s'appliquent.

## 1. Contexte

La vague rédige les 10 premières leçons d'EDHC de 3ème de la progression 2026-2027 en fichiers v3 prêts à importer, avec les figures de l'inventaire (ADR-0117 §4.1) : `diagram`, `stat_chart`, `map` `cote_d_ivoire`. Aucun code.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer les fichiers en brouillon, relire, publier | Importer un fichier que l'import refuse (règles inchangées) |
| Student | Réviser une leçon publiée, faire ses exercices, rédiger ses réponses | Voir une leçon en brouillon |
| Teacher | Donner les exercices, corriger les questions rédigées | Modifier la leçon |

Aucune règle d'autorisation nouvelle.

## 3. Parcours utilisateur

### Chemin nominal

1. Un rédacteur par leçon produit le fichier avec la consigne (`prompt-redaction.md`, matière EDHC).
2. Une fois la vague 2 fusionnée, le contrôle passe sans erreur ni avertissement.
3. Une relecture IA indépendante relit le fond (faits, institutions, neutralité) ; les corrections sont faites, le contrôle relancé.
4. Le porteur reçoit les fichiers ; l'équipe les importe en brouillon et publie.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Sorte `diagram`, `map` ou courbe pas encore livrée | Le contrôle rend `figure_invalid` ; la livraison attend la vague 2 |
| Identifiant de lieu inconnu du fond | `figure_invalid` ; l'identifiant est corrigé d'après le fond livré |
| Moins de 50 % de questions corrigées automatiquement | Avertissement ; le fichier n'est pas livré |
| Fait, date ou institution incertain | Non écrit ; signalé à l'enseignant dans le bilan |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Les 10 leçons d'EDHC

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 d'EDHC en 3ème
    Alors ses 10 premières leçons ont chacune un fichier version 3 au même intitulé exact dans lecons-traitees/3eme/edhc
    Et aucun fichier version 1 n'y reste

  Scénario: chaque leçon livrée passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 10 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: les figures sont celles de l'inventaire
    Étant donné les figures des 10 fichiers
    Alors chacune est de sorte diagram, stat_chart ou map de fond cote_d_ivoire

  Scénario: une leçon s'importe et se révise
    Étant donné un des fichiers importé en brouillon
    Quand l'équipe ouvre sa fiche de révision à 390 px et sur ordinateur
    Alors les 4 blocs de chaque notion et ses figures s'affichent
    Et une question rédigée peut être faite
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine, infrastructure, delivery, UI, script | aucun changement |
| Contenus | 10 fichiers v3 d'EDHC dans `docs/contenus/lecons-traitees/3eme/edhc/` ; ligne au tableau « Leçons traitées » du README des contenus |

## 6. Décisions rattachées

- ADR-0117 et UDR-0142 (programme), appliqués sans amendement.
- Aucun ADR ni UDR nouveau : pas de port, de table, de contrat ni de vue.
