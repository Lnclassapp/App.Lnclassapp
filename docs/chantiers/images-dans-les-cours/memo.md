# Memo — Des images dans les fiches de cours

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-10-10 |
| **Branche** | `feature/images-dans-les-cours` |
| **Programme** | — |

---

## Le problème

Une fiche essentielle ne contient que du texte : l'éditeur et l'import retirent toute image, et la méthode de rédaction interdit d'en prévoir (un schéma « se décrit en mots »). Pour les matières où la notion passe par un dessin (un circuit électrique, une figure de géométrie, un schéma de cellule, une carte), l'élève qui révise seul le soir sur son téléphone doit reconstruire le dessin dans sa tête à partir d'une description. Constaté sur la première leçon de Physique-Chimie de 6e (« Le circuit électrique ») : sans schéma, la leçon est difficile à comprendre.

## Pour qui

- **L'élève**, au moment où il lit une fiche pour réviser : il voit l'image à l'endroit où le texte en parle.
- **L'équipe contenu**, au moment où elle produit une leçon (par import ou dans l'éditeur) : elle place l'image dans la fiche.
- **L'enseignant**, qui lit les mêmes fiches que ses élèves depuis le catalogue.

## Pourquoi maintenant

La production des leçons de la progression 2026-2027 vient de commencer (6 leçons de 6e le 2026-10-08, 18 leçons de Tle D avant). Chaque leçon rédigée sans image devra être reprise plus tard. L'équipe a validé l'idée le 2026-10-10.

## Hors périmètre

