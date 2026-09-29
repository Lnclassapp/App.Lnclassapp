# PRD — Import des DRENA par fichier

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Remettre en service un environnement demande aujourd'hui de saisir les 41 DRENA une par une, et chaque faute de frappe casse l'import des 3 851 établissements, qui les retrouve par slug ([memo](memo.md)). L'équipe pourra désormais importer les DRENA depuis un fichier JSON, comme les établissements, par un bouton placé à côté de « Nouvelle DRENA ». En même temps, le slug de toute DRENA prend le préfixe `drena-` (`drena-abidjan-1`), et l'import des établissements ne reconnaît plus que ce slug exact.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer un fichier de DRENA, suivre son rapport, créer une DRENA au formulaire | Mettre à jour, renommer ou supprimer une DRENA par import |
| SchoolStaff | — | Voir l'écran des DRENA ou lancer un import |
| Teacher, Student, Parent | — | Voir l'écran des DRENA ou lancer un import |

Règle d'autorisation : `Policies::School::ManageSchoolPolicy` (équipe seulement). C'est la même que pour la gestion des DRENA et l'import des établissements, et le moteur d'import l'applique par le registre des types.

## 3. Parcours utilisateur

### Chemin nominal

1. Sur l'écran des DRENA, l'équipe voit « Nouvelle DRENA » et, juste à côté, « Importer des DRENA ».
2. « Importer des DRENA » ouvre la modale d'import avec le type DRENA déjà choisi. L'aide de la modale montre le format `lnclass.drenas`, la clé `name`, un exemple, et la règle du slug `drena-`.
3. L'équipe téléverse `db/seeds/data/imports/drenas-2026.json`, qui contient 41 lignes.
4. La modale passe au suivi du rapport, rafraîchi toutes les 3 s : 41 importées, 0 ignorée, 0 en erreur.
5. En rouvrant l'écran des DRENA, l'équipe voit les 41 DRENA, chacune avec son slug `drena-…`.
6. L'équipe importe ensuite le fichier des établissements réécrit. Chaque école trouve sa DRENA par son slug `drena-…`.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Une ligne a le slug d'une DRENA existante, ou d'une ligne plus haut dans le fichier | Elle est ignorée et comptée « ignorée ». La DRENA existante n'est pas modifiée |
| Une ligne porte un nom déjà pris en base sous un autre slug | Erreur de la ligne `drenas[i].name`, code `taken`. Les autres lignes sont importées |
| Une ligne a un nom vide, fait d'espaces, de plus de 80 caractères, ou sans lettre latine | Erreur de la ligne à `drenas[i].name` (`blank`, `too_long`, `invalid_value`) |
| Une ligne porte une clé inconnue (`code`, `region`…) | Erreur de schéma de la ligne |
| Format autre que `lnclass.drenas`, version autre que 1, ou JSON illisible | Rejet en bloc, rien n'est écrit |
| Plus de 500 lignes | Rejet en bloc `too_many_roots` |
| Un import de DRENA est déjà en cours | Le second attend son tour, comme pour les autres types (un seul actif par type) |
| Un fichier d'établissements cite `abidjan-1` (sans le préfixe) | L'école est en erreur `unknown_drena` à `schools[i].drena` |
| Le formulaire reçoit un nom sans lettre latine (« ??? ») | Erreur sous le champ, et la modale est re-rendue en 422 |
| Un membre qui n'est pas de l'équipe demande la modale d'import des DRENA | Refus, comme pour les autres types d'import |

## 4. Critères d'acceptation

Chacun devient un test. Les identifiants `DR-NN` sont cités par les tests et par `plan.md`.

