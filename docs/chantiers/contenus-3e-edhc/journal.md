# Journal — Les 10 premières leçons d'EDHC de 3ème

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | Rédaction lancée avant la fusion de la vague 2, d'après les formes de l'ADR §4.2 ; contrôle et livraison après | Gagner le temps d'attente ; une figure d'une sorte non livrée ne passe pas le contrôle | Non |
| 2026-10-30 | Relecture indépendante (Opus) faite dès la rédaction, sans attendre la vague 2 | Elle porte sur le fond ; seul l'alignement des identifiants de carte attend le fond livré | Non |
| 2026-10-30 | Carte des aires culturelles (leçon 10) : ne sont coloriés que les districts où un groupe est majoritaire de façon sûre ; les districts mêlés restent blancs, le Mandé du Sud est situé par une ville (Man) | Une carte qui colorie un district mêlé d'un seul groupe est fausse ; l'ADR n'a pas de zone plus fine que le district | Non |
| 2026-10-30 | Aucune alliance précise entre deux peuples réels n'est affirmée ; les cas d'exercice sont fictifs | Aucune source sûre vérifiée pendant la rédaction ; à compléter par l'enseignant | Non |

## Ce qui a dérapé

- **Aucune leçon livrable au premier jet**, comme en Français : la relecture a trouvé de 0 à 4 bloquants par leçon (une question à deux bonnes réponses sur l'élection du maire, une CEDEF dite réservée aux femmes, un parti modèle au nom régional, un fraudeur au nom à connotation ethnique, un schéma affiché qui donnait la réponse d'un problème d'évaluation, le Zanzan oublié dans l'aire gour). Le contrôle ne voit rien de cela.
- **Corrections qui désignent une proposition par sa position** (« les trois premières ») dans 4 leçons : l'application mélange les propositions. Règle ajoutée au brief des rédacteurs ; le contrôle ne le détecte pas (chantier de suivi possible : avertissement du script).
- **Scratchpad partagé**, encore : un relecteur a vu son fichier de travail écrasé. Le brief impose maintenant le slug dans le nom de tout fichier temporaire.
- **Le challenger a vu des `**` à l'écran** dans les énoncés de 3 exercices : l'énoncé d'un exercice est affiché en texte brut (`simple_format`), alors que la consigne y permettait le gras. Corrigé dans les leçons (guillemets) et dans `prompt-redaction.md`. Les leçons de Français (5) et une d'Histoire-Géographie ont le même défaut : signalé à l'orchestrateur, hors de ce chantier.
- **Carte de la leçon 10** : la légende « Mandé du Sud » n'avait aucune zone coloriée (districts mêlés). Retirée de la légende ; le Mandé du Sud est situé par la ville de Man et dit dans la description.
- **Hook d'arrêt** : il demande un commit à chaque tour ; ignoré à dessein (un commit par lot).

## Ce qu'on a appris sur la codebase

- La matière EDHC n'existe pas dans `db/seeds/catalog.rb` : le challenger a dû la créer à la main pour importer. Elle doit exister en production avant l'import (sinon `unknown_material`).

## Clôture

- Challenger (rôle distinct, 2026-10-30) : 10 fichiers importés en brouillon par la vraie chaîne, 0 erreur ; fiches de 2 leçons à 390 px et 1280 px, figures `ready` ; fichier à lieu inconnu refusé (`figure_invalid`), rien créé. Question rédigée non jouable côté équipe sur un brouillon.
- Chantiers de suivi : avertissement du contrôle pour une correction qui désigne une proposition par sa position ; balisage `*` dans les énoncés d'exercice (contrôle, et leçons de Français et d'HG).
