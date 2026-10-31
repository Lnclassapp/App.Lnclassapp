# PRD — Les leçons arrivent seules sur Develop et Staging

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Les feuilles « Prépare interros » et « Prépare devoirs » que Touré retravaille (aujourd'hui Thalès : 4 sujets de devoir, deux exercices par notion) vivent dans un fichier de leçon du dépôt et n'arrivent dans Develop et Staging que par un import à la main, que l'application refuse dès que la leçon y est publiée. À chaque démarrage sur Develop ou Staging, l'application charge seule les leçons du dépôt qui portent des sujets de devoir, en remplaçant l'ancienne version, effacement des résultats de test compris. La production n'est jamais touchée.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | voir dans l'écran Imports la ligne de chaque chargement automatique (terminé, refusé, avertissement) | déclencher le chargement depuis l'écran : il suit le déploiement |
| Teacher, Student | voir la nouvelle version des feuilles une fois chargée et publiée | garder leurs résultats et devoirs envoyés sur l'ancienne version d'une leçon remplacée |
| Parent, SchoolStaff | rien de neuf | — |

Aucune policy nouvelle : le chargement n'est pas une action d'utilisateur. La ligne d'import a pour auteur le plus ancien membre actif de l'équipe ; la lecture de l'écran Imports garde sa policy actuelle.

## 3. Parcours utilisateur

### Chemin nominal

1. Une PR qui modifie la leçon Thalès est fusionnée dans `Develop` ; Railway redéploie Develop.
2. Au démarrage, après les migrations, l'application lit le nom de l'environnement : `Develop`.
3. Elle prend les leçons de `docs/contenus/lecons-traitees` qui portent au moins un sujet de devoir (aujourd'hui : Thalès).
4. Pour chacune, elle compare l'empreinte du fichier à celle de son dernier chargement automatique réussi : différente (ou jamais chargée) → elle charge.
5. Charger : la leçon passe par la vraie chaîne d'import (mêmes contrôles qu'à la main) ; si elle existe déjà, publiée ou non, son contenu est remplacé, résultats et devoirs envoyés effacés ; puis tout est publié.
6. L'écran Imports montre une ligne « Cours complets », fichier `chargement-automatique-…json`, statut terminé.
7. Même chose sur Staging au déploiement suivant de `Staging`.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Environnement `production` (toute casse), environnement de PR, poste local, CI | rien, aucune ligne |
| Nom d'environnement inconnu | rien n'est chargé ; une ligne refusée dans Imports, erreur « environnement non reconnu : <nom> » ; l'application démarre |
| Fichier inchangé depuis le dernier chargement réussi | rien n'est chargé, aucune ligne |
| Niveau ou matière absent (Staging sans référentiel) | la leçon est refusée dans sa ligne (erreur de l'import ordinaire) ; retentée au déploiement suivant |
| Fichier invalide | refusé dans sa ligne, avec les erreurs de l'import ordinaire ; l'application démarre |
| Aucun membre d'équipe actif | rien n'est chargé, avertissement dans le journal du déploiement |
| Un import est déjà en cours, ou un autre démarrage charge déjà | rien n'est chargé cette fois ; journal du déploiement |
| Toute exception | journalisée ; l'application démarre quand même |

## 4. Critères d'acceptation

```gherkin
Scénario: une leçon publiée est remplacée sur Develop
  Étant donné l'environnement "Develop" et la leçon Thalès publiée avec un ancien contenu et une séance d'élève
  Quand le chargement automatique tourne
  Alors la leçon Thalès a les 4 sujets et 2 exercices par notion du fichier, tous publiés
  Et l'ancienne séance de l'élève n'existe plus
  Et une ligne d'import « Cours complets » terminée existe, au nom du plus ancien membre de l'équipe

Scénario: seules les leçons à sujets de devoir sont chargées
  Étant donné l'environnement "Staging" et une leçon du dépôt sans sujet de devoir
  Quand le chargement automatique tourne
  Alors cette leçon n'est ni créée ni modifiée

Scénario: un fichier inchangé n'est pas rechargé
  Étant donné un chargement automatique réussi de Thalès
  Quand le chargement automatique tourne de nouveau sans changement du fichier
  Alors aucune nouvelle ligne d'import n'est créée

Scénario: la production n'est jamais touchée
  Étant donné l'environnement "production"
  Quand le chargement automatique tourne
  Alors aucune leçon et aucune ligne d'import ne changent

Scénario: un nom inconnu prévient sans charger
  Étant donné l'environnement "Recette"
  Quand le chargement automatique tourne
  Alors aucune leçon ne change
  Et une ligne d'import refusée porte l'erreur « environnement non reconnu : Recette »

Scénario: un référentiel absent refuse la leçon sans bloquer
  Étant donné l'environnement "Staging" sans le niveau 3ème
  Quand le chargement automatique tourne
  Alors la leçon Thalès n'est pas créée
  Et la ligne d'import porte l'erreur du niveau inconnu
  Et le chargement se termine sans exception

Scénario: l'import à la main refuse toujours une leçon publiée
  Étant donné la leçon Thalès publiée
  Quand l'équipe l'importe depuis l'écran Imports
  Alors l'import est refusé avec « lesson_already_published »
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | règle de reconnaissance de l'environnement (Develop, Staging, production, PR, inconnu) ; use case de chargement automatique (sélection des leçons à sujets, comparaison d'empreintes, chaîne d'import puis publication) ; l'adaptateur d'import accepte, pour ce seul appelant, de remplacer une leçon publiée |
| Infrastructure | l'écrivain de l'arbre remplace une leçon publiée sur demande explicite (même effacement que pour un brouillon) ; dernière empreinte réussie lue dans les rapports d'import ; source des fichiers de leçon du dépôt ; tâche Rake `contenus:charger` sous verrou consultatif PostgreSQL |
| Delivery | `bin/docker-entrypoint` lance la tâche après `db:prepare`, sans bloquer le démarrage |
| UI | aucune vue modifiée ; un code d'erreur traduit (`unknown_environment`) |

## 6. Décisions rattachées

- ADR-XXXX-chargement-automatique-des-lecons-hors-production — repérage par le nom, remplacement d'une leçon publiée hors production, empreinte lue dans les rapports d'import.
- Pas d'UDR : aucune vue créée ni modifiée (la ligne d'import existante suffit ; seul un libellé d'erreur s'ajoute).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Durée ajoutée au démarrage, fichier inchangé | 0 | < 2 s | |
