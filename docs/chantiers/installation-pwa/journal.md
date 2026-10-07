# Journal — Installer Lnclass sur le téléphone (PWA)

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-07 | La PWA passe avant les apps Android | Le porteur a vu une vidéo sur les apps mobiles faites avec Claude Code (Expo) ; Expo réécrirait tous les écrans, la PWA garde ceux du site | Oui : ADR-0082, amendement de l'ADR-0070 |
| 2026-10-07 | Les exercices hors ligne sortent vers `exercices-hors-ligne` | Ils touchent la correction de l'ADR-0054 ; le chantier ne tenait plus en quelques jours (grill, question 10) | Non : l'ADR viendra avec `exercices-hors-ligne` |
| 2026-10-07 | Le bandeau ne garde rien sur le serveur | L'installation est une affaire d'appareil (grill, question 9) | Oui : ADR-0082 §4.5 ; colonnes `install_banner_*` abandonnées |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le chantier est parti comme « installer l'app » et a failli absorber les exercices hors ligne, plusieurs semaines de travail sur le moteur d'évaluation. Le grill l'a vu à la question 10 : poser la question de la taille dès qu'une réponse fait sortir le chantier de son contexte borné.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Exercices hors ligne : téléchargement des exercices assignés, réponses envoyées au retour du réseau, correction au serveur, premier arrivé gagne, réponses gardées au nom de l'élève sur un téléphone partagé | Touche la correction (ADR-0054) et l'identité ; plusieurs semaines | `exercices-hors-ligne`, qui reprend les questions 1 à 6 du grill |
| Relire hors ligne les pages déjà vues | Garderait le HTML des comptes sur un téléphone partagé (ADR-0076) | `exercices-hors-ligne` |
| Bandeau seulement à partir de la deuxième visite ? | Question encore ouverte au porteur | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
