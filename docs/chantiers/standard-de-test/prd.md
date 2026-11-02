# PRD — Un standard de test pour Lnclass

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Lnclass teste chaque endroit sur des données différentes, sans activité, et ne vérifie l'affichage des leçons qu'à la main ([memo](memo.md)). Le chantier pose un **jeu de test standard** décrit dans le dépôt : établissements variés dont un grand, comptes fictifs par rôle, une leçon par matière et niveau-série, un trimestre d'activité déterministe ; recréé en une commande en local, en PR et (sur décision) sur Develop. Il ajoute le **rendu automatique des leçons** en CI, l'**aperçu local** d'un fichier, la **recette par rôle**, la **preuve d'une vague** et une **règle de fusion**.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Équipe en local | Charger / remettre à zéro le jeu ; prévisualiser un fichier ; lancer la preuve d'une vague ; mesurer les pages lentes | Lancer l'aperçu hors développement |
| Équipe sur Develop | Charger le jeu (décision n° 1) | Remettre Develop à zéro sans confirmation explicite et accord du porteur |
| CI (PR, train) | Importer et rendre les leçons dans la base de test ; vérifier la section de preuve des PR | Publier dans un environnement |
| Déploiement Staging | Ajouter les leçons v3 absentes (décision n° 2 bis) | Remplacer une leçon présente (hors exercices des leçons à sujets, ADR-0122) |
| Production | — inchangé | Recevoir le jeu standard ou un chargement automatique |
| Comptes fictifs : élève, enseignant, direction, équipe (admin, contenu, terrain) | Se connecter au PIN de test, passer par les politiques existantes | Exister en production |

## 3. Parcours utilisateur

### Chemin nominal — recréer le jeu

