# Memo — Connexion et inscription de l'élève aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR à ouvrir) |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `Develop` (cadrage, docs seules) ; le code passera par une PR |
| **Programme** | — |

---

## Le problème

La connexion (`identity/sessions#new`) et l'inscription élève (`classroom/student_registrations#new`) fonctionnent, mais elles ne ressemblent pas aux écrans élève redessinés (`accueil-eleve` … `choix-classe-eleve`).

## Pour qui

L'élève qui crée son compte ou revient, le plus souvent sur un téléphone Android d'entrée de gamme. La connexion sert aussi aux enseignants, à la direction et à l'équipe : son texte reste au « vous ».

## Hors périmètre

- Les règles d'identité et d'adhésion : numéro ivoirien à 10 chiffres, code secret à 4 chiffres, débit limité, refus selon l'app (ADR-0050, ADR-0084, ADR-0085, ADR-0086).
- « Code secret oublié ? » (sa propre page) et les inscriptions enseignant et direction.

## Point de départ : les pages actuelles

Relevées dans le code le 2026-10-15.

- **Connexion** (UDR-0054, UDR-0060, UDR-0082 §3.4) : deux colonnes dès 1024 px (panneau « Heureux de vous revoir » avec le logo) ; carte « Connexion » : numéro, code secret avec l'œil, l'info et l'aide « code secret à 4 chiffres », « Se connecter », « Code secret oublié ? » ; « Numéro ou code secret incorrect. » ; refus dans la mauvaise app.
- **Inscription** (UDR-0079, UDR-0081 §3.1, §3.2) : deux colonnes dès 768 px (« Bienvenue sur Lnclass » et son texte) ; « Créer ton compte élève », « Trois rubriques, une minute. » ; Ta classe (cascade partagée, ou bandeau du lien de la classe avec « Ce n'est pas ta classe ? ») ; Toi (nom, prénoms, genre, numéro) ; Code secret (code, confirmation, « Les codes concordent. ») ; « Créer mon compte » ; « Déjà un compte ? Se connecter ».

## Maquettes

Toile : https://claude.ai/artifact/Mk5fa5Wvh9jBgG9LDBH1eV (téléphone, tablette et ordinateur).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelle page après le choix de classe ? | La connexion et l'inscription, toutes les étapes d'un coup (porteur, 2026-10-15). | Carte bleue d'accueil au téléphone et panneau bleu à gauche dès 1024 px ; rubriques numérotées en cartes ; la cascade de « Choisis ta classe » (pastilles, cases) reprise telle quelle, comme décidé dans `choix-classe-eleve` ; genre en deux grandes pastilles ; « Besoin d'aide ? » en haut. |
| Ajoute-t-on « Pas encore de compte ? Créer mon compte élève » sur la connexion ? | Oui (porteur, 2026-10-15). | Un lien vers l'inscription élève en bas de la carte « Connexion », sous « Code secret oublié ? ». |
| Garde-t-on « Besoin d'aide ? » en haut de ces deux pages ? | Oui (porteur, 2026-10-15). | « Besoin d'aide ? » en haut à droite, comme sur les autres pages élève. |

## Tablette et ordinateur

- Tablette verticale (820 px) : une colonne ; la carte bleue prend la largeur du formulaire (440 px pour la connexion, 560 px pour l'inscription) ; classes sur une ligne de 4 cases.
- Dès 1024 px : panneau bleu à gauche (logo, accueil), formulaire à droite ; la connexion est centrée en hauteur.

## Suite

PRD, UDR-0088 et plan de lots écrits le 2026-10-15 (pas d’ADR). Le code se fait dans une PR, après celle d’`accueil-eleve` ; la cascade de classe vient de `choix-classe-eleve`.
