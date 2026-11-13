# UDR-XXXX : Bleu unique de marque — #0861E1 du logo aux boutons, au bandeau, à la PWA et à Android
<!-- index
titre: Bleu unique de marque #0861E1
statut: Accepté
adr-lie: —
problematique: Le logo, les boutons et le bandeau portaient trois bleus différents (#00a0ff, #0070b3, #1e6bae) ; le bleu roi #0861E1 devient le seul, en clair comme en sombre, texte blanc sur fond bleu
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-11-13 : « Bleu roi #0861E1 » devient LE bleu de Lnclass) |
| **Date** | 2026-11-13 |
| **Chantier** | [`docs/chantiers/bleu-unique-marque`](../../chantiers/bleu-unique-marque/memo.md) |
| **ADR lié** | — (amende les valeurs de l'ADR-0082 §4.1 et de l'ADR-0086 §4.8) |
| **Amende** | UDR-0136 §2.2 et §3.1 (les trois bleus), UDR-0005 §3, UDR-0065 §3, UDR-0075 §3.1 (thème « Ciel »), UDR-0078, UDR-0080 §3.3 |
| **Remplacé par** | — |

---

## 1. Contexte

Le porteur : « je constate un écart entre le bleu d'origine sur le logo et le bleu sur les boutons, le bleu sur le layout n'est pas cohérent ». Une revue à trois agents a compté quatre bleus : le bleu ciel `brand` #00a0ff (logo baobab, bandeau élève, barre Turbo, PWA, Android), le bleu soutenu `brand-strong` #0070b3 (bouton principal, liens), un deuxième bouton `ui-button-brand` bleu ciel à texte noir posé à côté du premier, et l'icône « L » en #1e6bae. En sombre, `brand-strong` devenait un bleu clair #7fd0ff sous texte foncé : le bouton principal changeait de couleur **et** de couleur de texte selon le thème.

## 2. Décision

1. **Un seul bleu, #0861E1** (bleu roi du logo d'origine). Tout fond bleu de l'application, de la PWA, des pages statiques et des apps Android le prend.
2. **Texte blanc sur le bleu, toujours** : nouveau jeton `on-brand` (#ffffff dans les deux modes). Contraste 5,52:1 (AA, texte normal). Le noir sur #0861E1 ne fait que 2,91 : interdit.
3. **Le fond bleu ne change pas en sombre.** #0861E1 tient 3,4:1 sur le papier sombre et 3,1:1 sur la carte sombre (élément graphique ≥ 3:1). Plus d'inversion de rôle : un bouton bleu reste bleu à texte blanc dans les deux thèmes.
4. **`brand-strong` n'est plus un fond** : c'est le texte et l'icône bleus. Même valeur que `brand` en clair (#0861E1, 5,52 sur blanc, 4,80 sur `brand-soft`) ; éclairci en sombre (#8bb8f9, 9,22 sur papier, 7,17 sur `brand-soft`) parce qu'un texte bleu foncé ne se lit pas sur fond sombre.
5. **`brand-soft`** : teinte claire de #0861E1 (même teinte 215°), #e7f0fd en clair (encre 13,99) ; #122949 en sombre (encre 12,88).
6. **Un seul bouton bleu** : la variante `ui_button(variant: :brand)` (bleu ciel, texte noir) est fusionnée dans `primary`. Elle n'avait pas de rôle distinct : elle était posée sur les mêmes actions principales, ce qui mettait deux bleus de bouton côte à côte.
7. **Le dégradé bleu** (`from-brand-strong to-brand` des cartes d'accueil, de profil, de classe et de connexion) devient un aplat `bg-brand` : avec un seul bleu, il n'a plus de second ton.
8. **Le logo garde le baobab**, son fond passe de #00a0ff à #0861E1 (logo, favicon, icônes PWA et Android élèves). Le baobab enseignant sur orange ne change pas. Le « L » du SVG d'origine n'est pas affiché (voir le journal, « À trancher ») ; ses fichiers passent au même bleu.
9. **Thèmes d'annonce** : « Ciel » suit le bleu de marque (il reste « l'apparence actuelle ») ; les neuf autres ne changent pas.

Pourquoi un jeton `on-brand` plutôt que `text-white` : `white` est une surface, sombre en mode sombre (#171c24). `band-ink` reste le texte du bandeau orange de l'enseignant (encre foncée en clair).

## 3. Règles d'implémentation

> Contrat d'exécution : un agent l'applique littéralement.

**Tokens** (`app/assets/stylesheets/application.tailwind.css`, `@theme` puis les deux blocs sombres, mêmes valeurs dans les deux)

| Jeton | Clair | Sombre | Usage |
|---|---|---|---|
| `--color-brand` | `#0861e1` | `#0861e1` | **seul fond bleu** : bouton principal, bandeau élève, pastille pleine, puce active, barre, case cochée, carte bleue, barre Turbo, contour de focus |
| `--color-on-brand` | `#ffffff` | `#ffffff` | texte, icône et contour de focus **posés sur** `brand` |
| `--color-brand-strong` | `#0861e1` | `#8bb8f9` | texte, lien et icône bleus sur une surface ; **jamais un fond** |
| `--color-brand-soft` | `#e7f0fd` | `#122949` | fond doux : rond d'icône, entrée active, sélection, bandeau d'info |
| `--color-band-ink` | `#0b2a40` | `#ffffff` | texte posé sur le bandeau `teacher` (inchangé) |
| `--color-info` / `-soft` | alias de `brand-strong` / `brand-soft` | idem | inchangé |

**Classes** (vues, helpers, JavaScript)
- Fond bleu : `bg-brand` (+ `border-brand` s'il a un bord). `bg-brand-strong` est interdit (seule exception : la pastille du jeton sur `/design`). `test/design/brand_blue_test.rb` le refuse.
- Dans une même chaîne de classes, `bg-brand` (avec ou sans préfixe `has-checked:`, `group-aria-checked:`…) ne côtoie jamais `text-white` ni `text-ink` au même préfixe : c'est `text-on-brand`. Contour de focus sur fond bleu : `focus-visible:outline-on-brand`. Bord d'une puce vide sur fond bleu : `border-on-brand`.
- Bouton : `ui_button` variante `:primary` (fond `brand`, texte `on-brand`, survol `bg-brand/90`) ; `:brand` lève `ArgumentError`. Secondaire inchangé (fond `white`, texte `brand-strong`).
- Lien ou icône bleus : `text-brand-strong`, jamais `text-brand` (illisible en sombre, 3,1:1). Exception : une forme décorative `fill-current` sans texte.
- Bandeau d'accueil : `role_fill_class(role)` pour le fond, `role_ink_classes(role)` pour `{ text:, outline: }` — élève `text-on-brand` / `focus-visible:outline-on-brand`, enseignant `text-band-ink` / `focus-visible:outline-band-ink`.
- Rond blanc posé sur une carte bleue (`bg-white text-brand-strong`) : gardé ; en sombre il devient une pastille sombre à icône bleu clair.

**Hors des jetons** (valeur en dur, recopiée, citée ici)
- `config.x.pwa[:theme_color]` = `#0861e1` (manifeste et `meta theme-color`).
- `public/{400,404,422,500}.html` : `--brand #0861e1`, `--brand-soft #e7f0fd`, `--brand-strong #0861e1`, `--on-brand #ffffff` ; bouton `background: var(--brand); color: var(--on-brand)`, survol `rgb(8 97 225 / 0.9)`.
- `public/offline.html` meta `#0861e1` ; `public/offline.css` `--accent #0861e1`, `--on-accent #ffffff` dans les deux modes, bouton `background: var(--accent)`. Le cache hors connexion passe à `lnclass-offline-v3`.
- Android : `brand` et `avatar_background` `#0861E1`, `avatar_text` `#FFFFFF` (coque), `brand` et `ic_launcher_background` `#0861E1` (élèves). Enseignants inchangés.
- Images : fond du baobab #0861E1 dans `logo/lnclass.jpeg` (et ses copies `student.jpg`, `parent.jpg`), `lnclass/lnclass.png`, `public/icon*.png`, `public/apple-touch-icon.png`, `public/favicon.ico`, `android/student/.../mipmap-*/ic_launcher{,_round}.png` ; `lnclass/icon.svg`, `icon.png` et `logo-lnclass.svg` en #0861e1 ; l'illustration de matière par défaut `subjects/generique.svg` passe aux mêmes tons (#0861e1, #0548a8 pour sa tranche, #8bb8f9, #e7f0fd).

**États obligatoires** : aucun nouvel écran ; les états vide · chargement · erreur · succès existants gardent leurs composants. Bouton désactivé : `opacity-50` sur `brand` (inchangé).

**Accessibilité** (vérifiée par `test/design/dark_mode_test.rb`, `brand_blue_test.rb`, `announcement_themes_test.rb`)
- `on-brand`/`brand` 5,52 (clair et sombre) ; `brand-strong` sur `paper`, `white`, `brand-soft` ≥ 4,5 dans les deux modes ; `brand` sur `paper` et `white` ≥ 3 dans les deux modes (contour de focus : 5,52 en clair, contre 2,7 avant).
- Thème « Ciel » : signature `school` sur `brand-soft` 10,55 (clair) et 8,21 (sombre) ; pastille forte ≥ 3.

## 4. Conséquences

- Plus de deuxième bleu de bouton, plus de dégradé bleu, plus de texte noir sur bleu.
- Toute nouvelle vue qui pose un fond bleu écrit `bg-brand text-on-brand` ; le test de conception refuse les autres combinaisons.
- Une image ou une valeur hors jetons qui porte du bleu cite cette UDR et prend #0861E1.
