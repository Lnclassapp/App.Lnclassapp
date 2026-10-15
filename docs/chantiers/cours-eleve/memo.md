# Memo — Page Cours de l'élève aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `Develop` (cadrage, docs seules) ; le code passera par une PR |
| **Programme** | — |

---

## Le problème

La page « Cours » de l'élève (catalogue partagé `catalog/courses#index`, branche élève) fonctionne, mais elle ne ressemble pas encore à l'accueil élève, redessiné aux couleurs de Wave et de Djamo (chantier `accueil-eleve`). L'élève passe de l'un à l'autre par le menu : les deux écrans doivent parler la même langue visuelle.

## Pour qui

L'élève (Student), le plus souvent sur un téléphone Android d'entrée de gamme, parfois avec une connexion faible.

## Pourquoi maintenant

L'accueil élève est dessiné et ses décisions sont prises. « Cours » est l'écran suivant du menu élève ; on le dessine avec le même design system avant de coder.

## Hors périmètre

- La page d'un cours (`catalog/courses#show`) : seul son point d'entrée change.
- Le catalogue vu par l'enseignant, la direction et l'équipe (filtres Niveau et Série).
- L'ordre des cours et la pagination (24 par page) : inchangés.

## Point de départ : la page actuelle

Relevée dans le code le 2026-10-15 (UDR-0013, UDR-0054, UDR-0057) : lien « Accueil », titre « Cours » avec l'info « Tu vois seulement les cours de ton niveau. », recherche pendant la frappe, liste « Matière », compteur et « Tout voir », cartes (matière, nom, sous-titre sur 2 lignes, « Ouvrir le cours → »), « Afficher plus de cours » après 24 cours, états aucun résultat, sans classe, aucun cours publié, erreur de recherche.

## Maquettes

Toile : https://claude.ai/artifact/78wguP9ZtQc1g5LrtcxTy4 (téléphone d'abord).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| On repart de la page actuelle ou d'une page nouvelle ? | On commence par le téléphone (porteur, 2026-10-15), en repartant du cadre et des blocs actuels, comme pour l'accueil élève. | Même en-tête que l'accueil élève ; la carte garde « Ouvrir le cours → ». |
| Garde-t-on un filtre « Matière » (liste ou pastilles) ? | Non : on le supprime, la recherche suffit (porteur, 2026-10-15). | La page n'a plus que la recherche ; « Tout voir » n'apparaît que pendant une recherche ; le message sans résultat devient « Essaye un autre mot. ». Le filtre reste pour l'enseignant, la direction et l'équipe. |
| Que change la tablette ? | Passons à la tablette (porteur, 2026-10-15). | À partir de 700 px, la page se centre (720 px au plus) et les cartes passent sur deux colonnes, de même hauteur, « Ouvrir le cours » aligné en bas ; l'en-tête montre « Besoin d'aide ? » en entier. |
| Que change l'ordinateur ? | Passons à l'ordinateur (porteur, 2026-10-15). | À partir de 1024 px (ordinateur et tablette à l'horizontale), menu à gauche avec « Cours » actif, cartes sur trois colonnes ; l'icône de la matière passe au-dessus du texte pour laisser la place au titre et à la description. |
| La carte montre-t-elle l'avancement de l'élève ? | Oui (porteur, 2026-10-15). | Sous la description : une barre des fiches lues, « 5 fiches lues sur 8 · 2 exercices faits », « Pas encore commencé » sinon ; barre et texte en vert quand toutes les fiches sont lues. Il faut une lecture par élève des fiches lues et des exercices faits par cours. |
| Groupe-t-on les cours par matière ? | Oui (porteur, 2026-10-15). | Un titre par matière (icône, nom complet, nombre de cours), puis ses cartes ; la carte ne répète plus la matière. La recherche garde les groupes. |
| Quels niveaux la page montre-t-elle ? | Le niveau de l'élève uniquement (porteur, 2026-10-15). | Comme aujourd'hui ; le niveau s'affiche désormais à côté du titre (« Cours 3e »), l'info le rappelle. Aucun filtre de niveau. |
| Garde-t-on la barre d'onglets en bas du téléphone ? | Non, on la retire (porteur, 2026-10-15). | Au téléphone et sur tablette, Accueil, Cours et Ma classe passent dans le menu de l'avatar, la page en cours en surbrillance ; sur ordinateur, le menu de gauche reste. Décision commune avec `accueil-eleve` (UDR-0080 à amender). |

## Questions ouvertes

1. Ordre des matières : celui du programme (Mathématiques d'abord) ou l'ordre alphabétique ?
2. La carte ouvre-t-elle le cours là où l'élève s'est arrêté (« Reprendre ») ?
