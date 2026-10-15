# Journal — Connexion et inscription de l'élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Pas d'ADR | Interface seule : ni route, ni paramètre, ni règle d'identité nouvelle | Non |
| 2026-10-15 | `_class_picker` n'appartient pas à ce chantier ; codée avant, l'inscription garde l'ancienne cascade dans la nouvelle carte | Partagé avec « Choisis ta classe », redessiné par `choix-classe-eleve` ; confirmé par le porteur | Non |
| 2026-10-15 | Les deux pages basculent en deux colonnes à 1 024 px | La connexion basculait à `lg`, l'inscription à `md` | UDR-0088 §3.1 |
| 2026-10-15 | Lot 0 : `_auth_welcome` prend `variant: :card` ou `:panel` ; le panneau est collant (`lg:sticky lg:h-dvh`) | Sur l'inscription, longue, l'accueil reste visible pendant le défilement | Non |
| 2026-10-15 | Lot 0 : texte en `text-white` sur le dégradé `from-brand-strong from-60% to-brand`, logo sur une tuile `bg-white` | Même recette que la carte « Ma classe » (UDR-0084 §3.5) : AA dans les deux thèmes, car `white` et `brand-strong` s'inversent en sombre | Non |
| 2026-10-15 | Lot 0 : « Besoin d'aide ? » toujours rendu, y compris dans l'app Android | La barre native ne porte l'aide qu'après la connexion (pont `bridge--account`, rendu par le shell seulement) ; la règle de l'UDR-0080 ne s'applique donc pas à ces deux pages | Non |
| 2026-10-15 | Lot 0 : les clés `logo_home` des deux pages restent jusqu'aux lots A et B | Les vues actuelles les lisent encore ; chaque commit garde l'app debout | Non |
| 2026-10-15 | Lot A : le logo est dans la carte bleue (PRD CA-1, UDR §3.1), pas dans une barre « logo + Lnclass » comme sur la maquette ; la barre du haut ne porte que « Besoin d'aide ? » | Le PRD et l'UDR font autorité sur la maquette | Non |
| 2026-10-15 | Lot A : `sign_in_test` attendait « pas de 4 chiffres » à 390 px ; la page garde « code secret à 4 chiffres » sous le code (maquette, UDR §3.3 « inchangés ») : l'assertion devient `assert_text` | Échec déjà présent sur la base, fixé par le texte de cette page | Non |
| 2026-10-15 | Lot B : la pastille du genre choisie est en `bg-brand-strong text-white`, pas en `bg-brand text-white` (UDR §3.4) | Blanc sur `brand` fait 2,9:1 en clair et ~3:1 en sombre : l'UDR §3.7 exige AA ; `brand-strong` est aussi la couleur des pastilles de niveau (UDR-0091) | UDR-0088 §3.4 amendée |
| 2026-10-15 | Lot B : « Créer ton compte élève » devient le `h1` ; « Bienvenue sur Lnclass » passe en `p` dans l'accueil bleu | Comme la connexion (titre de la carte en `h1`) et la maquette ; un seul `h1` visible à toute largeur | Non |
| 2026-10-15 | Lot B : la cascade garde ses étapes numérotées 1-2-3 dans la rubrique 1 | `_class_picker` appartient à `choix-classe-eleve` (UDR §3.5) ; la double numérotation est soumise au porteur | Non |
| 2026-10-15 | Lot A : la page n'a pas de `main#main` | `sign_in_test` repère l'arrivée dans le shell par `main#main` ; l'avoir sur la connexion ferait passer ce repère trop tôt | Non |

## Ce qui a dérapé

- Lot C : à 390 px, la grille d'une colonne (`grid` sans gabarit) prenait la largeur minimale de son contenu ; `grid-cols-1` la rend rétrécissable. Vu sur les captures, pas par les tests.
- Le test système de CA-6 et CA-7 a été écrit avant la vue mais lancé après elle ; les tests de contrôleur des mêmes critères ont été vus rouges.

## Écarts avec les maquettes et l'UDR

| Écart | Où | Raison |
|---|---|---|
| Le logo est dans la carte bleue, pas dans une barre « logo + Lnclass » en haut à gauche | Connexion, inscription, < 1 024 px | PRD CA-1 et UDR §3.1 |
| Pastille du genre choisie en `brand-strong`, pas en `brand` | Inscription | AA (UDR §3.7) ; UDR-0088 §3.4 amendée |
| L'info du code secret reste sous le champ (`ui_info_tip`), pas à côté du libellé | Connexion | Composant partagé inchangé |
| Pas de barre de logo, donc la barre du haut ne porte que « Besoin d'aide ? » | Les deux pages | Conséquence du premier écart |
| La cascade garde ses étapes numérotées 1-2-3 dans la rubrique « 1. Ta classe » ; les cases de classe passent sur deux lignes à 1 280 px (« 6ème / 1 ») | Inscription | `_class_picker` appartient à `choix-classe-eleve` (UDR §3.5) |
| En sombre, l'accueil bleu devient bleu clair avec un texte foncé | Les deux pages | Tokens seuls : `brand-strong` et `white` s'inversent, comme la carte « Ma classe » |
| La feuille d'aide s'intitule « Contacte-nous » (tutoiement) sur la connexion, qui vouvoie | Connexion | `shared/_help_sheet` est partagé, hors périmètre |

## Ce qu'on a appris sur la codebase

- La connexion et l'inscription n'utilisent pas le shell : pas d'en-tête, donc « Besoin d'aide ? » doit être rendu par la page.
- Le test système de l'inscription élève est `test/system/classroom/join_test.rb`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| « Code secret oublié ? » et inscriptions enseignant et direction au même style | Hors périmètre | — |
| Titre de la feuille d'aide au « vous » sur la connexion (« Contactez-nous ») | `shared/_help_sheet` partagé avec les écrans élève | À décider par le porteur |
| Double numérotation (rubrique 1, étapes 1-2-3 de la cascade) et cases de classe trop étroites à 560 px | `_class_picker` du chantier `choix-classe-eleve` | À décider par le porteur |
| Après un échec, le focus va sur le numéro (comportement actuel), le PRD §3 parle du code ; verrouillé par `sign_in_test` (« a wrong PIN… ») jusqu'à la décision | Comportement inchangé exprès (CA-9) | À décider par le porteur |
| Dans Lnclass Teacher, la connexion montre aussi « Créer mon compte élève » (verrouillé en contrôleur, avec « Besoin d'aide ? », dans les deux coques) | L'élève qui s'inscrit là serait ensuite refusé par `:wrong_app` | Le porteur doit confirmer ce lien dans Lnclass Teacher |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-15 |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | UDR-0088 (acceptée, §3.4 amendée) |
| **bin/ci** | Lancé par groupes le 2026-10-15 (`CI_GROUP`, la suite entière dépasse 10 min d'un seul tenant). Vert : unit (couverture 100 %), sécurité, seeds, perf, assets, système 1/4 et 2/4. Rouge, déjà rouge sur la base : garde du budget système (+23,8 s, dont +2,0 s de ce chantier, le reste d'`accueil-eleve` et `choix-classe-eleve` non fusionnés) ; format du numéro « 01 00 00 00 09 » dans `public_pages_test` (FU-30, FU-32), `staff_invitation_test`, `team_invitation_test` |
