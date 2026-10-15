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

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- La connexion et l'inscription n'utilisent pas le shell : pas d'en-tête, donc « Besoin d'aide ? » doit être rendu par la page.
- Le test système de l'inscription élève est `test/system/classroom/join_test.rb`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| « Code secret oublié ? » et inscriptions enseignant et direction au même style | Hors périmètre | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | UDR-0088 |
