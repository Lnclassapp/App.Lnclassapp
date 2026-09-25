# UDR-0005 : Design system fondateur (tokens, composants, règles vérifiées)

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/refonte-application`](../../chantiers/refonte-application/) (Lot 0c, décision F-09) |
| **ADR lié** | [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (CSP stricte, aucune ressource tierce) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (budget de poids) |
| **Remplacé par** | — |

---

## 1. Contexte

L'ancienne application empile trois sources de style qui se contredisent. Les UDR-0001, 0002 et 0003 prescrivent des classes Tailwind brutes (`bg-slate-50`, `shadow-[0_2px_12px_rgba(...)]`, `bg-green-100`). `.interface-design/system.md` décrit une palette `slate/blue`. Enfin, la landing du nouveau dépôt a sa propre identité (bleu `#00a0ff`, encre, papier, DM Sans et Bricolage Grotesque). Pour l'utilisateur, cela donne des écrans qui ne se ressemblent pas d'un rôle à l'autre : trois balisages de carte de cours (C-32), des badges verts de deux teintes (C-31), une bascule de mode sombre sans aucun style sombre (C-38). Pour l'équipe, n'importe quelle valeur est permise, donc chaque écran réinvente la sienne.

Le porteur a tranché le 2026-09-25 pour un **design mixte**. Les écrans, les parcours, la structure et les composants viennent de l'ancienne application. L'identité visuelle (couleurs, polices, logo) vient de la landing.

## 2. Décision

1. **Une seule palette : le bloc `@theme`** de `app/assets/stylesheets/application.tailwind.css`, issu de la landing. Les familles de couleurs, de rayons, d'ombres et de polices par défaut de Tailwind sont **remises à zéro** (`--color-*: initial`, etc.). `bg-slate-50`, `rounded-xl` ou `shadow-md` ne produisent donc plus aucun CSS : le token est le seul chemin.
2. **Tokens courts et nommés** (`rounded-ln`, `shadow-card`, `bg-brand-soft`), jamais `rounded-[var(--radius-ln)]`.
3. **Aucune valeur arbitraire** (`-[…]`, `[prop:valeur]`, `-(--var)`), **aucun `#hex`**, **aucun attribut `style`** dans les vues, les helpers et le JavaScript. Un test l'impose (§3, « Vérification »).
4. **Pas de mode sombre en V1** : aucune variante `dark:`, et les bascules de l'ancienne application ne sont pas reprises.
5. **Heroicons seul**, en SVG vendorés (`vendor/heroicons`, v2.2.0, MIT), rendus en ligne par `ui_icon`. Pas de nouvelle gem, pas de police d'icônes, pas de CDN.
6. **Polices servies par l'application** (ADR-0049) : DM Sans et Bricolage Grotesque en woff2 variables, sous-ensemble latin, licence OFL, dans `app/assets/fonts`.
7. **Peu de composants, tous substantiels** : treize composants en partials, appelés par une API Ruby unique (`ComponentsHelper`). Une vue n'écrit pas le balisage d'un bouton, d'une carte ou d'un champ : elle appelle le composant.
8. **Un guide vivant** : `/design` (hors production) montre chaque token et chaque composant dans chacune de ses variantes et de ses états. Ce qui n'y figure pas n'existe pas.
9. **UDR-0004 est déclarée non applicable au projet cible.** Elle décrit une migration à iso-interface de l'ancienne application (5 rôles dont `parent`, tiroir et barre latérale « non altérés »). Le projet cible a 4 rôles et un shell unique (UDR-0006).
10. **Les sections « Tokens » des UDR-0001, 0002 et 0003 sont remplacées** par la présente UDR. Leurs autres sections (structure, comportement) restent valables, traduites en tokens selon la table du §3.

**Pourquoi remettre les familles à zéro plutôt que simplement l'interdire ?** Une règle écrite finit par être contournée. Une classe qui ne compile pas se voit à l'écran, et le test la refuse avant la revue.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Couleurs** (texte AA vérifié : ratio ≥ 4,5 sur le fond indiqué)