- **Génération d'image dans l'application.** Aucun fournisseur d'IA d'image n'est branché : les images sont produites avec Claude Design, hors de l'application, puis envoyées.
- **Reprise en masse des leçons existantes.** Les 24 leçons déjà importées ne reçoivent pas d'emplacements d'image ; un import ne met toujours jamais à jour un cours existant. L'ajout manuel d'une image dans une ancienne fiche reste possible.
- **Image dans les propositions de réponse.** Une question porte au plus une image, au-dessus de l'énoncé.
- **Image dans le JSON d'import.** L'import transporte la description d'une image, jamais l'image.
- **SVG, GIF animé, vidéo, son.** PNG, JPEG et WebP seulement.
- **Envoi d'image par un enseignant, un élève, un parent ou une direction.** Seuls les rôles d'équipe `admin` et `contenu` envoient, remplacent ou retirent une image ; le rôle `terrain` non.
- **Image de couverture d'un cours** ou d'une carte du catalogue.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| D'où viennent les images ? (SVG dessiné par le prompt, fichier envoyé par l'équipe, les deux, ou IA d'image) | Générées par une IA d'image, à partir d'une description écrite dans la leçon. | Nouveau fournisseur externe (coût par image, clé, panne possible). Une IA d'image dessine mal un schéma exact (symboles normalisés d'un circuit, figure cotée) : le risque d'erreur pédagogique devient le risque principal du chantier, il faut une relecture humaine de chaque image avant que l'élève la voie. |
| Qui lance la génération, et quand ? | L'application, à la demande : la leçon importée porte une description par image ; dans l'écran de la fiche, l'équipe clique « Générer », voit le résultat, le garde ou le régénère. | Le format d'import gagne une description d'image (sans image). L'appel au fournisseur part d'un écran de l'équipe, jamais de l'import ni de l'élève : le coût suit les clics. Une image générée n'est visible de l'élève qu'une fois gardée par l'équipe. Il faut un endroit pour la description dans la fiche et un état « image à générer / générée / gardée ». |
| Une fiche à publier a une image décrite mais pas encore gardée : que se passe-t-il ? | La publication est refusée tant que chaque image décrite n'est pas gardée, ou sa description retirée. | Nouvelle condition de publication d'une fiche (comme le texte de remplacement des images d'article). « Tout publier » sur un cours peut être refusé : le refus doit nommer la fiche et l'image en cause. Les fiches déjà publiées sans description d'image ne sont pas touchées. |
| Quel fournisseur d'IA d'image ? | « Avec les moyens du bord » : les images sont produites avec Claude Design (abonnement Claude de l'équipe), pas avec une API d'image payante. | Claude Design est un outil de claude.ai : l'application ne peut pas l'appeler. La génération sort donc de l'application, ce qui **remplace la réponse à la question 2** : l'équipe produit l'image dans Claude Design à partir de la description, l'exporte, puis l'envoie dans la fiche. Aucun fournisseur externe ni clé dans l'application ; le chantier devient « décrire, envoyer et relire une image de fiche ». |
| Sous quelle forme l'image arrive-t-elle ? | Une image PNG ou WebP exportée de Claude Design, téléversée par l'équipe dans l'éditeur de la fiche, à l'emplacement voulu. | On réutilise le chemin déjà éprouvé des images d'article (réduction par le navigateur, contrôle de l'en-tête du fichier, taille plafonnée) au lieu d'en écrire un second. Pas de SVG (code embarqué possible) ni d'image dans le JSON d'import : l'import ne transporte que la description. |
| Combien d'images par fiche, de quel poids ? | 300 Ko au plus par image ; pas de nombre fixe, il dépend de la leçon. | Plafond de poids plus bas que celui du blog (1 Mo) : la réduction par le navigateur vise 300 Ko. Pas de limite métier du nombre, mais chaque image se charge à la demande (au défilement) pour qu'une fiche longue ne coûte que ce que l'élève regarde. Un plafond technique anti-abus reste à fixer (question ouverte). |
| Comment les leçons déjà importées reçoivent-elles des images ? | Elles n'en reçoivent pas : seules les nouvelles leçons ont des images. | La règle « un import ne met jamais à jour l'existant » est conservée. Les 24 leçons déjà rédigées (18 de Tle D, 6 de 6e) restent en texte seul ; pour en illustrer une, il faudra la régénérer et la réimporter selon la procédure existante (renommer et archiver le cours vide, puis importer). Ce point va dans `Hors périmètre`. |
| L'équipe peut-elle insérer dans l'éditeur une image non décrite par l'import ? | Oui, librement, n'importe où dans la fiche. | Les emplacements décrits sont des rappels à remplir, pas les seuls points d'entrée : l'éditeur de fiche s'ouvre aux images comme celui des articles. La condition de publication porte sur les emplacements décrits ; une image ajoutée librement ne crée pas d'emplacement. Contradiction possible avec la réponse précédente (voir question suivante). |
| L'éditeur accepte-t-il les images aussi dans les fiches déjà existantes ? | Oui, partout. « Pas d'images pour l'existant » signifie seulement : pas de reprise en masse prévue. | Aucune règle de date ni de coupure : une seule règle pour toutes les fiches. L'équipe pourra illustrer une ancienne fiche à la main si elle le veut. La ligne du `Hors périmètre` vise la reprise en masse, pas l'ajout manuel. |
| Les questions d'exercice ont-elles aussi des images ? | Oui : fiches et questions. | Le chantier traverse deux contextes bornés (le catalogue pour les fiches, l'évaluation pour les questions). L'énoncé d'une question est un texte simple, pas un texte riche : l'image d'une question ne s'insère pas dans le texte, elle s'attache à la question. Le prompt de rédaction perd sa règle « aucune question ne dépend d'une figure » pour les questions qui portent une image. Touche aussi l'écran de session d'exercice de l'élève et son poids sur mobile. |
| Où se trouve l'image d'une question ? | Au plus une image par question, affichée au-dessus de l'énoncé. Les propositions restent du texte. | L'écran de réponse ne change pas de forme : une image en tête de question, rien de plus. Une question au plus une image : pas de galerie, pas d'image dans les propositions (hors périmètre). |
| Que voit l'élève si l'image ne charge pas, ou s'il est malvoyant ? | Un texte de remplacement, obligatoire pour publier, pré-rempli avec la description venue de l'import. | Deuxième condition de publication, sur les fiches **et** sur les exercices : chaque image a son texte de remplacement. Le refus nomme l'image en cause. Une question qui dépend de son image reste compréhensible si l'image ne charge pas. |

## Cas limites identifiés

- **Fiche sans image** : rien ne change, ni pour l'élève ni pour la publication.
- **Emplacement décrit par l'import, jamais rempli** : la fiche (ou l'exercice) refuse de se publier ; « Tout publier » sur le cours refuse aussi et nomme la fiche et l'emplacement.
- **L'équipe retire la description d'un emplacement** au lieu de le remplir : la fiche redevient publiable.
- **Image d'une fiche publiée remplacée** : l'élève voit la nouvelle image ; l'ancienne n'est plus servie.
- **Image retirée du texte d'une fiche** : elle n'est plus servie ; elle n'est jamais visible tant que sa fiche est en brouillon.
- **Fiche ou cours archivé** : ses images ne sont plus servies, comme le texte.
- **Fichier trop lourd** (> 300 Ko après réduction), d'un autre format, ou dont le contenu ne correspond pas à l'extension : refusé à l'envoi, avec la raison.
- **Fichier photo avec position GPS** : métadonnées retirées avant stockage.
- **Une fiche très illustrée** (10 images ou plus) : chaque image se charge seulement quand l'élève y arrive en faisant défiler.
- **Question avec image en session d'exercice hors ligne ou sur réseau faible** : le texte de remplacement s'affiche à la place.
- **Même image voulue dans deux fiches** : elle est envoyée deux fois ; aucune bibliothèque partagée.

## Questions encore ouvertes

- **Plafond technique du nombre d'images** par fiche (anti-abus), puisqu'il n'y a pas de limite métier : proposition 30 par fiche, à valider.
- **Format exact de la description dans l'import** (champ de la fiche, de la question) et place de l'emplacement dans le texte de la fiche : tranché par l'ADR.
- **Style « ludique » commun** des images produites dans Claude Design (palette, personnages, trait) : à fixer dans la méthode de rédaction, pas dans l'application.
