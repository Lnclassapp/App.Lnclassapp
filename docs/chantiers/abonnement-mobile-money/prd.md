# PRD — Abonnement payé par Mobile Money (Wave)

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Résumé du [memo](memo.md) une fois le cadrage terminé. Trois phrases maximum.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Teacher | | |
| Student | | |

Préciser la règle d'autorisation applicable (ex. `ClassroomAccessPolicy`).

## 3. Parcours utilisateur

### Chemin nominal

1. …
2. …

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| | |

## 4. Critères d'acceptation

Formulés de manière vérifiable. Chacun devient un test.

```gherkin
Étant donné qu'un enseignant est affecté à la classe 3ème A
Quand il publie un message
Alors les élèves de la 3ème A voient le message dans leur fil
Et les élèves des autres classes ne le voient pas
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | entités, ports, use cases |
| Infrastructure | migrations, modèles `Orm::`, repositories, queries |
| Delivery | routes, contrôleurs |
| UI | vues, partials, contrôleurs Stimulus |

## 6. Décisions rattachées

- ADR-NNNN — …
- UDR-NNNN — …

## 7. Mesures

*Obligatoire pour un chantier d'optimisation, recommandé ailleurs.*

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| | | | |
