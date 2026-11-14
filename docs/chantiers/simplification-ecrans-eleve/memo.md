# Mémo — simplification-ecrans-eleve

**Slug** : `simplification-ecrans-eleve` · **Cycle** : feature (3 écrans) · **Date** : 2026-11-14

## Le problème

L'accueil de l'élève, la vue d'une matière et la page d'une leçon empilent des blocs qui se répètent (carte « Prochain exercice », « Exercice du jour », case et bandeau « Inviter », « Tous les exercices », cadre noir). L'élève, souvent sur Android d'entrée de gamme, lit beaucoup avant son premier clic utile.

## Pour qui, pourquoi maintenant

L'élève (11 à 18 ans). Le porteur a validé le 2026-11-14 des maquettes minimalistes dans le style de l'app Wave : [`maquettes/`](maquettes/README.md) (4 HTML, données fictives).

## Ce qu'on fait

Trois écrans conformes aux maquettes, avec les données réelles : accueil `/students`, `/courses?material=…`, `/courses/<slug>`. Les règles sont écrites d'abord : UDR-XXXX-ecrans-minimalistes-style-wave.

## Hors périmètre

Les écrans enseignant, direction et équipe ; le catalogue sans `?material=` ; la recherche et la pagination des leçons (inchangées) ; la charte `lnclass-design-system` (skill hors dépôt, voir `journal.md`) ; toute migration (l'icône d'une leçon est calculée).

## Grill (décisions du porteur, reprises des maquettes)

- Leçons d'une matière en grille ; une icône par leçon, choisie automatiquement selon sa matière et son titre.
- Page leçon : 3 premiers éléments de « Prépare interros » et « Prépare devoirs », puis « Voir plus (n) ».
- Jonction bleu → blanc de l'accueil abaissée de 30 % (le blanc commence à 159 px).
- « Exercice du jour » et sections vides retirés ; plus de raccourci en double.
