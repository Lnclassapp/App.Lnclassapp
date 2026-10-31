# Memo — Sujets de devoir Thalès, titres numérotés des feuilles, correction en bloc

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/sujets-thales-feuilles` |
| **Programme** | — |

---

## Le problème

Les feuilles « Prépare devoirs » (chantier `prepare-interros-cahier`) sont en place sur `Develop` et `Staging`, mais aucun sujet de devoir n'existe dans les données : la section reste vide. Touré veut, pour la leçon « Propriétés de Thalès dans un triangle » (3ème), quatre sujets à la manière de sa maquette, figures comprises.

Deux écarts d'interface avec la maquette, relevés par Touré le 2026-10-31 :

- le titre d'une feuille est le nom de la notion ou le titre du sujet ; Touré veut « Prépare interros n°1 », « n°2 »… et « Prépare devoirs n°1 », « n°2 »… ;
- la correction s'affiche sous chaque question ; Touré la veut en un bloc par exercice (« a. … b. … c. … »), comme la maquette.

## Pour qui

L'élève de 3ème qui prépare un devoir sur Thalès ; l'enseignant qui envoie un sujet à sa classe ; l'équipe Contenu qui importe les sujets.

## Pourquoi maintenant

La fonctionnalité est livrée sans contenu : sans sujet, « Prépare devoirs » ne se montre pas. Touré veut la tester sur `Develop` et `Staging` aujourd'hui.

## Hors périmètre

- La production : l'import y sera fait plus tard (décision de Touré, 2026-10-31).
- Les sujets des autres leçons.
- L'import lui-même sur `Develop` et `Staging` : il se fait depuis l'écran Imports, avec un compte de l'équipe (Kamkara).

## Ce que le cadrage a révélé

| Question | Réponse (Touré, 2026-10-31) | Conséquence sur le chantier |
|---|---|---|
| Combien de sujets ? | Quatre (la maquette en a trois) | Un quatrième sujet est rédigé dans le style de la maquette, calculs revérifiés |
| Les figures de la maquette ? | Oui, les ajouter | Figures « triangle ABC, M sur [AB], N sur [AC] » et « papillon » ajoutées à la leçon |
| Où écrire « Prépare interros n°1 » ? | Titre de chaque feuille | Changement d'écran pour toutes les leçons : amendement de UDR-0149 |
| Correction en bloc ? | Un bloc sous l'exercice | Changement d'écran pour toutes les leçons : amendement de UDR-0149 |
| Combien d'exercices par feuille ? | Pas de limite, « laisse comme ça » | Rien |