```gherkin
# DR-01 — slug préfixé, formulaire et import
Étant donné un membre de l'équipe
Quand il crée la DRENA « Bouaké 1 » au formulaire
Alors son slug est « drena-bouake-1 »
Et une DRENA importée sous le nom « San-Pédro » a le slug « drena-san-pedro »

# DR-02 — import nominal
Étant donné qu'aucune DRENA n'existe
Quand l'équipe importe le fichier livré drenas-2026.json
Alors le rapport est « Terminé » avec 41 importées, 0 ignorée, 0 en erreur
Et les 41 slugs sont exactement ceux du fichier des établissements réécrit

# DR-03 — doublons par slug
Étant donné la DRENA « Bouake 1 » (slug « drena-bouake-1 »)
Quand l'équipe importe « Bouaké 1 », « Grand-Bassam » et « Grand Bassam »
Alors « Bouaké 1 » et « Grand Bassam » sont ignorées (2 ignorées)
Et « Grand-Bassam » est importée
Et le nom de « Bouake 1 » n'a pas changé

# DR-04 — nom pris sous un autre slug
Étant donné la DRENA « Abidjan 1 » renommée « Abidjan Plateau » (slug figé « drena-abidjan-1 »)
Quand l'équipe importe « Abidjan Plateau » et « Man »
Alors « Abidjan Plateau » est en erreur « taken » à drenas[0].name
Et « Man » est importée

# DR-05 — lignes invalides
Quand l'équipe importe un nom vide, un nom de 81 caractères, « ??? » et une ligne { "name": "Man", "code": "M1" }
Alors chaque ligne est en erreur à son chemin drenas[i] (blank, too_long, invalid_value, schéma)
Et aucune DRENA n'est créée

# DR-06 — rejets en bloc
Quand l'équipe importe un fichier au format « lnclass.schools », ou de version 2, ou de 501 lignes
Alors le rapport est « Rejeté » et aucune DRENA n'est créée

# DR-07 — autorisation
Étant donné un membre de la direction d'un établissement (SchoolStaff)
Quand il demande la modale d'import de type « drenas » ou poste un fichier de ce type
Alors la requête est refusée, et aucun rapport n'est créé

# DR-08 — formulaire : nom sans lettre latine
Quand l'équipe crée au formulaire la DRENA « ??? »
Alors la modale est re-rendue en 422 avec l'erreur sous le champ
Et aucune DRENA n'est créée

# DR-09 — l'import des établissements ne reconnaît que le slug exact
Étant donné la DRENA « Abidjan 1 » (slug « drena-abidjan-1 »)
Quand l'équipe importe une école avec "drena": "drena-abidjan-1", puis une autre avec "drena": "abidjan-1"
Alors la première est importée dans « Abidjan 1 »
Et la seconde est en erreur « unknown_drena » à schools[1].drena

# DR-10 — le bouton d'import sur l'écran des DRENA
Étant donné un membre de l'équipe sur l'écran des DRENA
Alors il voit « Nouvelle DRENA » et « Importer des DRENA » côte à côte dans l'en-tête
Et « Importer des DRENA » ouvre la modale d'import de type DRENA, avec l'aide du format
Et le téléversement d'un fichier valide affiche le suivi du rapport sans rechargement de page

# DR-11 — les fichiers livrés sont conformes
Alors drenas-2026.json est valide pour le schéma lnclass.drenas v1
Et chacune des 3 851 écoles du fichier des établissements réécrit cite un slug présent dans drenas-2026.json
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | La règle du slug préfixé portée par l'entité DRENA, unique source pour le formulaire et l'import. Un nom sans lettre latine est refusé par le formulaire. Un cinquième type `drenas` au registre des imports (format `lnclass.drenas`, racines `drenas`, sans cible, 500 au plus, policy `ManageSchoolPolicy`). Un adaptateur d'import `School::ImportDrenas`. Le port des DRENA gagne l'écriture en masse et la liste des noms pris |
| Infrastructure | Une migration qui élargit la contrainte des types de rapport à `drenas`. Le slug figé des DRENA dérive de la règle du domaine. Le repository implémente l'écriture en masse. Un schéma `config/schemas/lnclass.drenas.v1.json`. Le job `School::ImportDrenasJob`, inscrit dans `config.x.import_jobs`. Les seeds adoptent la nouvelle règle d'elles-mêmes |
| Delivery | Aucune route nouvelle : le contrôleur des imports accepte le nouveau type par le registre |
| UI | L'en-tête de l'écran des DRENA gagne le bouton d'import. Une nouvelle aide `teams/imports/kinds/_drenas`. Le libellé du type dans les locales. L'exemple de l'aide des établissements passe à `drena-abidjan-1` |
| Données livrées | `db/seeds/data/imports/drenas-2026.json` (41 DRENA) et le fichier des établissements 2026 réécrit avec les slugs `drena-…` |

## 6. Décisions rattachées

- ADR-0066 — Les DRENA s'importent, et leur slug est préfixé `drena-`. Il amende l'ADR-0034 et l'ADR-0039 (§9 « les DRENA ne s'importent pas », et l'amendement « quatre types d'import »).
- UDR-0053 — Import des DRENA : bouton à côté de « Nouvelle DRENA », et aide du format dans la modale d'import. Elle complète l'UDR-0035 et l'UDR-0037.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Saisies manuelles pour mettre un environnement en service | 41 formulaires | 1 import | |
| Écoles du fichier 2026 rattachées à leur DRENA | dépend de la saisie | 3 851 / 3 851 | |
