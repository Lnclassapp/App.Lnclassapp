# Memo — Actions d'un objet dans un menu ⋮

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/actions-en-menu` |
| **Programme** | — |

---

## Le problème

Les écrans de l'équipe affichent les gestes qui modifient un objet sous forme de boutons en ligne : « Modifier », « Désactiver », « Supprimer » sur chaque ligne des DRENA, établissements, séries, niveaux et matières, et « Modifier » seul dans l'en-tête d'une fiche essentielle ou d'un exercice. Trois boutons par ligne élargissent la dernière colonne ; « Supprimer » est posé à côté de « Modifier », à portée d'un clic distrait ; et chaque écran range ses actions à sa manière (texte, icône seule à libellé caché, bouton secondaire ou fantôme), alors que la page d'un cours regroupe déjà les siennes dans un menu ⋮.

Le porteur, le 2026-09-28 : « j'aime avoir les actions suppressions, modifications dans un dropdown avec ellipsis-vertical ». Élargi le même jour : les pages qui n'ont qu'un seul bouton « Modifier » passent aussi dans le menu.

## Pour qui

L'équipe (Team), qui administre le référentiel (DRENA, établissements, séries, niveaux, matières) et le contenu (fiches essentielles, exercices), au bureau surtout, parfois au téléphone.

## Pourquoi maintenant

Décision du porteur du 2026-09-28, avant la mise en production de la V1 : les écrans d'administration doivent parler un seul langage. Plus on attend, plus il y a d'écrans à reprendre.

## Hors périmètre

- La page « Mon profil » : chaque bouton y modifie un champ précis de la carte (un par ligne), ce n'est pas l'action d'un objet listé.
- L'accueil enseignant : « Modifier mes classes » est un lien de navigation vers un autre écran.
- Les bascules : matrice niveaux × séries, déclaration des classes de l'enseignant. Ce sont des états, pas des actions.
- Les gestes de création et d'import (« Nouvelle DRENA », « Nouvel exercice », « Importer des exercices »…) : ils restent des boutons visibles, ils ne portent sur aucun objet existant.
- Le panneau de statut du contenu (publier, archiver) : il reste visible, c'est l'état de l'objet.
- Le retrait d'une question dans le formulaire d'un exercice : c'est un champ du formulaire, pas un objet de la page.
- Toute nouvelle action (dupliquer, archiver une DRENA…) : on déplace les gestes existants, on n'en invente pas.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Un menu absolu, dans un tableau `overflow-x-auto`, n'est-il pas rogné par le défilement du tableau ? | Oui : `overflow-x: auto` force aussi le défilement vertical ; le menu de la dernière ligne serait coupé par le bas de la carte. | Le menu d'une ligne est en position fixe, calculée à l'ouverture, et suit le défilement (`ui_dropdown fixed: true`). |
| Au téléphone, le menu passe-t-il sous la barre de navigation basse (`z-40`) ? | Oui, avec le `z-30` des menus. | Un menu fixe est en `z-50`, au-dessus des barres du shell. |
| La confirmation « Supprimer » vit dans la ligne : si elle est ouverte depuis le menu, où revient le focus quand on l'annule ? | Le navigateur rend le focus à l'élément actif à l'ouverture de la `<dialog>` ; l'entrée du menu est alors cachée. | Le menu se ferme et rend le focus au bouton ⋮ **avant** `showModal()` : Échap ramène au ⋮. |
| « Modifier » charge sa modale dans le frame `modal` : le menu reste-t-il ouvert dessous ? | Oui, rien ne le fermait (même défaut sur la page d'un cours). | L'entrée `frame:` ferme le menu et rend le focus au ⋮ au clic. |
| Un établissement inactif : son menu montre-t-il « Désactiver » ? | Non, l'action n'existe pas pour lui. | L'entrée disparaît ; la place vide qui alignait les icônes (`w-15`) n'a plus lieu d'être. |
| Que devient le nom accessible « Modifier l'établissement X » ? | Il nommait l'objet sur un bouton isolé. Dans le menu, c'est le bouton ⋮ qui nomme l'objet (« Actions pour X ») et l'entrée garde son libellé visible. | Clé `actions` ajoutée, clés `edit_label` retirées. |

## Cas limites identifiés

- Menu de la dernière ligne d'un tableau court : il s'ouvre vers le haut s'il manque de place en bas, jamais hors de l'écran.
- Menu ouvert puis tableau défilé latéralement (téléphone) : le menu suit son bouton.
- Suppression refusée (DRENA ou établissement utilisé) : la confirmation se ferme, le toast donne la raison, la ligne reste avec son menu.
- Ligne remplacée par un Turbo Stream (renommage, désactivation) : le nouveau menu fonctionne sans rechargement.

## Questions encore ouvertes

- Aucune.
