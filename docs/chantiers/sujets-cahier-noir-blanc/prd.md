# PRD — Les sujets d'interrogation en cahier noir et blanc

> Issue #390. Apparence seule : aucune règle métier, aucune donnée, aucune route ne change.

## 1. Contexte

Voir `memo.md`. Trois écrans montrent encore le bleu, le vert et le rouge de l'application : le sujet d'un exercice, la copie de
l'élève et le résultat corrigé. Ils passent sous la même feuille noir, blanc et gris que les feuilles de la leçon (UDR-0149).

> Décision du porteur (2026-11-05) : pas de maquette par sujet ; le tableau de l'issue et l'exemple Thalès sont un gabarit générique pour tous les sujets d'interrogation et de devoir, toutes matières.

## 2. Acteurs et permissions

| Acteur | Ce qu'il voit | Change ? |
|---|---|---|
| Élève | sujet, copie, résultat | apparence seule |
| Enseignant, équipe | sujet, résultat d'un élève | apparence seule |
| Parent, direction | — | non |

Aucune policy ne change.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre un exercice : la feuille porte un cartouche « INTERROGATION · Lnclass », le titre, la consigne (nombre de questions,
   barème quand les points diffèrent).
2. Il remplit sa copie sur la même feuille et clique « Vérifier ma copie ».
3. Le résultat : appréciation en titre, note sur 20, points, « À revoir », correction ; « Juste » et « Faux » écrits en toutes lettres.

### Chemins alternatifs et erreurs

- Copie invalide (422) : le résumé des erreurs et le message par question restent, en noir sur gris, avec leur icône.
- Pendant la pause : « Tu pourras recommencer à … » reste, en noir.

## 4. Critères d'acceptation

```gherkin
CA-1 Étant donné un élève sur le sujet d'un exercice, sa copie ou son résultat
     Alors la feuille porte la classe « exam-sheet » et la feuille de style « exam_sheet »
     Et la feuille est du papier cahier (#fbf6e9, lignes Seyès grises, marge grise), le même gabarit que « Prépare interros » et « Prépare devoirs »
     Et aucune couleur bleue, verte ou rouge n'y est calculée (test système : couleurs calculées de la feuille)

CA-2 Étant donné la fiche de révision
     Alors elle ne porte pas « exam-sheet » et garde ses couleurs

CA-3 Étant donné un résultat avec une question juste et une fausse
     Alors « Juste » et « Faux » sont écrits en toutes lettres

CA-4 Étant donné le sujet ou la copie
     Alors le cartouche dit « Interrogation » et la consigne dit le nombre de questions, sans durée ni « une seule tentative »

CA-5 Étant donné la copie
     Alors un seul bouton « Vérifier ma copie », précédé de « Une fois ta copie vérifiée, tu ne pourras plus changer tes réponses. »

CA-6 À 375 px, 768 px et 1280 px, aucune des trois pages ne défile horizontalement

CA-7 `exam_sheet.css` est la seule exception aux jetons ajoutée (design_tokens_test)
```

## 5. Modélisation préliminaire

Aucune. Une feuille de style isolée redéfinit, à l'intérieur du conteneur `.exam-sheet`, les variables de couleur, de rayon, d'ombre
et de police du design system : toutes les classes existantes (badges, boutons, cartes) passent en noir et blanc sans réécrire les
partiels. C'est le mécanisme déjà utilisé par les thèmes d'annonce.

## 6. Décisions rattachées

- ADR : aucun — ni port, ni table, ni contrat ; une feuille de style chargée par trois vues.
- UDR : `UDR-0157`.
- S'appuie sur UDR-0149 (feuilles noir et blanc), UDR-0140 (correction comme en classe), UDR-0154 (pleine largeur sur téléphone).

## 7. Mesures

Captures 390 px et ordinateur des trois écrans, envoyées au porteur.
