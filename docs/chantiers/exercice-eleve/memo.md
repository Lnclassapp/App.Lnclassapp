# Memo — Parcours d'exercice de l'élève aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré, en revue |
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
| En séance, retire-t-on l'en-tête de l'application (mode concentré) ? | Oui (porteur, 2026-10-15). | Pendant les questions et les retours : ni en-tête, ni menu de gauche, ni menu de l'avatar ; une croix « Quitter la session », la barre de progression et « 3/5 » en haut ; le bouton d'action reste collé en bas. |
| Quitter la séance demande-t-il confirmation ? | Oui (porteur, 2026-10-15). | Une feuille en bas de l'écran : « Quitter la séance ? », « Ta progression est gardée. Tu pourras reprendre à la question N. », « Continuer l'exercice » (principal) et « Quitter ». La session reste ouverte, comme aujourd'hui. |
| À 20/20, « Recommencer » disparaît-il du résultat ? | Oui, comme aujourd'hui (porteur, 2026-10-15). | Seul « Revoir l'exercice » reste. |
| Que change la tablette ? | Passons à la tablette (porteur, 2026-10-15). | Page de l'exercice et résultat centrés (720 px au plus), « Ta progression » sur une ligne de quatre cases ; en séance, la question et les réponses sur 640 px au centre, la barre de progression sur toute la largeur ; la confirmation pour quitter devient une fenêtre au centre. |
| Que change l'ordinateur ? | Passons à l'ordinateur (porteur, 2026-10-15). | À partir de 1024 px : menu à gauche ; page de l'exercice sur deux colonnes (présentation et progression à gauche, aperçu des questions à droite) ; résultat sur deux colonnes (note et boutons à gauche, correction à droite) ; la séance garde le mode concentré, au centre. |
| Quels types de questions ajouter ? | Les quatre proposés : texte à trous, réponse en nombre, remettre dans l'ordre, relier (porteur, 2026-10-15). | **Texte à trous** : un champ dans la phrase. **Réponse en nombre** : un grand champ, clavier numérique, bouton ± (le clavier Android n'a pas toujours le signe moins), virgule acceptée. **Remettre dans l'ordre** : flèches monter / descendre sur chaque étape (pas de glisser-déposer, plus fiable au doigt et au lecteur d'écran). **Relier** : toucher un élément à gauche puis à droite ; un numéro relie les deux. Après la réponse, « Ton choix » montre la réponse de l'élève, jamais la bonne. C'est le plus gros chantier : le moteur (entités, notation, saisie des enseignants, import) ne connaît aujourd'hui que Vrai / Faux et les choix ; à découper en lots, un type par lot. |

## Questions fermées (porteur, 2026-10-15)

1. **Texte à trous** : juste sans tenir compte des majuscules, des accents ni des espaces en trop ; l'enseignant peut saisir plusieurs réponses justes ; une faute de frappe est fausse.
2. **Réponse en nombre** : marge facultative fixée par l'enseignant pour chaque question, sinon la valeur exacte ; « 3,5 » et « 3.5 » valent pareil.
3. **Remettre dans l'ordre et relier** : tout juste ou faux, sans points partiels ; le calcul de la note ne change pas.

Suite : PRD, ADR-0091, UDR-0087 et plan de lots écrits le 2026-10-15 ; le code se fait dans une PR, après celle d'`accueil-eleve`.
