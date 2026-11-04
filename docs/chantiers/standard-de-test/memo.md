# Memo — Un standard de test pour Lnclass

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-02 |
| **Branche** | `feature/standard-de-test` |
| **Programme** | — |

---

## Le problème

Lnclass n'a pas de standard de test. Chaque endroit a ses propres données :

- en local et en PR, le jeu démo crée 3 établissements, 63 classes, des milliers d'élèves **sans activité**, et importe toutes les leçons v3 ;
- un second jeu (Saint-Michel, local seulement) simule l'activité d'une seule classe de Tle D ;
- Develop recharge à chaque déploiement toutes les leçons v3 du programme (~350 publiées) ;
- Staging ne reçoit automatiquement que les leçons à sujets ; la production, que des imports manuels.

Conséquences : on ne sait pas sur quoi une PR a été testée ; les tableaux de bord enseignant, direction et équipe (filtre DRENA) affichent des zéros partout sauf sur une classe ; les cas difficiles (classe vide, collège seul, établissement mixte, séries A, leçon très longue) ne sont présents nulle part de façon sûre ; aucune page n'est jamais vue avec un établissement de grande taille ; l'affichage des leçons n'est vérifié qu'à l'œil (30 sur 347) ; corriger une leçon demande un réimport manuel ; aucune règle ne dit ce qu'une PR a prouvé.

## Pour qui

- **Le porteur et l'équipe** : un jeu unique, recréé en une commande, pour tester, faire la recette et faire des démonstrations.
- **Les rédacteurs de contenus** : voir tout de suite une leçon modifiée, l'améliorer en boucle courte.
- **Les enseignants, directions et DRENA** à qui l'on fait une démonstration : des tableaux de bord avec de vrais chiffres.
- **Les enseignants relecteurs** : tout le contenu sur Staging, et seulement là.

## Pourquoi maintenant