1. `bin/jeu-standard --reset` en local : base vidée, jeu chargé (établissements, comptes, leçons, trimestre d'activité) en quelques minutes.
2. Il affiche les comptes par rôle et l'empreinte des totaux.
3. `bin/tester-pr <PR> --demo` et l'environnement de PR chargent le même jeu ; l'empreinte est la même.

### Chemin nominal — corriger une leçon

1. Modifier `…/tle-d/mathematiques/<leçon>.json`.
2. `bin/apercu-lecon <fichier> [--suivre]` : `valider.rb`, import seul de ce fichier, publication, adresse affichée avec un compte élève de la série.
3. PR : la CI rend ce fichier à 390 px et sur ordinateur.
4. Fusion : Develop recharge ce seul fichier (empreinte SHA-256 changée, ADR-0122).

### Chemin nominal — recette d'un chantier

1. Le chantier touche l'écran « progression de la classe » : la table écran → parcours désigne le parcours enseignant.
2. Le testeur le rejoue sur le jeu standard, à 390 px et sur ordinateur.
3. La PR remplit « Prouvé sur le jeu standard » : parcours rejoué, leçons rendues, ligne `bin/ci-quiet`.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| JSON refusé par `valider.rb` ou l'import | Aperçu arrêté, erreurs affichées, base intacte ; test d'affichage rouge avec le code de refus |
| Aperçu lancé hors développement | Refus, rien importé |
| Remise à zéro demandée sur un environnement distant sans confirmation | Refus, rien supprimé |
| Fichier du manifeste absent ou non v3 | Test du manifeste rouge ; chargement non commencé |
| Contact fictif hors de la plage réservée | Test rouge |
| Page débordante à 390 px, `**` affichés, figure absente | Test d'affichage rouge : fichier, largeur, défaut |
| PR qui change du code sans section de preuve | Garde de la CI rouge |
| Calcul de statistique modifié | Empreinte des totaux différente : test rouge, à mettre à jour sciemment |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Jeu standard

  Scénario: le manifeste décrit le jeu
    Étant donné le manifeste du jeu standard
    Alors il nomme un lycée public, un collège seul privé et un grand établissement mixte d'environ 1 500 élèves
    Et une classe par niveau-série, dont les séries A et C
    Et une classe vide et un élève sans activité
    Et des comptes élève, enseignant, direction et équipe, dont un enseignant dans deux établissements
    Et pour chaque couple niveau-série et matière ayant du v3, exactement un fichier v3 existant
    Et la leçon v3 la plus longue du dépôt

  Scénario: une commande, à l'identique
    Étant donné une base locale quelconque
    Quand on lance bin/jeu-standard --reset deux fois
    Alors les deux chargements donnent la même empreinte des totaux
    Et la commande dure moins de 5 minutes

  Scénario: rejouer sans remise à zéro ne double rien
    Quand on lance bin/jeu-standard sur un jeu déjà chargé
    Alors rien n'est créé en double

  Scénario: même jeu en local et en PR
    Quand l'environnement de PR sème ses données ou que l'on lance bin/tester-pr --demo
    Alors c'est le jeu standard qui est chargé

  Scénario: aucune vraie donnée personnelle
    Alors chaque contact du jeu est dans la plage fictive réservée
    Et chaque nom vient de la liste fictive du dépôt

  Scénario: remise à zéro distante protégée
    Quand on lance bin/jeu-standard --reset avec RAILWAY_ENVIRONMENT_NAME=develop sans confirmation
    Alors rien n'est supprimé

Fonctionnalité: Activité d'un trimestre

  Scénario: les tableaux de bord ont des chiffres
    Étant donné le jeu standard chargé
    Alors le tableau de bord enseignant d'une classe active montre des séances, des notes, des lacunes, des devoirs rendus et en retard
    Et le tableau de bord de la direction montre l'activité de son établissement
    Et le tableau de bord équipe filtré par une DRENA montre ses établissements
    Et la classe vide et l'élève sans activité affichent leur état vide

  Scénario: déterministe
    Étant donné deux chargements à des dates différentes
    Alors l'empreinte des totaux est identique
    Et le trimestre se termine la veille du chargement

Fonctionnalité: Grand établissement

  Scénario: repérer les pages lentes
    Étant donné le grand établissement chargé
    Quand on lance la mesure des pages par rôle
    Alors chaque page est listée avec son temps de réponse
    Et celles au-dessus du seuil sont signalées

Fonctionnalité: Leçons vérifiées par la machine

  Scénario: chaque défaut fait échouer le rendu
    Étant donné un fichier v3 qui déborde à 390 px, ou affiche « ** », ou dont une figure est vide, ou que l'import refuse
    Quand le test d'affichage le rend à 390 px et sur ordinateur
    Alors il échoue en nommant le fichier, la largeur et le défaut

  Scénario: une PR ne rend que ce qu'elle touche
    Étant donné une PR qui modifie 3 fichiers de leçons
    Quand bin/ci-quiet joue le niveau pr
    Alors ces 3 fichiers, et eux seuls, sont rendus

  Scénario: le train rend tout dans le budget
    Quand la CI du train tourne
    Alors tous les fichiers v3 sont rendus, dans des tâches de 5 minutes au plus
    Et rien n'est publié hors de la base de test

Fonctionnalité: Aperçu local

  Scénario: modifier puis voir
    Quand on lance l'aperçu sur un fichier v3 modifié
    Alors seule sa leçon est réimportée et publiée, et son adresse est affichée

  Scénario: refus hors développement
    Quand on lance l'aperçu avec RAILS_ENV=production
    Alors il refuse et n'importe rien

Fonctionnalité: Un rôle par environnement

  Scénario: Develop charge le jeu sans supprimer (décision n° 1, option a)
    Quand Develop se déploie
    Alors le jeu standard est chargé et aucune autre leçon n'est supprimée

  Scénario: Staging ajoute sans écraser (décision n° 2 bis)
    Étant donné une leçon déjà présente sur Staging
    Quand Staging se déploie
    Alors les leçons v3 absentes sont ajoutées et la présente n'est pas modifiée

  Scénario: la production ne charge rien
    Quand la production se déploie
    Alors ni le jeu standard ni aucune leçon ne sont chargés

Fonctionnalité: Recette, preuve de vague et règle de fusion

  Scénario: un parcours par rôle
    Alors le dépôt décrit un parcours élève, enseignant, direction, DRENA (équipe filtrée) et équipe sur les comptes du jeu
    Et une table relie chaque écran aux parcours qui le traversent

  Scénario: preuve d'une vague
    Quand on lance la preuve sur le dossier d'une vague
    Alors valider.rb et le test d'affichage passent sur ses fichiers
    Et une capture 390 px et une sur ordinateur sont produites par matière, hors du dépôt

  Scénario: une PR dit ce qu'elle a prouvé
    Étant donné une PR vers Develop qui change du code
    Quand sa section « Prouvé sur le jeu standard » est absente ou vide
    Alors la garde de la CI échoue
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Catalog::StandardTestSet` (manifeste, contrôle) ; `School::FictitiousIdentity` (noms, plage de contacts) ; `AutomaticLoadStage` étendu (Develop : jeu standard ; Staging : ajout des absentes) |
| Infrastructure | `db/seeds/standard/jeu.yml`, `db/seeds/standard/noms.yml` ; `db/seeds/standard.rb` (base), `db/seeds/standard/activite.rb` (trimestre, horloge à la Saint-Michel, graine fixe), `db/seeds/standard/grand.rb` ; mode `:create_only` de `ContentTreeWriter` ; aucun nouveau port |
| Delivery | `bin/jeu-standard [--reset] [--grand]`, `bin/apercu-lecon`, `bin/preuve-vague`, `bin/pages-lentes` ; `bin/tester-pr --demo` → jeu standard |
| Tests / CI | `test/system/catalog/lesson_rendering_test.rb` ; garde de la section de preuve ; tâche `lecons` au train |
| Docs | `docs/recette/` (un parcours par rôle + table écran → parcours) ; modèle de PR |
| UI | aucune vue modifiée — pas d'UDR |

## 6. Décisions rattachées

- ADR-XXXX-standard-de-test — jeu standard, activité déterministe, rôle des environnements, rendu des leçons, règle de fusion. Amende ADR-0122 (Staging) et ADR-0123 (Develop) sous réserve des décisions ouvertes.
- UDR : aucune, aucune vue créée ni modifiée.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Fichiers v3 rendus par la machine | 0 / 417 | 417 / 417 au train | |
| `bin/jeu-standard --reset` | — (`--demo` ~1 min, sans activité) | < 5 min, avec un trimestre d'activité | |
| Classes avec activité | 1 (Saint-Michel, local) | toutes sauf la classe vide | |
| Modifier un JSON → le voir en local | import manuel | < 15 s, une commande | |
| Tâche CI la plus longue | ≤ 5 min | ≤ 5 min | |
