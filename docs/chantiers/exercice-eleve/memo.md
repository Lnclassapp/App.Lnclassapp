# Memo — Parcours d'exercice de l'élève aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `Develop` (cadrage, docs seules) ; le code passera par une PR |
| **Programme** | — |

---

## Le problème

Le parcours d'un exercice (page de l'exercice, séance question par question, résultat) fonctionne, mais il ne ressemble pas encore aux écrans élève redessinés aux couleurs de Wave et de Djamo (`accueil-eleve`, `cours-eleve`, `ma-classe-eleve`). C'est l'écran où l'élève passe le plus de temps.

## Pour qui

L'élève (Student), le plus souvent sur un téléphone Android d'entrée de gamme, parfois avec une connexion faible.

## Hors périmètre

- Les vues de l'enseignant et de l'équipe sur l'exercice et le résultat (bonnes réponses visibles).
- Le moteur de notation (seuils 50, 70, 80, 100), les badges et la création des exercices.
- Les autres pages encore à redessiner : révision (cours et fiches), profil, historique, choix de classe, connexion et inscription.

## Point de départ : le parcours actuel

Relevé dans le code le 2026-10-15 (UDR-0021, UDR-0022, UDR-0023, UDR-0073) :
- **Page de l'exercice** : lien vers la fiche essentielle, cours, titre, matière, niveau, type, nombre de questions ; « Ta progression » (meilleure note, maîtrise, badge, sessions) ; « Commencer l'exercice », « Reprendre » et « Recommencer », ou « Refaire l'exercice » ; aperçu des questions sans la bonne réponse, 3 puis « Voir plus ».
- **Séance** : « Quitter la session », barre de progression, une question à la fois (Vrai / Faux, choix unique, 2 ou 3 propositions correctes), « Valider » ; puis « Bonne réponse » ou « Mauvaise réponse », « Ton choix », « Explication », « Question suivante » ou « Voir mon résultat ». La bonne réponse n'est jamais montrée.
- **Résultat** : badge, « Félicitations ! » ou « Courage ! », note /20, maîtrise, phrase de progrès, « Recommencer » (caché à 100 %), « Revoir l'exercice », correction question par question.

## Maquettes

Toile : https://claude.ai/artifact/NTPyZWmFK4oK9z9jMgvWL5 (téléphone d'abord).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelle page élève après Ma classe ? | Le parcours d'un exercice ; restent la révision, le profil, l'historique, le choix de classe, la connexion et l'inscription (porteur, 2026-10-15). | Un chantier par parcours ; celui-ci couvre les trois écrans de l'exercice. |

## Questions ouvertes

1. En séance, retire-t-on l'en-tête de l'application (mode concentré : une croix pour quitter, la barre de progression en haut) ?
2. Quitter la séance : demande-t-on confirmation (« Ta progression est gardée ») ?
3. Sur le résultat, quand toutes les réponses sont justes : « Recommencer » disparaît, comme aujourd'hui ?
