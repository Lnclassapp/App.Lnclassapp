# Memo — Une modale servie ouverte reste invisible sans JavaScript

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `fix/modales-sans-js` |
| **Programme** | `refonte-application` |

---

## Symptôme

Sans JavaScript, l'utilisateur qui suit « Modifier » sur « Mon profil » arrive sur `/profile/name/edit` et voit **une page blanche** sous l'en-tête : ni titre de modale, ni champ, ni bouton. Attendu : le formulaire « Modifier mon nom » visible et utilisable (le serveur sait déjà répondre sans Turbo, en 303 vers « Mon profil »).

## Reproduction

1. Navigateur avec JavaScript désactivé (ou requête sans JS : le HTML servi suffit).
2. Se connecter (élève 0100000001 / 2468 en développement), ouvrir `/profile`.
3. Suivre « Modifier » → `/profile/name/edit`.
4. Constaté : `<dialog id="profile-name-modal">` **sans attribut `open`** → rien d'affiché (capture `s7-nojs-edit.png` de la recette du chantier `profil-utilisateur`, 2026-09-28).

Environnement : tous. Reproduit aussi par le HTML brut : `curl` de la page montre le `<dialog>` sans `open`.

## Portée

- Depuis l'introduction de `ui_modal(open: true)` (UDR-0006, chantier `boucle-pedagogique`).
- Touche **toute modale servie ouverte** : nom, numéro, PIN du profil, code de récupération du PIN, édition des séries, et toute vue qui passe `open: true`.
- Aucun acteur n'est exclu : élève, enseignant, équipe, établissement.
- Aucune donnée corrompue : c'est un défaut d'affichage.

## Source du comportement attendu

- UDR-0041 §3 : « Repli HTML identique » — la page doit rester utilisable sans Turbo.
- Demande du porteur du 2026-09-28 : corriger maintenant.

## Hors périmètre

- Les modales **fermées** ouvertes par un bouton (`trigger:`) : sans JavaScript, le bouton ne fait rien ; c'est un choix d'interface (repli par lien), à traiter à part si besoin.
- Les boutons « Fermer » / « Annuler » (`type="button"`) restent inopérants sans JavaScript : le retour du navigateur ou l'envoi du formulaire suffisent.
- La fermeture de toutes les sessions au verrouillage : conservée telle quelle (décision du porteur, 2026-09-28).

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code (recette du 2026-09-28, capture `s7-nojs-edit.png`)
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
