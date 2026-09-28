# PRD — Cycles en boutons radio

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier.

## 1. Contexte

Le cycle d'un niveau et celui d'un établissement passent d'une liste déroulante à un groupe de boutons radio ([memo](memo.md)). Le domaine ne change pas : mêmes valeurs soumises, mêmes validations.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | choisir le cycle d'un niveau (création, modification) et d'un établissement (modification) | — (inchangé) |

## 3. Critères d'acceptation

```gherkin
# CR-01
Étant donné la modale « Nouveau niveau »
Alors le cycle est un groupe « Cycle » de deux boutons radio, « Premier cycle » et « Second cycle »
Et « Premier cycle » est coché

# CR-02
Étant donné le niveau « Tle » du second cycle
Quand l'équipe ouvre sa modale de modification
Alors « Second cycle » est coché

# CR-03
Étant donné la modale « Nouveau niveau », au clavier
Quand l'équipe va sur le groupe « Cycle » et appuie sur la flèche droite
Alors « Second cycle » est coché
Et le niveau enregistré est du second cycle

# CR-04
Étant donné un établissement du premier cycle
Quand l'équipe ouvre sa modale de modification
Alors le cycle est un groupe de deux boutons radio, « Premier cycle » coché
Et choisir « Premier et second cycles » puis enregistrer met à jour la ligne

# CR-05
Étant donné une saisie envoyée sans cycle
Alors la modale revient en 422 avec le message sous le groupe, relié à chaque bouton

# CR-06
Étant donné un écran de 390 px de large
Alors chaque option fait au moins 48 px de haut et la page ne défile pas en largeur

# CR-07
Étant donné la liste des établissements
Alors le filtre « Tous les cycles » reste une liste déroulante
```

## 4. Hors périmètre

Voir le [memo](memo.md#hors-périmètre).

## 5. Décisions

- [UDR-0005](../../decisions/udr/0005-design-system-fondateur.md#amendement-du-2026-09-28--groupe-de-boutons-radio) : composant `ui_radio_group`.
- [UDR-0032](../../decisions/udr/0032-gestion-des-niveaux.md) et [UDR-0036](../../decisions/udr/0036-gestion-des-etablissements.md) : amendements du 2026-09-28.
- Pas d'ADR : aucune architecture ne bouge.
