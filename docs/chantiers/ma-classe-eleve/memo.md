# Memo — Page Ma classe de l'élève aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (code sur `feature/ma-classe-eleve`, PR à ouvrir après `accueil-eleve`) |
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
| Montre-t-on les enseignants de la classe ? | Oui, puis sur relecture : non, on retire la liste (porteur, 2026-10-15). | Pas de bloc enseignants. Seule une classe sans enseignant sur Lnclass montre une carte « Aucun enseignant sur Lnclass pour l'instant » avec « Inviter mon enseignant », le même parcours que sur l'accueil. |
| Montre-t-on le nombre d'élèves ? | Non (porteur, 2026-10-15). | Ni nombre ni liste des élèves sur Ma classe. |
| « Exercices assignés » répète « À faire » de l'accueil : on garde les deux ? | Oui (porteur, 2026-10-15). | Les deux listes restent, avec les mêmes échéances et le même ordre. |
| « Inviter mon enseignant » ajoute une action à une page qui n'en a pas (UDR-0057 R1) : on modifie la règle ? | Oui (porteur, 2026-10-15). | L'UDR du chantier amende UDR-0057 R1 : Ma classe a une seule action, « Inviter mon enseignant », et seulement quand la classe n'a aucun enseignant sur Lnclass. |
| Que change la tablette ? | Passons à la tablette (porteur, 2026-10-15). | À partir de 700 px, la page se centre (720 px au plus) ; le bandeau des cours montre deux cartes et demie ; les listes restent sur une colonne ; « Besoin d'aide ? » en entier dans l'en-tête. |
| Que change l'ordinateur ? | Passons à l'ordinateur (porteur, 2026-10-15). | À partir de 1024 px (ordinateur et tablette à l'horizontale) : menu à gauche avec « Ma classe » actif, quatre cartes de cours visibles dans le bandeau, « Exercices assignés » et « Exercices traités » côte à côte. |

## Questions ouvertes

Aucune. PRD, UDR-0086 et plan de lots écrits le 2026-10-15 (pas d’ADR) ; le code se fait dans une PR, après celle d’`accueil-eleve`.
