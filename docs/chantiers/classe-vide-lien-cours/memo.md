# Memo — Classe sans exercice : « ci-dessous » ne montre rien

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-29 |
| **Branche** | `fix/classe-vide-lien-cours` |
| **Programme** | — |

---

## Symptôme

Page d'une classe sans exercice assigné : l'état vide dit « Ouvrez une fiche de cours ci-dessous pour assigner un exercice à cette classe. » Sous ce bloc, il n'y a aucun cours : le bloc « Cours » de la page (UDR-0062) a été retiré par UDR-0134. L'enseignant ne sait pas où aller, et la page ne propose aucun lien.

Attendu : l'état vide dit où trouver les cours et y mène.

## Reproduction

- **Acteur** : enseignant d'une classe sans assignation active (Develop, « 3ème 1 » avant l'assignation des exercices).
- **Étapes** : Classes → la classe → bloc « Exercices assignés » : texte « ci-dessous », rien dessous qui y réponde.

## Portée

- Toute classe sans exercice assigné, vue par son enseignant (premier parcours : c'est le premier écran de la classe). Aucune donnée touchée.

## Correctif retenu

- Description : « Ouvrez une fiche de cours dans « Cours » pour assigner un exercice à cette classe. »
- Bouton « Voir les cours » (`secondary`, icône `book-open`) vers `courses_path`, seulement pour l'enseignant (celui qui assigne). Les autres rôles gardent le texte sans bouton.
- UDR-0062 (bloc « Exercices assignés », ligne « Vide ») amendée.

## Hors périmètre

- Le reste de la page de la classe.

## Portes de sortie

- [x] Test rouge puis vert (texte, bouton pour l'enseignant, pas de bouton pour un autre rôle)
- [x] UDR-0062 amendée
- [ ] Captures 390 px et ordinateur envoyées au porteur
- [ ] `bin/ci-quiet` vert, ligne de preuve dans la PR
