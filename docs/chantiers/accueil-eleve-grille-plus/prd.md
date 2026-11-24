# PRD — Accueil élève : « Inviter » et « Plus » dans la grille

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'accueil de l'élève, au téléphone, a une grille de matières puis une section à part « Invite tes camarades ». Comme chez Wave, la grille devient l'unique porte : les matières (6 au plus selon le niveau), puis « Inviter », puis « Plus », qui ouvre une feuille basse avec les entrées secondaires (S'abonner, Salle d'étude, Littera, Composa, Devoirs CI). Sur ordinateur, pas de « Plus » : ces entrées sont dans le menu de gauche.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Ouvrir « Plus », toucher une entrée ; aller à « Abonnement » ; inviter ses camarades s'il a une classe | Voir « Inviter » sans classe |
| Teacher, SchoolStaff, Team, Parent | — (accueil inchangé) | Voir la grille de l'élève |

Aucune règle d'autorisation nouvelle : l'accueil reste réservé à l'élève (contrôleur existant), « Abonnement » garde sa règle (`allow_roles :student`), « Inviter » garde sa porte serveur.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre son accueil au téléphone : la grille « Mes matières » montre ses matières, puis « Inviter », puis « Plus », 4 par rangée.
2. Il touche « Plus » : une feuille monte du bas, titre « Plus », grille de 4 colonnes des entrées.
3. Il touche « S'abonner » : la page Abonnement s'ouvre.
4. Il touche « Salle d'étude » : la feuille reste ouverte, le message « Bientôt disponible » s'affiche et est lu.
5. Sur ordinateur, la grille montre ses matières et « Inviter » ; les mêmes entrées sont dans le menu de gauche, sous ses trois destinations.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Élève sans classe | Matières de son dernier niveau puis « Plus » ; pas d'« Inviter » |
| Aucune matière | « Inviter » (s'il a une classe) et « Plus » restent ; la phrase « aucune matière » reste sous la grille |
| Moins de 6 matières | « Inviter » et « Plus » suivent la dernière matière, sans case vide |
| Entrée sans écran | Message « Bientôt disponible » annoncé, aucun lien |
| Échap, toucher hors de la feuille, croix | La feuille se ferme, le focus revient sur « Plus » |
| JavaScript indisponible | La feuille ne s'ouvre pas (comme toute fenêtre de l'application) ; la grille des matières et « Inviter » restent utilisables |

## 4. Critères d'acceptation

```gherkin
Scénario: CA-1 la grille se termine par « Inviter » puis « Plus », la section « Invite tes camarades » disparaît
Étant donné un élève de la Tle D avec ses matières
Quand il ouvre son accueil
Alors la grille « Mes matières » se termine par la case « Inviter » puis la case « Plus »
Et la page n'a plus de section « Invite tes camarades »

Scénario: CA-2 sans classe, « Plus » sans « Inviter »
Étant donné un élève sans classe active
Quand il ouvre son accueil
Alors la grille montre les matières de son dernier niveau puis « Plus »
Et aucune case « Inviter »

Scénario: CA-3 « Plus » ouvre une feuille basse de 4 colonnes
Étant donné un élève sur son accueil à 390 px
Quand il touche « Plus »
Alors une fenêtre nommée « Plus » s'ouvre en bas de l'écran
Et elle montre S'abonner, Salle d'étude, Littera, Composa, Devoirs CI, 4 par rangée
Et sa hauteur est au moins 25 % de l'écran

Scénario: CA-4 « S'abonner » mène à la page Abonnement
Quand l'élève touche « S'abonner » dans « Plus »
Alors la page Abonnement s'ouvre

Scénario: CA-5 une entrée sans écran dit « Bientôt disponible »
Quand l'élève touche « Salle d'étude » dans « Plus »
Alors le message « Bientôt disponible » s'affiche dans une zone annoncée aux lecteurs d'écran
Et l'adresse de la page ne change pas

Scénario: CA-6 la feuille se ferme et rend le focus
Étant donné la feuille « Plus » ouverte
Quand l'élève appuie sur Échap
Alors la feuille se ferme et le focus revient sur « Plus »

Scénario: CA-7 ordinateur : pas de « Plus », les entrées dans le menu de gauche
Étant donné un élève sur son accueil à 1440 px
Alors la grille n'a pas de case « Plus »
Et le menu de gauche liste S'abonner, Salle d'étude, Littera, Composa, Devoirs CI sous Accueil, Cours et Ma classe
Et « Salle d'étude » y dit « Bientôt disponible » au lieu de mener à une page

Scénario: CA-8 une seule liste d'entrées
Alors la feuille « Plus » et le menu de gauche montrent les mêmes entrées, dans le même ordre
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Rien : aucune règle métier |
| Infrastructure | Rien |
| Delivery | Rien : aucune route ni contrôleur ; la liste des entrées est une constante du helper de navigation (clé, destination ou rien, pictogramme, teinte) |
| UI | Grille « Mes matières » (cases « Inviter » et « Plus »), feuille « Plus » (`ui_modal` en `:phone_sheet`, déjà là), entrée sans écran en `popover` natif, menu de gauche (2e carte de la barre latérale, comme l'équipe), suppression de la section « Invite tes camarades », clés I18n |

## 6. Décisions rattachées

- Pas d'ADR : ni port, ni table, ni dépendance, ni contrat ne change (vues et helper seulement).
- UDR-XXXX-accueil-eleve-grille-plus (`docs/decisions/udr/XXXX-accueil-eleve-grille-plus.md`) — amende UDR-0173 §3 (accueil, « Mes matières ») et UDR-0179 accueil-eleve-qr-fenetre-inviter §3.3 (la tuile « Inviter » entre dans la grille).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Hauteur de l'accueil à 390 px (Tle D, jeu réduit) | ≈ 980 px | − 140 px (section « Invite tes camarades » retirée) | |
