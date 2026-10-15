# Memo — Page Ma classe de l'élève aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `Develop` (cadrage, docs seules) ; le code passera par une PR |
| **Programme** | — |

---

## Le problème

La page « Ma classe » de l'élève (`classroom/student_classrooms#show`) fonctionne, mais elle ne ressemble pas encore à l'accueil et à la page Cours, redessinés aux couleurs de Wave et de Djamo (chantiers `accueil-eleve` et `cours-eleve`). C'est le troisième écran du menu élève.

## Pour qui

L'élève (Student), le plus souvent sur un téléphone Android d'entrée de gamme, parfois avec une connexion faible.

## Hors périmètre

- Les pages ouvertes depuis Ma classe (cours, exercice, résultat) : seul leur point d'entrée change.
- Le choix de classe (cascade `student_classroom_choices`) et l'élève sans classe, qui reste sur l'accueil.
- La liste des élèves de la classe : interdite (UDR-0011).

## Point de départ : la page actuelle

Relevée dans le code le 2026-10-15 (UDR-0011, UDR-0057, UDR-0062, UDR-0076 §3.2) : lien « Accueil », titre « Ma classe » ; carte de la classe (nom, niveau et série, établissement, année scolaire) ; « Cours assignés » (compteur, bandeau qui défile, « N exercices assignés ») ; « Exercices assignés » (par urgence, badge d'échéance) ; « Exercices traités » (meilleur score, Acquis / Fragile / En difficulté) ; 3 lignes puis « Voir plus » ; aucune action.

## Maquettes

Toile : https://claude.ai/artifact/5YCL2xGDiioqcrvEBr6W1B (téléphone d'abord).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Par quel écran commence-t-on ? | Le téléphone (porteur, 2026-10-15). | Même en-tête et même menu de l'avatar que l'accueil et Cours (« Ma classe » en surbrillance) ; carte de la classe en dégradé bleu comme sur l'accueil ; listes dans des cartes blanches ; échéances en orange (retard, aujourd'hui, demain), notes en vert à partir de 14/20. |

## Questions ouvertes

1. Montrer les enseignants de la classe (nom, matière) ?
2. Montrer le nombre d'élèves, comme sur l'accueil (« 32 élèves ») ?
3. « Exercices assignés » répète « À faire » de l'accueil : on garde les deux ?
