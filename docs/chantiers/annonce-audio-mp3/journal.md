# Journal — Un MP3 enregistré au téléphone est refusé à la création d'une annonce

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

- **2026-10-05** : le porteur n'a plus le fichier refusé. Sans lui, le bug ne se reproduit pas, et la porte « bug reproduit à la main » ne peut pas être franchie. Le chantier s'arrête au cadrage. Choisir les enregistrements de téléphone acceptés (autres marques MP4/3GP, MP3 précédé d'octets de remplissage, AMR, OGG/Opus) devient une question du chantier feature `annonces-v2`. Leçon : quand un fichier est refusé, garder le fichier.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
