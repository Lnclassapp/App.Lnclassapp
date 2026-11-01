# ADR-0122 : Les leçons à sujets de devoir se chargent seules sur Develop et Staging
<!-- index
titre: Chargement automatique des leçons hors production
statut: Proposé
problematique: Faire arriver sur Develop et Staging, sans import à la main, les leçons retravaillées pour Prépare interros et Prépare devoirs, même déjà publiées.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-31 |
| **Chantier** | `docs/chantiers/contenus-develop-staging` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Les leçons sont rédigées dans le dépôt (`docs/contenus/lecons-traitees`, format `lnclass.course-tree` v3) et n'entrent dans une base que par l'écran Imports (ADR-0113, ADR-0116) ou, dans un environnement de PR, par les semis (ADR-0108). Develop et Staging, déployés en production Rails sur Railway, n'ont ni l'un ni l'autre : un membre de l'équipe doit télécharger le fichier et le téléverser, environnement par environnement. Et l'import refuse une leçon publiée (ADR-0116 §4.4) : la version corrigée ne peut pas y remplacer l'ancienne. Le pilote retravaille les feuilles « Prépare interros » et « Prépare devoirs » (Thalès, #423) et veut les voir sur Develop et Staging sans manipulation ; la production reste à la main.

## 2. Moteurs de décision

- La production ne doit jamais être touchée, même par une erreur de configuration.
- Aucun réglage à poser (choix du pilote) ; un nom non reconnu prévient au lieu de se taire.
- Les mêmes contrôles qu'un import à la main : pas de seconde chaîne d'écriture.
- Le démarrage de l'application ne doit jamais échouer à cause du contenu.
- Pas de migration.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Variable posée sur Develop et Staging (comme ADR-0108) | Absente de la production par construction | Écartée par le pilote : un réglage à poser ; Develop la copierait dans ses PR |
| B — **Reconnaître `RAILWAY_ENVIRONMENT_NAME` = `Develop` ou `Staging`** | Rien à poser ; `production` exclu explicitement ; un nom inconnu laisse une ligne d'avertissement | Retenue |
| C — Toutes les leçons du dépôt | Develop et Staging identiques au dépôt | Écartée : efface les résultats de test de 101 leçons ; le pilote ne travaille que les feuilles à sujets |
| D — Bouton « charger depuis le dépôt » dans Imports | Visible, déclenché à la demande | Écartée : une action à faire, et la production aurait le bouton |

## 4. Décision

> **Nous chargeons, à chaque démarrage d'un environnement Railway nommé `Develop` ou `Staging` (casse ignorée), les leçons du dépôt qui portent au moins un sujet de devoir, par la chaîne d'import ordinaire ; une leçon présente, même publiée, n'y voit remplacés que ses exercices de notion, ses problèmes et ses sujets de devoir, son cours et ses fiches restant intacts ; puis tout est publié.**

1. **Repérage.** `production` (toute casse), un environnement de PR (`PrEnvironment.active?`) ou l'absence de `RAILWAY_ENVIRONMENT_NAME` : rien. `Develop` ou `Staging` : chargement. Tout autre nom : rien n'est chargé, une ligne d'import `course_tree` refusée porte l'erreur `unknown_environment` (« environnement non reconnu : <nom> »).
2. **Sélection.** Les fichiers v3 dont la leçon a une clé `subjects` non vide.
3. **Changement.** L'empreinte SHA-256 du fichier est comparée à celle du dernier rapport `course_tree` terminé dont le fichier s'appelle `chargement-automatique-<niveau>-<matière>-<fichier>` ; égale : rien, aucune ligne.
4. **Remplacement.** Leçon absente : créée entière. Leçon présente, publiée ou non : pour ce seul appelant, l’adaptateur d’import passe en mode « exercices et sujets seulement » ; l’écrivain efface les exercices de la leçon (notions et problèmes), ses sujets et ce qui s’y rattache (séances, tentatives, badges, lacunes nées de ces séances, devoirs envoyés), garde le cours, les notions, leurs fiches et leurs lectures, réécrit exercices et sujets en les rattachant aux notions existantes par leur nom (une notion introuvable refuse la leçon), et fusionne dans les figures de la leçon celles que ces exercices et sujets citent. La cascade de publication publie ensuite ce qui est en brouillon. L’import à la main garde son refus `lesson_already_published`.
5. **Auteur.** Le plus ancien membre actif de l'équipe ; s'il n'y en a pas, rien n'est chargé (journal).
6. **Sûreté du pré-déploiement.** Tâche `contenus:charger` lancée par le pré-déploiement Railway (`bin/rails db:prepare db:seed`, ADR-0052) : `db/seeds.rb` charge `db/seeds/contenus.rb` en production Rails (Develop, Staging et production y tournent), pas dans un environnement de PR ; `bin/docker-entrypoint` ne convient pas, le `CMD` du Dockerfile ne se termine pas par `./bin/rails server`. Elle tourne sous un verrou consultatif PostgreSQL ; toute erreur est journalisée et le pré-déploiement n'échoue jamais à cause d'elle. Un fichier inchangé dont la leçon n'est pas entièrement publiée (cours non publié, brouillon restant) voit sa publication reprise seule, sans réimport ; un échec de publication est journalisé avec le nom de la leçon.

## 5. Conséquences

### 🟢 Positives

- Une fusion dans `Develop` suffit à voir les feuilles à jour sur Develop ; un train suffit pour Staging.
- Un seul chemin d'écriture : les erreurs d'un fichier sont celles de l'écran Imports, lisibles au même endroit.

### 🔴 Coûts consentis

- Les résultats des élèves et les devoirs envoyés sur les exercices et sujets remplacés sont effacés sur Develop et Staging à chaque changement de son fichier.
- Un renommage de l'environnement Staging chez Railway arrête le chargement (la ligne d'avertissement le dit, mais il faut la lire).
- Le démarrage s'allonge du temps d'un import quand un fichier a changé.
- Une correction du texte d’une fiche ne suit pas : elle reste à importer à la main.
- Le remplacement des exercices d’une leçon publiée existe désormais dans le code : son accès est réservé à cet appelant, et un test garde le refus de l'import à la main.

## 6. Liens

- ADR-0108 (environnements de PR), ADR-0113, ADR-0116 §4.4 (remplacement d'un brouillon), ADR-0121 (sujets).

## 7. Comment vérifier

- Tests du use case : Develop/Staging chargent, `production` et un environnement de PR ne font rien, un nom inconnu laisse une ligne refusée, un fichier inchangé ne crée pas de ligne, une leçon publiée est remplacée et republiée.
- Test de l'import à la main : une leçon publiée reste refusée.
- Après déploiement de Develop : l'écran Imports montre la ligne `chargement-automatique-3eme-mathematiques-proprietes-de-thales-dans-un-triangle.json`, et « Prépare devoirs » de Thalès compte 4 sujets.
