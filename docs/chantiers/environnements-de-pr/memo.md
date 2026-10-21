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

## Cas limites identifiés

- Une PR ouverte depuis une branche déjà déployée (Develop, Staging) : c'est une promotion, pas d'environnement.
- Une PR rouverte après fermeture : l'environnement est recréé, la base repart vide et se resème.
- Un nouveau commit sur la PR : redéploiement, les seeds rejoués ne créent rien de plus.
- Une PR dont la migration échoue : le déploiement échoue, rien n'est servi.
- Les fichiers téléversés : un environnement de PR ne doit jamais écrire dans le stockage de Develop.

## Questions encore ouvertes

- Une adresse publique avec des comptes au PIN connu : faut-il protéger l'accès ?
- La base d'un environnement de PR part-elle vide ou copiée de Develop ? Le stockage de fichiers est-il dupliqué ?
- Comment l'application sait-elle qu'elle tourne dans un environnement de PR ?