Les vagues de contenus v3 (347+ leçons, PR #439 à #447) arrivent plus vite que la relecture humaine, et les statistiques enseignant et direction ne se testent pas sans activité. Le porteur a validé le 2026-11-02 quatre principes et huit objectifs (voir l'ADR).

## Objectifs validés (2026-11-02)

1. Activité fictive sur un trimestre (séances, notes, lacunes, devoirs rendus et en retard), **déterministe**, pour les tableaux de bord enseignant, direction et DRENA.
2. Un parcours de recette par rôle (élève, enseignant, direction, DRENA, équipe), **rejoué seulement dans le chantier qui touche ce rôle ou cet écran**.
3. Les cas difficiles présents : classe vide, élève sans activité, public / privé / mixte, collège seul, séries A et C, leçon très longue, téléphone 390 px.
4. Corriger un contenu en local puis l'améliorer : modifier, voir rendu tout de suite, valider, PR, rechargement de cette seule leçon sur Develop.
5. Le même jeu en local, en PR et sur Develop, recréé en une commande en quelques minutes, remis à zéro à volonté, sans aucune vraie donnée personnelle.
6. Un grand établissement (~1 500 élèves) pour repérer les pages lentes.
7. Le même jeu sert de démonstration à un établissement ou une DRENA.
8. Une règle simple de fusion : chaque PR et chaque vague dit ce qu'elle a prouvé sur ce jeu.

Plus les 4 principes : une leçon par matière et par niveau dans le jeu ; contrôle automatique de l'affichage de toutes les leçons dans la CI (5 min par tâche) ; un rôle par environnement ; preuve d'une vague.

## Hors périmètre

- **Aucune suppression** sur Develop, Staging ou production sans accord explicite du porteur. La remise à zéro de Develop est la décision ouverte n° 1.
- Production inchangée : import manuel du seul validé.
- **Pas de compte DRENA** : le rôle n'existe pas (rôles : élève, enseignant, direction, équipe). Le parcours « DRENA » se fait avec un compte équipe sur le tableau de bord filtré par DRENA. Un vrai compte DRENA serait un chantier à part (décision ouverte n° 6).
- Pas de compte Parent : pas de parcours parent aujourd'hui.
- Pas de nouvel écran ni de vue modifiée : pas d'UDR. Un écran lent trouvé par le grand établissement ouvre un chantier `optimize` séparé.
- Pas de correction des leçons : le test signale, les chantiers de contenus corrigent.
- La recette n'est **pas** rejouée après chaque déploiement.
- Pas d'environnement de démonstration nouveau dans ce chantier (décision ouverte n° 7).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| « Une leçon par matière et par niveau » : le niveau compte-t-il la série ? | Oui : Tle C et Tle D n'ont pas la même leçon de maths. | Une leçon par dossier niveau-série et par matière : 46 couples ont du v3 aujourd'hui. |
| 2nde, 4ème, 5ème, 6ème n'ont que du v1 : qu'y met-on ? | Le chargement ignore les v1. | Couples vides jusqu'à leur vague v3, écrits comme tels (décision n° 4). |
| Qui choisit les leçons, et si un fichier est renommé ? | Un choix implicite change à chaque arrivée de fichier. | Un **manifeste écrit** nomme chaque fichier ; un test refuse un fichier absent, non v3, ou un couple oublié. |
| « Déterministe » : avec des dates fixes, les tableaux « 7 derniers jours » se vident avec le temps. | Saint-Michel date tout entre le 14/09 et le 05/10/2026 : déjà vide aujourd'hui sur les périodes courtes. | Le trimestre se termine **la veille du chargement**, les tirages sont à graine fixe : mêmes chiffres, recalés sur la date. Une empreinte des totaux, testée, montre qu'un calcul a changé (décision n° 3). |
| Simuler un trimestre pour ~1 500 élèves par les use cases tient-il en « quelques minutes » ? | Saint-Michel : 20 élèves × 3 leçons × 6 passages via use cases ; ×75 élèves ne tient pas. | Le grand établissement a ses élèves et classes, mais une activité **échantillonnée** (une classe par niveau active) ; ou chargé seulement sur option (décision n° 5). Durée mesurée et plafonnée à 5 min. |
| « Remis à zéro à volonté » sur Develop = supprimer. | Develop porte ~350 leçons, des tentatives, des devoirs. | En local : une commande, sans question. Sur Develop : la même commande refuse sans une confirmation explicite, et la première remise à zéro attend l'accord du porteur. |
| « Aucune vraie donnée personnelle » : comment le prouver ? | Les numéros fictifs actuels (01…, 05…, 07…) ressemblent à de vrais numéros ivoiriens. | Noms tirés d'une liste fictive écrite dans le dépôt, numéros dans une plage réservée **non attribuable** ; un test refuse tout contact hors plage. Plage à confirmer (décision n° 8). |
| La démonstration à une DRENA peut-elle se faire sur Develop ? | Develop change à chaque fusion ; une démo peut tomber sur une PR cassée. | Le jeu est **présentable** (noms d'établissement neutres, chiffres crédibles) ; l'endroit de la démo reste à choisir (décision n° 7). |
| La recette par rôle : quand la rejouer ? | Précision du porteur : seulement dans le chantier qui touche ce rôle ou cet écran. | Une **table écran → parcours** dans le dépôt ; la PR coche le parcours rejoué ; aucune recette automatique après déploiement. |
| « Règle de fusion simple » : qui la vérifie ? | Une règle non vérifiée s'oublie. | Une section « Prouvé sur le jeu standard » dans le modèle de PR, vérifiée par une garde de la CI (section présente et non vide quand le code change). |
| Le test d'affichage des 417 fichiers tient-il dans 5 min ? | ~2 à 3 s par fichier à deux largeurs : 15 à 20 min. | PR : fichiers touchés seulement ; train : tout, en parts de ≤ 5 min ; dérogation au budget système (décision n° 2). |
| Staging = tout le contenu relu : le chargement doit-il remplacer une leçon relue ? | Non, cela effacerait la relecture. | Staging ajoute les leçons absentes sans toucher aux présentes (décision n° 2 bis). |
| Un enseignant dans deux établissements, un élève dans deux classes ? | Le premier a déjà cassé ; le second n'existe pas dans le métier. | Un enseignant affecté à deux établissements est dans le jeu. |
| L'aperçu local d'un fichier peut-il toucher un environnement partagé ? | Il remplace la leçon entière, tentatives comprises. | Refusé hors développement local. |

## Cas limites identifiés

- Fichier du manifeste renommé ou repassé en v1 : test rouge, chargement non commencé.
- Jeu rejoué : rien en double ; jeu remis à zéro : mêmes totaux (empreinte identique).
- Chargement le 1er janvier ou un dimanche : le trimestre recule, l'empreinte reste identique (elle porte sur les totaux, pas sur les dates).
- Une migration ajoute une colonne obligatoire : le jeu échoue en local avant d'échouer sur Develop (test de chargement en CI).
- Classe vide et élève sans activité : les tableaux de bord affichent leur état vide, pas une erreur.
- PR qui touche 60 leçons : le rendu se découpe comme au train.
- JSON refusé à l'import : l'aperçu ne touche pas la base ; le test d'affichage échoue avec le code de refus.

## Questions encore ouvertes

1. **Develop** : (a) y charger le jeu standard **à côté** des ~350 leçons, sans rien supprimer [recommandé d'abord] ; (b) le remettre à zéro au jeu standard — supprime ~350 leçons publiées, leurs tentatives, séances, devoirs, lectures et les 3 établissements de test.
2. **CI** : dérogation au budget système de 15 s pour le test d'affichage (fichiers touchés en PR, tout au train en parts ≤ 5 min). **2 bis. Staging** : ajout automatique des leçons v3 absentes, sans remplacer les présentes ?
3. **Dates de l'activité** : trimestre glissant terminé la veille du chargement [recommandé] ou dates fixes (chiffres identiques mais périodes courtes vides) ?
4. **Niveaux sans v3** (2nde, 4e, 5e, 6e) : vides ou une leçon v1 ?
5. **Grand établissement** : toujours chargé, activité échantillonnée [recommandé], ou seulement sur option (`--grand`) pour garder la commande sous 5 min ?
6. **DRENA** : parcours via un compte équipe filtré par DRENA [recommandé], ou ouvrir un chantier « compte DRENA » ?
7. **Démonstration** : sur Develop, ou sur un environnement Railway dédié (coût) ?
8. **Plage de numéros fictifs** : laquelle est garantie non attribuable en Côte d'Ivoire ?
9. **Choix des leçons** : la première du programme de chaque matière, ou un choix du porteur ?
