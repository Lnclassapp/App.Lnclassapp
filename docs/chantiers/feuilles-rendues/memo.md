# Memo — Les feuilles d'exercices vérifiées et lisibles sur chaque leçon

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-11-06 |
| **Branche** | `test/feuilles-rendues` |
| **Programme** | — |

---

## Le problème

Depuis #464, les exercices d'une leçon ne sont plus sur sa page mais sur celle de chaque feuille (« Prépare interros », « Prépare devoirs »). Le test de rendu des leçons (`lesson_rendering_test.rb`) ne regardait que la page de la leçon : aucune vérification qu'un exercice tient à 390 px, que ses formules sont rendues, que ses figures sont dessinées. Étendu aux feuilles, il trouve sur les 60 leçons de la base :

- « Les alcanes » (3ème, physique-chimie), sujets 1 et 4 : une équation de combustion élargit la page à 390 px ;
- toute formule finie par un indice (CO₂, CH₂) dans un tableau montre une barre de défilement (2 px, marge négative de KaTeX) ;
- sur ordinateur, les colonnes de lettres des QCM (4,5 em, UDR-0152 §3) coupent les propositions : « CH₃ − », « L'hexan », « pentan ».

## Pour qui

L'élève qui lit un sujet (« Prépare devoirs ») avant de commencer, sur téléphone ou sur ordinateur ; l'enseignant qui le lit pour l'assigner.

## Pourquoi maintenant

Ticket #484 : le porteur s'intéresse aux règles d'affichage des exercices. Les 60 leçons de la base sont chargées sur Develop.

## Hors périmètre

- Le contenu des leçons (aucun fichier de `docs/contenus/` ne change).
- Les leçons de `docs/contenus/a-reprendre/`.
- La feuille à remplir (`fill`), déjà sans défaut sur les 60 leçons.
