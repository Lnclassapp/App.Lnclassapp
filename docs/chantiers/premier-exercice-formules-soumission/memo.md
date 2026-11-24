# Memo — Premier exercice : formules des listes et envoi de la copie

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré (PR prête) |
| **Ouvert le** | 2026-11-24 |
| **Branche** | `fix/premier-exercice-formules-soumission` |
| **Programme** | — |

---

## Symptôme

Signalement du porteur (2026-11-24), sur la copie du premier exercice de l'élève :

1. « Toutes les formules dans les listes ne fonctionnent pas. »
2. « On n'arrive pas à soumettre l'exercice. »

Vu : dans une question « choix dans une liste », le menu affiche `$e^{7}$`, `$\dfrac{1}{7}$`, `$\ln 7$` au lieu des formules. Attendu : des propositions lisibles, comme dans un choix unique (UDR-0140 §3, ADR-0051 : toute formule `$…$` de l'élève est rendue par KaTeX).

## Reproduction

- Acteur : élève, copie d'un exercice (`/sessions/:id`), atteinte par « Commencer » de la fenêtre « Ton premier exercice » ou depuis la leçon.
- Données : une question `select` dont une proposition contient `$…$`. 3 937 questions `select` dans `docs/contenus`, dont celles de *Fonction exponentielle népérienne* (Tle A2) : « Complète : $e^{x} = 7 \iff x =$ ___ ».
- Local : test système `test/system/assessment/formulas_in_lists_test.rb`, rouge avant le correctif (« found 1 match » au lieu de 4 formules rendues).
- Staging (élèves de recette `0100000166`, `0100000012`) : l'exercice proposé n'a que des choix et des nombres ; formules rendues, envoi accepté (303 → résultat). Staging n'a pas les leçons du manifeste, donc pas de question `select` en formule.

## Portée

- Depuis l'arrivée des questions « choix dans une liste » (UDR-0140) et des leçons de maths qui en mettent en formule.
- Tous les élèves, toutes classes et tous établissements (rendu pur, sans lecture d'appartenance) ; l'enseignant ne remplit pas de copie.
- Données : aucune donnée fausse en base. La valeur envoyée est l'indice d'affichage, inchangé ; les notes déjà données restent justes.

## Hors périmètre

- La fiche « Je m'entraîne » (`catalog/practice_checks/_question`) a le même menu natif : chantier de suivi (journal).
- Une formule coupée par une case à remplir (`$A_7^3 = ___$`, 115 questions `fill_blank`) reste en LaTeX brut : chantier de suivi (journal).
- Les listes de repli de « relier » et « remettre dans l'ordre » : cachées dès que JavaScript tourne, l'élève voit les cartes, déjà rendues.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel document dit que la formule doit être rendue ? | ADR-0051 (rendu KaTeX des formules), UDR-0140 §3 (`select` natif) | Bug : l'UDR n'avait pas prévu une proposition en formule |
| L'envoi échoue-t-il seul ? | Non : Staging et local acceptent la copie (choix, nombre, relier, ordre, trous, liste). Un nombre illisible est refusé avec un message, comme prévu | Le symptôme 2 découle du 1 : l'élève ne peut pas choisir une proposition illisible |
| Multi-appartenance ? | Rendu sans lecture de classe ni d'école | Sans objet |
| Données à réparer ? | Non | Pas de lot de réparation |

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit dans l'application avant toute ligne de code (Staging pour le parcours, local pour la question en formule)
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test (journal)
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause** (la vue qui met la formule dans une option)
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : une liste sans formule garde ses libellés dans le menu
- [x] Données déjà corrompues : aucune
- [x] Challenger a rejoué les étapes de reproduction dans l'application (captures 390 px et ordinateur)
- [x] Commit `fix(assessment): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