| Token | Valeur | Usage |
|---|---|---|
| `ink` | `#262626` | texte principal, bouton principal |
| `mute` | `#5e5a54` | texte secondaire (6,46 sur `paper`) |
| `line` | `#e6e1d8` | bordures, filets |
| `mist` | `#f2eee7` | fonds neutres, squelettes, survols |
| `paper` | `#faf8f4` | fond de page |
| `white` | `#ffffff` | cartes, champs, modales |
| `brand` | `#00a0ff` | aplats de marque ; **le texte posé dessus est toujours `ink`** (5,38 ; le blanc ne fait que 2,81) |
| `brand-soft` | `#e5f5ff` | fonds de marque doux, tuiles d'icône |
| `brand-strong` | `#0070b3` | texte et icônes de marque sur fond clair (5,29 sur blanc) |
| `teacher` · `school` · `team` · `gold` | `#ff8a00` · `#1b365d` · `#7b3aed` · `#f39c12` | couleurs de rôle (filet d'en-tête, badges, avatars) |
| `success` / `success-soft` | `#18723f` / `#e7f5ed` | état réussi (5,31 sur son fond) |
| `warning` / `warning-soft` | `#9a5200` / `#fff1dc` | avertissement (5,27) |
| `error` / `error-soft` | `#c8322b` / `#fdecea` | erreur (4,65 ; blanc sur `error` : 5,32) |
| `info` / `info-soft` | = `brand-strong` / `brand-soft` | information |

Opacités autorisées sur ces tokens (`bg-ink/5`, `border-ink/10`, `text-white/70`). `transparent`, `current` et `rounded-full` restent disponibles.

**Typographie**
- `font-sans` = DM Sans (texte courant, 16 px), `font-display` = Bricolage Grotesque (titres, `font-extrabold`), `font-mono` = pile système.
- Échelle Tailwind standard (`text-xs` → `text-6xl`) plus `text-2xs` (11 px, barre basse et petits badges). Interligne des grands titres : `leading-display` (1,05).

**Rayons** : `rounded-sm` 0,5 rem (petits éléments), `rounded-ln` 0,75 rem (champs, menus, tuiles), `rounded-card` 1,5 rem (cartes, toasts), `rounded-sheet` 2 rem (modales, grands blocs), `rounded-full` (pilules, boutons, avatars).

**Ombres** : `shadow-card` (repos d'une carte), `shadow-lift` (carte-lien survolée, bouton d'appel), `shadow-pop` (menus, modales, toasts).

**Espacements**
- Échelle numérique autorisée pour les marges, les retraits, les écarts, les positions et les translations (`p-*`, `m-*`, `gap-*`, `space-*`, `inset-*`, `top-*`, `translate-*`, `scroll-m*-*`) : **0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10, 12, 14, 16, 20, 24, 28, 32**. Les tailles (`w-*`, `h-*`, `size-*`) restent libres sur l'échelle Tailwind.
- Espacements nommés : `tap` (3 rem = 48 px, cible tactile minimale), `gutter` (1,25 rem, marge latérale mobile), `bar` (4 rem, hauteur de l'en-tête), `rail` (18 rem, largeur de la barre latérale).
- Largeurs de contenu : `max-w-page` (72 rem), `max-w-form` (28 rem).

**Animations** : `animate-fade-in` (menus), `animate-slide-up` (modales, toasts), plus `animate-spin` et `animate-pulse` de Tailwind.

**Utilitaires maison** (`@utility`) : `object-hero` (cadrage de la photo de la landing), `pb-safe` (barre basse au-dessus de l'indicateur système), `scrollbar-none` (bandes défilantes d'onglets).

**Composants** — `app/views/components/`, API dans `app/helpers/components_helper.rb`. Une option inconnue lève `ArgumentError` en français.

| Composant | API |
|---|---|
| Icône | `ui_icon(name, variant: :outline\|:solid\|:mini, size: :sm\|:md\|:lg\|:xl, label: nil, class:)` : décorative (`aria-hidden`) sauf si `label:` est donné |
| Indicateur | `ui_spinner(size:)` |
| Bouton | `ui_button(label = nil, variant: :primary\|:brand\|:secondary\|:ghost\|:danger, size: :sm\|:md\|:lg, href:, type:, icon:, icon_end:, disabled:, loading:, method:, full:, **html) { contenu }` : `<a>` si `href:`, désactivé et en chargement annoncés (`aria-disabled`, `aria-busy`) |
| Carte | `ui_card(title:, subtitle:, icon:, href:, padding: :none\|:sm\|:md\|:lg, heading: :h2) { \|card\| card.actions {…}; card.footer {…}; corps }` : avec `href:`, toute la carte est un lien qui se soulève |
| Champ | `ui_field(form, :attribut, as: :text\|:email\|:password\|:tel\|:number\|:date\|:search\|:url\|:textarea\|:select\|:checkbox, label:, hint:, required:, choices:, **input_html)` : libellé, aide et **première** erreur reliés par `aria-describedby`, `aria-invalid` |
| Modale | `ui_modal(title:, id:, size: :sm\|:md\|:lg, trigger:, trigger_variant:, trigger_icon:, open:) { \|modal\| modal.footer {…}; corps }` : `<dialog>` native |
| Menu | `ui_dropdown(label:, icon:, trigger:, align: :start\|:end, id:) { ui_dropdown_item(label, href:, icon:, method:, tone: :default\|:danger) }` : sans `href:`, l'entrée est inactive |
| Onglets | `ui_tabs(id:, label:, selected:) { \|tabs\| tabs.tab(:key, label, icon:) { panneau } }` |
| Badge | `ui_badge(label, tone:, size: :sm\|:md, icon:, dot:)` : tons `neutral brand info success warning error teacher school team gold` |
| Badge de rôle | `ui_role_badge(role, size:)` |
| Badge de matière | `ui_subject_badge(label, category:, size:)` : la teinte vient de `materials.category` (`literature` → `gold`, `science` → `brand`, `other` → `team`), **jamais du nom** (défaut CA-26) ; une catégorie inconnue ou absente donne `neutral` |
| Avatar | `ui_avatar(name, src:, size: :sm\|:md\|:lg, tone:)` : photo, sinon initiales (premier et dernier mot) sur un ton stable dérivé du nom |
| Toast | `ui_toast(message, type: :success\|:info\|:warning\|:error, title:, persistent:)` · `turbo_stream_toast(message, type:, title:)` · `toast_type_for(flash_key)` |
| États | `ui_empty_state(title:, description:, icon:, action: { label:, href:, variant:, icon: }) { actions libres }` · `ui_error_state(title:, message:, retry_href:, retry_label:)` · `ui_loading_state(label:, variant: :spinner\|:skeleton, lines:)` |
| Pagination | `ui_pagination(page:, pages:, param: :page)` : rien si une seule page ; conserve la chaîne de requête |
| En-tête de page | `ui_page_header(title:, subtitle:) { actions }` |

**Correspondance pour les UDR-0001, 0002 et 0003** (leurs sections « Tokens » sont remplacées) : `bg-slate-50` → `bg-paper` ; `text-slate-900` → `text-ink` ; `border-slate-100/200` → `border-line` ; `shadow-sm` et `shadow-[0_2px_12px_…]` → `shadow-card` ; survol `shadow-lg` → `shadow-lift` ; `rounded-2xl` → `rounded-card` ; `bg-green-100 text-green-800` → `ui_badge tone: :success` ; « Bleu 600 » → `ui_button variant: :primary` ou `:brand` ; `text-primary-600` → `text-brand-strong` ; badges de gamification Argent / Or / Diamant → `neutral` / `gold` / `brand` (la teinte définitive est tranchée par l'UDR du lot Assessment) ; couleur de matière → `ui_subject_badge(category:)`.

**Comportement**
- Contrôleurs Stimulus : `modal` (`showModal()`, piège du focus et Échap natifs, clic sur le fond, fermeture avant la mise en cache Turbo), `dropdown` (motif WAI-ARIA « menu button » : flèches, Début, Fin, Échap rend le focus au bouton, Tab et clic extérieur ferment), `tabs` (flèches en boucle, Début, Fin, tabindex itinérant), `toast` (délai, pause au survol et au focus, fermeture).
- La classe d'une variante est toujours une chaîne littérale (constante du helper ou tableau dans la vue), jamais interpolée : Tailwind ne compile que ce qu'il lit.

**États obligatoires** : chaque liste ou section de données prévoit `ui_empty_state`, `ui_loading_state` et `ui_error_state`. Les succès passent par un toast (UDR-0006).

**Accessibilité**
- Cibles ≥ 48 × 48 px : `min-h-tap`, `size-tap`. Le bouton `sm` (40 px) agrandit sa zone tactile par un pseudo-élément.
- Focus toujours visible : `focus-visible:outline-2 focus-visible:outline-brand`.
- Contraste AA sur tous les couples texte / fond du tableau des couleurs.

**Vérification**
- `test/design/design_tokens_test.rb` lit `app/views`, `app/helpers` et `app/javascript` et refuse : valeur arbitraire, propriété arbitraire, variable arbitraire, `#hex`, attribut `style`, `dark:`, couleur de la palette par défaut, rayon, ombre ou police hors tokens, espacement hors échelle.
- `test/system/design_system_test.rb` rend `/design` dans Chrome et vérifie chaque composant (couleurs calculées, tailles, clavier, Turbo Stream).
- `test/helpers/*` couvrent les helpers à 100 % en lignes et en branches.

**Budget (ADR-0051)**, mesuré le 2026-09-25 (minifié, gzip niveau 9) : CSS 7,4 Ko (plafond 30), JS 39,7 Ko sans Trix (plafond 60). Polices : 36 Ko (DM Sans) et 40 Ko (Bricolage Grotesque), déjà compressées en woff2. Seule DM Sans est préchargée.

**Formules** : KaTeX, quand un lot en aura besoin, sera servi par le bundle et jamais par un CDN (ADR-0049).

## 4. Conséquences

- Toute nouvelle couleur, rayon, ombre ou espacement nommé passe par une modification du `@theme` **et** de cette UDR (ou d'une UDR qui la remplace). Il n'y a pas d'exception locale.
- Un nouveau composant n'existe qu'une fois appelable par `ComponentsHelper`, visible sur `/design` et couvert par le test système.
- Les teintes de matière suivent `materials.category`. Une règle fondée sur le nom de la matière est interdite.
- Interdit désormais : `dark:`, les couleurs `slate/gray/blue…` de Tailwind, `rounded-xl` et apparentés, `shadow-md` et apparentés, toute valeur entre crochets, tout `#hex` et tout `style=` dans les vues, toute police ou icône servie par un tiers.
