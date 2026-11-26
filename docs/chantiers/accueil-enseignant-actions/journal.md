# Journal — Accueil enseignant tourné vers l'action

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-26 | Le code de la classe revient dans « Inscrire vos élèves » | Il n'était plus que sur la carte du carrousel, que le chantier retire | non (UDR §3.5) |
| 2026-11-26 | Liste des élèves : 10 par page au lieu de 30 | « Voir plus (n) au-delà de quelques lignes » (porteur) ; le mécanisme de pagination d'ADR-0097 §4.7 ne change pas | non |
| 2026-11-26 | « Mon compte » en page reçoit « ‹ Accueil » ; les modales servies en page (matières, jours de séance) n'en reçoivent pas | Elles ont « Annuler » ; un retour en plus ferait deux sorties | non (UDR §3.4) |
| 2026-11-26 | « Personne n'a fait le devoir » : le bouton de relance est l'action de l'état vide | Pas de « Prochain geste » dans cet état ; c'est pourtant là qu'il y a le plus à relancer | non |

## À trancher

- [x] 2026-11-26 · accueil-enseignant-actions · Garder la barre latérale de l'enseignant sur ordinateur hors accueil ? — appliqué : gardée ; autres : la retirer aussi (retour par « ‹ Accueil » seulement) ; recommandé : gardée — tranché par le porteur : recommandé gardé
- [x] 2026-11-26 · accueil-enseignant-actions · « Voir mes N autres classes » : où ? « Mes classes » est une page de déclaration sans lien vers chaque classe — appliqué : les autres classes se déplient sur l'accueil (même ligne) ; autres : rendre « Mes classes » navigable et y mener ; recommandé : déplier sur l'accueil — tranché par le porteur : recommandé gardé
- [x] 2026-11-26 · accueil-enseignant-actions · Ligne d'élève « nom et état » : garder la photo (ou les initiales) avant le nom ? — appliqué : gardée (repère visuel, même lien) ; autres : nom seul ; recommandé : gardée — tranché par le porteur : recommandé gardé
- [x] 2026-11-26 · accueil-enseignant-actions · Sans barre du haut hors accueil, « Mon compte » et « Besoin d'aide ? » ne sont plus qu'à l'accueil (site) — appliqué : accepté tel quel ; autres : rendre le bloc de profil de la barre latérale cliquable vers « Mon compte » ; recommandé : tel quel pour le pilote — tranché par le porteur : recommandé gardé

## Retouches

- …

## Ce qui a dérapé

- Huit tests (contrôleur et système) lisaient la barre du haut ou son panneau sur une page intérieure : réécrits pour l'accueil ou le retour.
- `script/docs/build_index` échoue sous une locale US-ASCII : `LANG=C.UTF-8` dans le conteneur.
- Ruby 3.4.13 absent du conteneur : compilé avec ruby-build (définition ajoutée à la main), environ 6 minutes.

## Ce qu'on a appris sur la codebase

- La page « Mes classes » (`teacher_classrooms`) ne mène à aucune classe : jusqu'ici, seul le carrousel de l'accueil ouvrait une classe.
- L'en-tête du shell a déjà une règle « page à bandeau » (`content_for :home_band`) : c'est la clé de l'accueil.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | aucun |
| **UDR produits** | UDR-XXXX-accueil-enseignant-actions |
