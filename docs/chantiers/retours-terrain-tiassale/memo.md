# Memo — Retours de terrain de Tiassalé (programme)

| | |
|---|---|
| **Type de cycle** | programme (3 chantiers feature + un guide) |
| **Statut** | cadré, chantiers lancés |
| **Ouvert le** | 2026-11-20 |
| **Branche** | `claude/keen-keller-127bnu` (cadrage, docs seules) |
| **Programme** | — |

---

## Ce qu'on a vu

Visite du porteur au collège Notre-Dame de la Paix de Tiassalé, 2026-11-20, élèves inscrits en classe sur téléphone :

1. **Des élèves s'inscrivent comme enseignant.** L'accueil montre « Je suis élève » et « Enseignant(e) » côte à côte ; certains prennent le second.
2. **Des élèves cliquent sur « Se connecter » sans avoir de compte.** La modale de rôle propose « Se connecter » en premier, puis « Créer mon compte ».
3. **La DRENA et l'établissement se choisissent mal.** Deux listes natives (41 DRENA, puis des centaines d'écoles), sans recherche : erreurs de sélection.
4. **Le partage entre élèves et enseignants n'est pas structuré** : il manque le geste qui fait venir le voisin de table, et la mesure du k-factor par classe.
5. **Pas de playbook** pour lancer Lnclass dans une nouvelle ville.

## Décisions du porteur (2026-11-20)

| # | Point | Décision |
|---|---|---|
| D1 | Élève inscrit comme enseignant | **Confirmation seulement** : l'accueil ne change pas ; l'inscription enseignant demande d'abord « Êtes-vous bien enseignant ? », avec la sortie « Non, je suis élève » vers l'inscription élève. |
| D2 | « Se connecter » sans compte | **Entrée élève unique** : un clic sur « Je suis élève » montre numéro + code secret. Si le numéro a un compte, l'élève est connecté ; sinon, il **continue la création de son compte** (numéro et code déjà saisis). Le processus d'inscription élève est mis à jour en conséquence. |
| D3 | DRENA et établissement | **Une seule recherche** : un champ « Ton établissement » qui cherche dans les 3 851 écoles en tapant quelques lettres et affiche la DRENA à côté. La DRENA n'est plus une étape séparée. |
| D4 | Partage, k-factor | Les quatre : **QR code de classe**, **l'élève invite sa classe** (WhatsApp, lien de la classe), **mesure du k-factor** (qui a fait venir qui, par classe et établissement, vu par l'équipe), **kit d'affiche école** (A4 imprimable, QR + 3 étapes). |
| D5 | Playbook ville | Guide écrit : [`docs/guide/playbook-lancement-ville.md`](../../guide/playbook-lancement-ville.md). |

## Découpage

| Chantier | Couvre | Dépend de |
|---|---|---|
| `entree-eleve-unifiee` | D2, D1 | — |
| `recherche-etablissement` | D3 (élève, enseignant, direction : le même composant) | — ; se raccorde à l'inscription élève de `entree-eleve-unifiee` (fichiers voisins : fusionner l'un après l'autre) |
| `partage-classe-k-factor` | D4 | — (s'appuie sur le lien de classe `/c/<jeton>` et `croissance-parrainage`) |
| guide | D5 | — |

## Points de vigilance (pour les chantiers)

- **D2 révèle si un numéro a un compte** (un code faux sur un numéro inscrit ≠ un numéro inconnu). Décision du porteur assumée ; le chantier l'écrit dans une ADR, garde le débit limité de la connexion (ADR-0050) et ne crée jamais un compte sur un numéro déjà inscrit. Un numéro inscrit avec un autre rôle (enseignant, direction) se connecte normalement.
- **D2 et le wifi de classe** : 40 élèves sur une même adresse ; les limites de débit de l'entrée unique suivent le correctif `inscription-classe-meme-wifi`.
- **D3** : la recherche ne renvoie que des établissements actifs, côté serveur, bornée (20 résultats), tolérante aux accents et aux mots dans le désordre (« ND paix tiassale »), et garde un repli sans JavaScript.
- **D4** : l'attribution (qui a invité) ne donne aucun droit et n'expose aucune donnée d'élève à un autre élève ; le QR porte le lien de classe existant, jamais un secret supplémentaire.
