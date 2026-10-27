# UDR-0137 : La fiche de cours reprend les maquettes à l'identique, dans un habillage à part
<!-- index
titre: Fiche de cours à l'identique des maquettes
statut: Proposé
adr-lie: ADR-0110
problematique: Les maquettes des fiches de cours (Seyès, Kalam, Source Serif 4, couleurs chaudes par fiche, graisse 700) contredisent l'UDR-0136 et les règles de `test/design/design_tokens_test.rb` ; il faut une exception bornée à l'écran de la fiche
-->

| | |
|---|---|
| **Statut** | Proposé — exception à l'UDR-0136 accordée par Touré le 2026-10-27 pour le test, à confirmer par le porteur ; nom à l'écran en attente du porteur (§ 4) |
| **Date** | 2026-10-27 |
| **Chantier** | `docs/chantiers/contenu-en-blocs` (#318) |
| **ADR lié** | ADR-0110 |
| **Remplacé par** | — |

---

## 1. Contexte

Le porteur a décidé le 2026-10-27 que les maquettes de `docs/design/fiches-cours/` se reproduisent au pixel près : papier Seyès, pages, thème par fiche, Kalam et Source Serif 4 hébergées par Lnclass.

Le reste de l'application suit l'UDR-0136 : palette froide, une seule police (DM Sans), graisse plafonnée à 500. `test/design/design_tokens_test.rb` refuse les couleurs hexadécimales, l'attribut `style`, les valeurs arbitraires, `font-serif` et toute police autre que DM Sans dans `app/views`, `app/helpers` et `app/javascript`.

## 2. Décision

**L'écran de la fiche de cours a son propre habillage, isolé du reste de l'application.** Exception à l'UDR-0136 accordée par Touré le 2026-10-27 pour le test, à confirmer par le porteur.

- Une feuille de style à part, `app/assets/stylesheets/course_sheet.css`, chargée seulement sur l'écran de la fiche. Elle porte les jetons des maquettes en variables CSS (`--sheet-paper`, `--sheet-ink`, `--sheet-primary`, `--sheet-accent`…), le Seyès en dégradés, les 3 thèmes (`blue`, `teal`, `burgundy`) et les composants (`.sheet-page`, `.sheet-box`, `.sheet-btn`…).
- Kalam (400, 700) et Source Serif 4 (variable, 400 à 600, italique) en `woff2`, servies par Lnclass depuis `public/fonts/`, déclarées seulement dans cette feuille.
- Les vues de `app/views/catalog/course_sheets/` et les contrôleurs `app/javascript/controllers/course_sheet/` n'utilisent que les classes de cette feuille : pas d'attribut `style`, pas de valeur arbitraire Tailwind. La position calculée d'une bulle ou d'un point de figure passe par des attributs SVG ou des variables CSS posées en JavaScript.
- `design_tokens_test.rb` garde ses règles partout, sauf les règles « une seule police », « palette froide » et « graisse 500 » pour ces deux dossiers et cette feuille. Le test vérifie que l'exception ne s'étend pas ailleurs.
- La barre de l'application (`shell`) reste au-dessus de la fiche, avec la palette de l'UDR-0136.

## 3. Règles d'implémentation

| Élément | Règle (source : `docs/design/fiches-cours/README.md` et le code des `.dc.html`) |
|---|---|
| Page | papier `#fbf6e9`, ombre teintée par thème, 3 pages `data-screen-label`, écart 40 px |
| Titres | Kalam ; h1 48 à 56 px souligné 3 px accent ; h2 26 à 30 px numéroté, accent |
| Texte | Source Serif 4, 16 à 18 px, interligne 1,5, `text-wrap: pretty` |
| Retours | juste `oklch(0.52 0.13 155)`, à revoir `oklch(0.53 0.19 27)`, à compléter `#6a6d80` |
| Lexique | bulle `position: fixed`, 310 px, `max-height: 70vh`, fermée au défilement ou au clic ailleurs |
| Explications simples | bascule violette `oklch(0.48 0.15 305)` |

Les valeurs exactes de chaque composant se lisent dans le gabarit `<x-dc>` des maquettes, pas dans des captures.

## 4. En attente du porteur (#318)

1. **Nom à l'écran** — proposition : « Fiche de cours », cohérent avec l'UDR-0130 (la fiche se rattache à la leçon, `Course`).
2. **Téléphone** — retenu par Touré pour le test de la phase 1 (2026-10-27), à confirmer par le porteur : le même design avec des pages fluides sous 1 000 px.
   - On garde les couleurs, les polices et le rythme Seyès de 8 et 32 px.
   - La hauteur A4 disparaît, et les marges intérieures passent à 16 px.
   - Les figures SVG se redimensionnent, et leurs points se déplacent au doigt (zone de toucher ≥ 44 px).
   - Le tableau des connecteurs passe en cartes.
   - Le lexique s'ouvre en tiroir en bas de l'écran sous 640 px.

## 5. Conséquences

- La fiche ne ressemble pas au reste de l'application : c'est voulu, c'est un cahier.
- Deux polices de plus, chargées seulement sur la fiche, à compter dans le poids de la page.
- Amende l'UDR-0136 pour le seul écran de la fiche de cours.
