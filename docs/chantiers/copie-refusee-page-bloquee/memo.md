# Memo — Copie refusée : la page ne répond plus

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré, clos |
| **Ouvert le** | 2026-10-29 |
| **Branche** | `fix/copie-refusee-page-bloquee` |
| **Programme** | — |

---

## Symptôme

L'élève touche « Vérifier ma copie », confirme « Vérifier quand même », et la copie est refusée (« Question 4 : Coche le nombre de propositions demandé… »). Ensuite **plus aucun toucher ne répond** : il ne peut ni cocher ni décocher, ni rendre sa copie. Seul un rechargement de la page débloque. Le compteur affiche aussi « 0/5 répondues » alors que ses réponses sont cochées.

Attendu (UDR-0138 §3.3, lignes « Réponse illisible » et « Erreur ») : la copie se rouvre avec ses valeurs, le résumé `#copy-errors` prend le focus, l'élève corrige et rend ; « compteur juste ».

## Reproduction

- **Acteur** : élève de 3ème inscrit dans une classe, exercice assigné avec une question à cases multiples (Develop, élève simulé n° 4, session `TFiLPPDWQAHGYo`).
- **Étapes** :
  1. Ouvrir la copie, répondre à toutes les questions mais ne cocher qu'**une** case à la question qui en demande deux.
  2. « Vérifier ma copie » puis, si la confirmation s'ouvre, « Vérifier quand même ».
  3. Le serveur répond 422, la copie revient avec le message.
  4. Toucher une autre réponse : rien ne se passe (« <html> intercepts pointer events »). `#copy-confirm` : `open=false`, `:modal=true`. Compteur « 0/5 ».
- Reproduit **à la main sur Develop** (Playwright, 390 px) et **en local** (test système jetable, même état).
- Tout refus 422 passé par la confirmation déclenche le bug, pas seulement le nombre de cases.

## Portée

- Depuis l'arrivée de la copie d'un seul envoi (UDR-0138, ADR-0112) : tout élève dont la copie est refusée après la confirmation.
- Pas de données corrompues : rien n'est écrit sur un 422. Un élève bloqué peut recharger (le brouillon `localStorage` restaure ses réponses). Contournement existant → bugfix, pas hotfix.
- Multi-appartenance : sans objet (comportement purement navigateur, indépendant de la classe).
- Autres acteurs : toute boîte `ui_modal` ouverte au moment d'un re-rendu Turbo par morphing peut rester bloquée de la même façon (voir journal).

## Hors périmètre

- Les autres constats de la simulation des 45 élèves (limite d'inscriptions, badge élève/enseignant, % contre /20, message « Bien » + consolation, 502 sous charge) : chantiers séparés.
- Pas de changement de libellé ni de parcours : pas d'UDR.

## Portes de sortie (lot unique)

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [x] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
