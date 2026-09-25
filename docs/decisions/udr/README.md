# Registre des décisions d'interface (UDR) — Lnclass

Une **UDR** (*UI Decision Record*) consigne une décision d'expérience ou d'interface. Ce n'est pas un compte-rendu de design : c'est une **consigne exécutable**. Un agent doit pouvoir écrire la vue à partir de la seule section « Règles d'implémentation », sans poser de question.

Le format de référence est [`TEMPLATE.md`](./TEMPLATE.md). Les décisions d'**architecture** vivent dans [`../adr/`](../adr/README.md).

---

## Index des UDR

| N° | Titre | Statut | Date | ADR lié | Problématique |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [0001](./0001-design-visuel-du-catalogue-pedagogique.md) | Design visuel du catalogue pédagogique | Accepté · Tokens remplacés par 0005 | — | [0022](../adr/0022-modelisation-hexagonale-du-catalogue-pedagogique.md) | Le catalogue affichait trop d'informations d'un coup (essentiels sur la carte de cours) : définir une direction « Étude Premium » et une carte-vitrine épurée. |
| [0002](./0002-ui-ux-de-l-organisation-scolaire.md) | UI/UX de l'organisation scolaire | Accepté · Tokens remplacés par 0005 | — | [0023](../adr/0023-modelisation-de-l-organisation-scolaire.md) | Rendre l'espace écoles / DRENA / classes clair et hiérarchique plutôt qu'administratif : cartes d'école, badges de statut, édition en page dédiée ou slide-over. |
| [0003](./0003-moteur-evaluation-et-gamification.md) | Moteur d'évaluation & gamification (Assessment UI) | Accepté · Tokens remplacés par 0005 | — | [0008](../adr/0008-moteur-evaluation-et-gamification.md) | Offrir une expérience d'exercice immersive sans rechargement (Turbo Frames), centrée sur la progression visible et la récompense (badges Argent, Or, Diamant). |
| [0004](./0004-identite-et-profils.md) | Identité et profils (Identity UI) | Accepté · non applicable (0005) | — | [0021](../adr/0021-gestion-de-l-identite.md) | Garantir zéro régression d'interface pour les 5 rôles pendant le refactoring du module Identity côté backend. |
| [0005](./0005-design-system-fondateur.md) | Design system fondateur | Accepté | 2026-09-25 | [0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md), [0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) | Trois sources de style contradictoires et aucune valeur interdite : une palette `@theme` seule issue de la landing, des échelles, treize composants, pas de mode sombre, heroicons vendorés, un test qui refuse `[…]` et `#hex`. Remplace les sections « Tokens » des UDR-0001/0002/0003 ; UDR-0004 non applicable. |
| [0006](./0006-shell-applicatif-par-role.md) | Shell applicatif par rôle | Accepté | 2026-09-25 | [0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) | 4 × 4 partials de navigation divergents et des destinations cachées sur mobile : un shell unique paramétré par le rôle, la même liste en bureau et en mobile, un accueil par rôle, des toasts dont le message survit au Turbo Stream, et des CRUD entièrement Hotwire (modale dans un frame, 422, Turbo Stream). |
| [0007](./0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) | Vocabulaire de la fiche essentielle et de l'évaluation | Accepté | 2026-09-25 | — | remplace le vocabulaire des UDR-0001 et 0003 |

---

## Conventions de nommage

- Un fichier par décision : **`NNNN-titre-en-kebab-case.md`**.
- **4 chiffres**, séquentiel, **jamais réutilisé**.
- Pas d'accent, pas de majuscule, pas de `_` dans le nom de fichier.
- Le numéro dans le nom de fichier, le numéro du titre `# UDR-NNNN : …` et la ligne d'index doivent toujours coïncider.

## Ajouter une UDR

1. Relever le dernier numéro pris : `ls docs/decisions/udr/ | tail -3`.
2. Copier [`TEMPLATE.md`](./TEMPLATE.md) vers `NNNN-titre-en-kebab-case.md` et remplir le bloc de métadonnées (Statut, Date, Chantier, ADR lié, Remplacé par).
3. Décrire la **friction utilisateur** en section 1 : qui la subit, à quel moment, et ce qu'elle coûte.
4. Écrire la section **Règles d'implémentation** comme un contrat : composant de référence, tokens (jamais de valeur en dur), comportement Turbo/Stimulus, **états obligatoires** (vide, chargement, erreur, succès) et accessibilité (cibles ≥ 48×48 px, contraste, focus, `aria-*`).
5. Renseigner les **conséquences** : ce que la décision impose au reste de l'interface, et ce qu'elle interdit désormais.
6. Ajouter la ligne correspondante dans le tableau d'index ci-dessus.
7. **Si l'UDR en remplace une précédente** : renseigner `Remplacé par : UDR-NNNN` dans l'ancienne et ajouter un encadré d'avertissement en tête. Une UDR périmée n'est jamais supprimée : elle est marquée.

## Champs inconnus

Quand une information est introuvable dans l'historique, écrire `—` ou `*(non documenté)*`. Ne jamais reconstituer une règle d'interface de mémoire : une UDR est appliquée littéralement par un agent.
