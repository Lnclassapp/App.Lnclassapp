# Journal — Les feuilles d'exercices vérifiées et lisibles sur chaque leçon

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-06 | Le test de rendu visite chaque feuille, en lecture et à remplir, à 390 px et sur ordinateur. | Les exercices ne sont plus sur la page de la leçon depuis #464. | Non |
| 2026-11-06 | QCM sur ordinateur : colonnes à la taille, empilé s'il ne tient pas (porteur). | Les colonnes de 4,5 em coupaient les propositions. | UDR-0152 §3, amendement |

## À trancher

- …

## Ce qui a dérapé

- Premier run : la CI locale était rouge parce que le CSS n'était pas compilé dans le conteneur (`application.css` absent), sans rapport avec le code.

## Clôture (2026-11-06)

- Livré par #500. Les 60 leçons de la base passent le test de rendu avec leurs feuilles (avant : 59 sur 60).
- Appris : depuis #464, la vérification d'une leçon ne voyait plus ses exercices ; une vérification doit suivre les pages où le contenu s'affiche, pas celles où il s'affichait.
- Reste ouvert : rien.
