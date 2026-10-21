# Memo — Environnements de PR sur Railway

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-21 |
| **Branche** | `feature/environnements-de-pr` |
| **Programme** | — |

---

## Le problème

Pour essayer une PR, le porteur doit aujourd'hui la jouer sur sa machine. Il ne peut pas l'ouvrir sur un téléphone hors de son Wi-Fi, ni la montrer à quelqu'un d'autre. L'hébergeur sait créer un environnement par PR, avec une adresse publique, et le supprimer à la fusion. Activé tel quel, ce mécanisme a trois défauts :

- l'environnement ne se met jamais en veille, parce que le traitement des tâches de fond interroge la base en continu : chaque PR ouverte coûte un environnement allumé en permanence ;
- la base est créée sans référentiel ni comptes : on ne peut pas se connecter ;
- rien ne filtre les PR de promotion (Develop → Staging, Staging → main) ni celles ouvertes par des robots.

De plus, l'hébergeur ne lira plus la configuration de déploiement actuelle à partir du 2026-12-01. Sans migration, la production perd la préparation de la base avant chaque livraison (migrations et seeds) et le contrôle de santé.

## Pour qui

- **Le porteur** (rôle Team), quand une PR est prête à être essayée : il ouvre son adresse sur l'ordinateur ou le téléphone et se connecte avec un compte de test.
- **Les personnes à qui il montre une PR** : enseignants ou directions pilotes, qui jouent un parcours sur des données fictives.

## Pourquoi maintenant

- Le 2026-12-01, la configuration de déploiement actuelle cesse d'être lue, en production comme ailleurs.
- Le porteur n'a pas d'autre moyen d'essayer une PR hors de sa machine, et le choix de l'environnement de base est fait : Develop.

## Hors périmètre

- Les environnements de PR des robots : désactivés (décision du porteur, 2026-10-21).
- Les environnements pour les PR de promotion Develop → Staging et Staging → main (décision du porteur, 2026-10-21).
- Les données d'activité déjà jouée (séances, badges) : leur création dure environ 20 minutes, trop long pour un déploiement.
- Toute donnée réelle : un environnement de PR ne contient que des données fictives.
- Un changement de l'environnement Develop lui-même, de Staging ou de la production, au-delà de la migration de leur configuration à l'identique.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel environnement sert de base ? | Develop (porteur, 2026-10-21) | Les environnements de PR héritent des variables et services de Develop : tout réglage propre aux PR doit s'y distinguer de Develop |
| Faut-il un environnement pour les PR de robots et de promotion ? | Non (porteur, 2026-10-21) | Le réglage robots se coupe dans l'hébergeur. Pour les promotions, l'hébergeur ne filtre pas par branche cible : il faut un mécanisme à nous |
| Quelles données dans un environnement de PR ? | Les données de test : établissements, enseignants, classes, élèves (porteur, 2026-10-21) | En production, seule l'identité est semée : référentiel, DRENA, comptes fictifs et trois établissements de test doivent être semés dans les environnements de PR, et nulle part ailleurs hors développement |
| Les tâches de fond doivent-elles tourner dans un environnement de PR ? | Proposition retenue : non, pour permettre la mise en veille (porteur, 2026-10-21) | Amendement de la décision « worker toujours actif ». Piège connu : ce worker n'a jamais tourné par le passé à cause d'une condition oubliée ; l'exception doit être étroite et testée |
| Par quoi commencer ? | La migration de la configuration de déploiement (porteur, 2026-10-21) | Premier lot, livrable seul, à comportement identique pour Develop, Staging et production |
| La nouvelle configuration remplace-t-elle l'ancienne à l'identique ? | Non (documentation de l'hébergeur, 2026-10-21) : elle n'est pas relue à chaque livraison, elle s'applique en ligne de commande, environnement par environnement, et décrit tout le projet ; elle ne documente ni la politique de redémarrage, ni la construction par image, ni la mise en veille | La migration se fait avec l'outil de l'hébergeur, connecté au projet, par le porteur : un fichier écrit à la main risquerait de supprimer un service oublié. Bloquée tant que la connexion du porteur à l'hébergeur ne marche pas |
| L'hébergeur permet-il des réglages propres aux environnements de PR ? | Seulement dans l'ancienne configuration, qui disparaît le 2026-12-01 ; aucune variable ne signale un environnement de PR (documentation, 2026-10-21) | L'application reconnaît elle-même un environnement de PR : une variable posée sur Develop est copiée dans ses PR ; si le nom de l'environnement courant n'est pas celui qu'elle porte, c'est une PR. Staging et production n'ont pas la variable : rien ne s'y déclenche par erreur |
| La base d'un environnement de PR part-elle vide ? | Oui : bases neuves, la copie des volumes a été retirée (hébergeur, 2025) | Le semis complet se joue à chaque création, en quelques secondes ; rejoué, il ne crée rien |
| Peut-on filtrer les PR de promotion ? | Aucun filtre par branche cible n'est documenté | À observer à la prochaine promotion. S'il y a un environnement, une action GitHub le supprimera, ce qui demande un jeton de l'hébergeur dans les secrets GitHub |
| Les variables de Develop arrivent-elles dans la PR ? | Oui, sauf les variables scellées (documentation) | Le porteur vérifie qu'aucune variable indispensable de Develop (clé maître, base, stockage) n'est scellée, sinon l'environnement de PR ne démarre pas |
| Une adresse publique, des comptes au PIN connu : faut-il protéger l'accès ? | Oui : un mot de passe commun devant tout l'environnement de PR, que le porteur donne aux personnes à qui il montre la PR (porteur, 2026-10-21) | Le mot de passe vient d'une variable de Develop, copiée dans les PR. Dans un environnement de PR sans ce mot de passe, tout est refusé : un oubli ferme l'accès au lieu de l'ouvrir. Seul le contrôle de santé de l'hébergeur passe sans mot de passe. Develop, Staging et production ne demandent rien de plus |

## Cas limites identifiés

- Une PR ouverte depuis une branche déjà déployée (Develop, Staging) : c'est une promotion, pas d'environnement.
- Une PR rouverte après fermeture : l'environnement est recréé, la base repart vide et se resème.
- Un nouveau commit sur la PR : redéploiement, les seeds rejoués ne créent rien de plus.
- Une PR dont la migration échoue : le déploiement échoue, rien n'est servi.
- Les fichiers téléversés : un environnement de PR ne doit jamais écrire dans le stockage de Develop.

## Questions encore ouvertes

- Le stockage de fichiers est-il dupliqué dans l'environnement de PR, ou partagé avec Develop ? À vérifier par le porteur à la première PR.
- Une PR de promotion crée-t-elle un environnement ? À observer à la prochaine promotion.
- Les tâches de fond : sans worker, sont-elles exécutées dans le processus web (proposition), ou pas du tout ?
