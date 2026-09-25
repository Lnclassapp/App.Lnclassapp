# Inventaire de la couche UI — Lnclass

> Matière première pour la construction du design system et de la bibliothèque de
> composants du nouveau projet Rails. Ce document décrit **ce qui existe**, pas ce
> qu'il faudrait faire.

**Racine auditée** : `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp`
**Périmètre** : 316 fichiers `app/views/`, 31 contrôleurs Stimulus, `app/assets/stylesheets/application.tailwind.css`, `app/helpers/` (7 fichiers, 528 lignes), `.interface-design/system.md`, `config/routes.rb`.
**Branche** : `docs/process-v2`

---

## 1. Les tokens de design réellement utilisés

Le bloc `@theme` se trouve dans `app/assets/stylesheets/application.tailwind.css`, lignes 16 à 58.
Il n'existe **pas** de `tailwind.config.js` — la configuration est entièrement CSS-first (Tailwind v4).

Les compteurs d'usage ci-dessous portent sur `app/views` + `app/javascript` + `app/helpers`.

### 1.1 Typographie

| Token | Valeur exacte | Usages | Verdict |
|---|---|---|---|
| `--font-display` | `"Montserrat", sans-serif` | 32 | Vivant |
| `--font-body` | `"Inter", sans-serif` | 1 | **Quasi mort** |

Les deux familles sont chargées par un `@import` Google Fonts **bloquant**, en ligne 6 du CSS, hors du `@theme` :

```
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Montserrat:wght@500;600;700;800&display=swap');
```

Graisses chargées : Inter 300/400/500/600/700 ; Montserrat 500/600/700/800.

`--font-body` est quasi mort parce que la police du texte courant vient en réalité de la classe
Tailwind par défaut `font-sans`, posée par `body_classes` dans `app/helpers/layout_helper.rb:15`.
**Inter n'est donc jamais appliquée au corps de texte.**

#### Échelle de taille de texte réellement employée

Aucun token de taille n'est défini : l'échelle est celle de Tailwind par défaut.

| Classe | Taille | Usages |
|---|---|---|
| `text-sm` | 0.875rem / 14px | 659 |
| `text-xs` | 0.75rem / 12px | 421 |
| `text-lg` | 1.125rem / 18px | 147 |
| `text-2xl` | 1.5rem / 24px | 92 |
| `text-3xl` | 1.875rem / 30px | 68 |
| `text-xl` | 1.25rem / 20px | 58 |
| `text-base` | 1rem / 16px | 45 |
| `text-4xl` | 2.25rem / 36px | 26 |
| `text-5xl` | 3rem / 48px | 15 |
| `text-6xl` | 3.75rem / 60px | 3 |

**Hors échelle**, en valeur arbitraire : `text-[10px]` (93 usages — plus fréquent que `text-base`),
`text-[15px]` (9), `text-[11px]` (9), `text-[9px]` (8).

### 1.2 Couleurs

| Token | Valeur exacte | Usages | Verdict |
|---|---|---|---|
| `--color-primary` | `#0066ff` | 283 | Vivant — le seul token couleur vraiment adopté |
| `--color-primary-50` | `#eff6ff` | 4 | Marginal |
| `--color-primary-100` | `#dbeafe` | 0 en vue (1× dans le CSS, ligne 209) | **Mort côté vues** |
| `--color-primary-200` | `#bfdbfe` | 4 | Marginal |
| `--color-primary-hover` | `#0052cc` | 0 direct (via `.btn-primary:hover`) | Vivant indirectement |
| `--color-secondary` | `#1a1a1a` | 109 | Vivant |
| `--color-success` | `#00c851` | 42 | Vivant |
| `--color-warning` | `#ff8800` | 20 | Vivant |
| `--color-error` | `#ff4444` | 28 | Vivant |
| `--color-neutral-50` | `#f8f9fa` | 45 | Vivant |
| `--color-neutral-100` | `#e9ecef` | 106 | Vivant — le plus employé de l'échelle |
| `--color-neutral-200` | `#dee2e6` | 37 | Vivant |
| `--color-neutral-300` | `#ced4da` | 9 | Faible |
| `--color-neutral-400` | `#adb5bd` | 69 | Vivant |
| `--color-neutral-500` | `#868e96` | 96 | Vivant |
| `--color-neutral-600` | `#6c757d` | 37 | Vivant |
| `--color-neutral-700` | `#495057` | 37 | Vivant |
| `--color-neutral-800` | `#343a40` | 13 | Faible |
| `--color-neutral-900` | `#212529` | 30 | Vivant |
| `--color-surface` | `#ffffff` | 15 | Faible |
| `--color-surface-dim` | `#f8f9fa` | 3 | **Quasi mort** (et duplique `neutral-50`) |
| `--color-border` | `#e9ecef` | 3 en `bg-border` + 28 en `border-[var(--color-border)]` | Vivant, mais contourné à 90 % (et duplique `neutral-100`) |

**`border-border` n'est employé nulle part** : les 3 usages du token sont des `bg-border` servant
de filet de séparation. La bordure passe à 90 % par la syntaxe arbitraire.

L'échelle `neutral` est une palette de type Bootstrap, pas la `neutral` de Tailwind : elle **écrase**
la palette par défaut du même nom. `--color-surface-dim` est un alias exact de `--color-neutral-50`,
et `--color-border` un alias exact de `--color-neutral-100`.

### 1.3 Rayons

| Token | Valeur exacte | Usages | Forme d'écriture |
|---|---|---|---|
| `--radius-ln` | `0.75rem` (12px) | 29 | **100 % en `rounded-[var(--radius-ln)]`** |
| `--radius-card` | `1rem` (16px) | 7 | **100 % en `rounded-[var(--radius-card)]`** |
| `--radius-pill` | `9999px` | 5 | **100 % en `rounded-[var(--radius-pill)]`** |

**0 occurrence** de `rounded-ln`, `rounded-card` ou `rounded-pill` : les utilitaires que Tailwind v4
génère automatiquement depuis ces tokens ne sont **jamais** employés. Tout le code réécrit
manuellement la syntaxe arbitraire, ce qui annule le bénéfice du token.

#### Rayons réellement présents dans les vues — 19 valeurs distinctes

| Classe | Valeur | Usages |
|---|---|---|
| `rounded-full` | `9999px` | 359 |
| `rounded-xl` | `0.75rem` | 339 |
| `rounded-2xl` | `1rem` | 189 |
| `rounded-lg` | `0.5rem` | 175 |
| `rounded-md` | `0.375rem` | 49 |
| `rounded` (nu) | `0.25rem` | 38 |
| `rounded-[var(--radius-ln)]` | `0.75rem` | 29 |
| `rounded-3xl` | `1.5rem` | 25 |
| `rounded-[2.5rem]` | 40px | 13 |
| `rounded-[2rem]` | 32px | 8 |
| `rounded-[20px]` | 20px | 8 |
| `rounded-[var(--radius-card)]` | `1rem` | 7 |
| `rounded-[var(--radius-pill)]` | `9999px` | 4 |
| `rounded-[28px]` | 28px | 4 |
| `rounded-b-2xl` | `1rem` | 3 |
| `rounded-t` | `0.25rem` | 2 |
| `rounded-[32px]` | 32px | 2 |
| `rounded-[40px]` | 40px | 1 |
| `rounded-[1.25rem]` | 20px | 1 |

À noter : `rounded-xl` (339 usages) a exactement la même valeur que `--radius-ln` (0.75rem), et
`rounded-2xl` (189) la même que `--radius-card` (1rem). Les tokens décrivent donc bien la réalité —
ils sont simplement court-circuités.

### 1.4 Ombres

**Aucun token d'ombre n'est défini dans le `@theme`.** Les ombres proviennent de Tailwind ou sont
écrites en dur.

| Classe | Usages |
|---|---|
| `shadow-sm` | 276 |
| `shadow-md` | 73 |
| `shadow-lg` | 52 |
| `shadow` (nu) | 52 |
| `shadow-xl` | 28 |
| `shadow-2xl` | 14 |
| `shadow-none` | 12 |
| `shadow-inner` | 6 |

Ombres en valeur arbitraire (13 occurrences, 7 valeurs distinctes) :

```
shadow-[0_4px_0_0_#4338CA]                     4×   ombre "néo-brutaliste" de bouton
shadow-[0_10px_30px_-10px_rgba(0,0,0,0.08)]    4×
shadow-[0_8px_30px_rgb(0,0,0,0.04)]            3×
shadow-[0_8px_30px_rgb(14,165,233,0.12)]       1×
shadow-[0_8px_30px_rgb(0,0,0,0.15)]            1×
shadow-[0_8px_30px_rgb(0,0,0,0.08)]            1×
shadow-[0_5px_0_0_#E2E8F0]                     1×
```

Trois ombres supplémentaires sont écrites dans le CSS lui-même :

- `.card-ln` au repos : `0 2px 8px rgba(0, 0, 0, 0.04)` (ligne 159)
- `.card-ln` au survol : `0 12px 24px rgba(0, 0, 0, 0.08)` (ligne 163)
- `.turbo-progress-bar` : `shadow-[0_0_10px_var(--color-primary-100)]` (ligne 209)

Et `.interface-design/system.md` en prescrit deux autres, encore différentes :
`shadow-[0_2px_12px_rgba(0,0,0,0.03)]` au repos et `shadow-[0_12px_24px_rgba(0,0,0,0.08)]` au survol.
On compte donc **trois définitions concurrentes** de « l'ombre de carte ».

### 1.5 Espacements

**Aucun token d'espacement n'est défini.** L'échelle utilisée est celle de Tailwind par défaut
(base 0.25rem). Les écarts à l'échelle sont marginaux en espacement pur ; les valeurs arbitraires se
concentrent sur la typographie et les rayons.

### 1.6 Animations

| Token | Valeur exacte | Usages | Verdict |
|---|---|---|---|
| `--animate-slide-up` | `slide-up 0.4s cubic-bezier(0.16, 1, 0.3, 1)` | 6 | Vivant |
| `--animate-fade-in` | `fade-in 0.3s ease-out forwards` | 16 | **Ambigu — voir ci-dessous** |
| `--animate-fade-out` | `fade-out 0.3s ease-out forwards` | 0 | **Mort** |

Keyframes déclarés (lignes 61 à 93) :

```
fade-out : opacity 1 → 0, translateY(0) → translateY(-10px)
fade-in  : opacity 0 → 1
slide-up : opacity 0 → 1, translateY(20px) → translateY(0)
```

**Conflit** : une classe `.animate-fade-in` est *redéfinie* en dur dans `@layer utilities`
(ligne 238) avec des keyframes **différents** nommés `fadeIn` (ligne 246), qui ajoutent un
`translateY(5px)` absent du token. Le token du `@theme` et l'utilitaire du layer se marchent dessus.
Une quatrième animation, `.animate-fade-in-up` / `fadeInUp` (lignes 242 et 251), n'est utilisée
qu'une seule fois.

### 1.7 Les classes du `@layer components`

Ce sont les composants CSS du design system (lignes 96 à 202).

| Classe | Définition (résumé) | Usages | Verdict |
|---|---|---|---|
| `.card-ln` | `bg-surface`, `rounded-[var(--radius-card)]`, `border-neutral-100`, ombre `0 2px 8px rgba(0,0,0,.04)` ; survol : `border-primary/20`, ombre `0 12px 24px rgba(0,0,0,.08)`, `translateY(-2px)` | 55 | Vivant — le plus adopté |
| `.badge` | `inline-flex`, `px-2.5 py-0.5`, `rounded-full`, `text-xs font-medium` | 72 | Vivant |
| `.btn-primary` | `bg-primary text-white shadow-sm` ; survol `bg-primary-hover shadow-md` ; focus `ring-primary/30` | 16 | Vivant |
| `.input-ln` | `w-full`, `rounded-[var(--radius-ln)]`, `border-neutral-300`, `py-3 px-4`, `placeholder:text-neutral-400` ; focus `border-primary ring-primary outline-none` | 9 | Faible |
| `.label-ln` | `block text-sm font-medium text-neutral-700 mb-1.5` | 9 | Faible |
| `.no-scrollbar` | masque la barre de défilement (WebKit + IE + Firefox) | 7 | Vivant |
| `.btn-secondary` | `bg-white text-neutral-800 border-neutral-200` ; survol `bg-neutral-50` | 7 | Faible |
| `.btn-ghost` | `bg-transparent text-primary shadow-none` ; survol `bg-primary/10` | 3 | Faible |
| `.badge-primary` | `bg-primary/10 text-primary` | 2 | **Quasi mort** |
| `.badge-success` | `bg-success/10 text-success` | 2 | **Quasi mort** |
| `.badge-error` | `bg-error/10 text-error` | 2 | **Quasi mort** |
| `.badge-warning` | `bg-warning/10 text-warning` | 1 | **Quasi mort** |
| `.btn-danger` | `bg-error text-white` ; survol `bg-red-600` ; focus `ring-error/30` | 1 | **Quasi mort** |
| `.btn-base` | styles partagés des boutons | 0 | **Mort** |
| `.hover-scale` | `transition-transform` ; survol `scale-105` | 0 | **Mort** |
| `.text-shadow-sm` | `text-shadow: 0 1px 2px rgba(0,0,0,0.5)` | 0 | **Mort** |

Base partagée par tous les boutons (ligne 106, appliquée directement aux sélecteurs) :

```
inline-flex items-center justify-center gap-2 font-display font-medium
rounded-[var(--radius-ln)] transition-all duration-200 active:scale-95
focus:outline-none focus:ring-4 disabled:opacity-50 disabled:cursor-not-allowed
border border-transparent
```

À noter : `.btn-danger` survolé bascule sur `bg-red-600` — une couleur de la palette Tailwind par
défaut, pas sur `--color-error`.

---

### 1.8 Les fuites du design system

#### Fuite 1 — La palette Tailwind par défaut écrase les tokens

**3 659 occurrences** de couleurs de la palette Tailwind par défaut, contre **~1 000** occurrences de
tokens. Répartition par famille :

```
slate  1666      green   148      orange   66      cyan    22
blue    746      indigo  147      amber    59      pink    15
gray    245      emerald 126      sky      38      teal    14
red     193      purple  102      violet   32      rose     9
```

`slate` et `blue` représentent à eux seuls 2 412 occurrences.

Le document `.interface-design/system.md` prescrit lui-même `bg-slate-50`, `bg-white`,
`text-slate-900`, `text-slate-500`, `text-blue-600` et `bg-blue-600`. **Le document de design
contredit le `@theme`**, et c'est le document qui a gagné dans le code. Il existe donc deux palettes
concurrentes, sans arbitrage.

#### Fuite 2 — Des nuances `primary-*` qui n'existent pas

Le `@theme` ne définit que `primary`, `primary-50`, `-100`, `-200` et `-hover`. Les vues emploient
pourtant :

| Classe | Usages | Définie ? |
|---|---|---|
| `primary-600` | 17 | **Non** |
| `primary-500` | 12 | **Non** |
| `primary-50` | 7 | Oui |
| `primary-200` | 5 | Oui |
| `primary-700` | 4 | **Non** |
| `primary-300` | 1 | **Non** |
| `primary-100` | 1 | Oui |

Vérification dans le CSS compilé (`app/assets/builds/application.css`) : seules
`--color-primary-50`, `--color-primary-100` et `--color-primary-200` sont émises.
**Les 34 classes `primary-300/500/600/700` ne produisent aucun style.**

Conséquences visibles :

- `app/views/components/_back_path.html.erb:14` — le lien « Retour » global n'a aucun effet de survol.
- `app/views/components/_question_card.html.erb:11` — la pastille « Q » n'a pas de couleur.
- `app/views/components/_exercise_card.html.erb:18,23,193` — bordure de survol, titre survolé et lien d'action sans couleur.
- `app/views/assessment/exercise_sessions/_question_card.html.erb:24` — la classe de sélection d'une réponse `ring-2 ring-primary-500 bg-primary-50 border-primary-500` ne s'applique qu'à un tiers.

#### Fuite 3 — Cinq variables CSS utilisées et jamais définies

Introuvables dans le `@theme`, ailleurs dans `app/`, et dans le CSS compilé :

| Variable | Usages |
|---|---|
| `--color-text-primary` | 17 |
| `--color-text-secondary` | 12 |
| `--color-bg-main` | 12 |
| `--color-text-tertiary` | 9 |
| `--color-bg-paper` | 5 (+ usages en `border-`/`bg-`) |

Elles sont concentrées **dans la bibliothèque de composants officielle** :

```
app/views/components/_page_header.html.erb
app/views/components/_button.html.erb        (variante "outline")
app/views/components/_modal.html.erb
app/views/components/_dropdown.html.erb
app/views/components/forms/_field.html.erb
app/views/components/_import_card.html.erb
app/views/components/_import_inline.html.erb
app/views/components/_read_more.html.erb
```

Plus 6 écrans : `teachers/classrooms/course`, `teachers/classrooms/essential`,
`classroom/teachers/classrooms/course`, `classroom/teachers/classrooms/essential`,
`catalog/courses/show`, `catalog/essentials/show`, `catalog/essentials/_essential`.

Concrètement : dans `app/views/components/_page_header.html.erb:12` le `<h1>` n'a pas de couleur, et
dans `app/views/components/_modal.html.erb:45` le panneau de la modale n'a pas de fond.

#### Fuite 4 — 559 valeurs arbitraires `[...]`

Par préfixe :

```
text     190      min-h        26      has            11      max-h     5
rounded   75      shadow       25      active:scale   12      hover:text 5
bg        33      w            15      tracking       10
border    31      group-data   13      h              10
data      27      active:scale 12      z               6
```

Les plus fréquentes :

```
text-[10px]                                    93×
border-[var(--color-border)]                   28×
rounded-[var(--radius-ln)]                     27×
data-[active=true]                             27×
text-[var(--color-text-primary)]               17×
rounded-[2.5rem]                               13×
min-h-[44px]                                   13×
group-data-[active=true]                       13×
text-[var(--color-text-secondary)]             12×
bg-[var(--color-bg-main)]                      12×
active:scale-[0.98]                            12×
has-[:checked]                                 11×
text-[var(--color-neutral-500)]                10×
```

#### Fuite 5 — 74 couleurs hexadécimales en dur

| Valeur | Occurrences | Où |
|---|---|---|
| `#1E40AF` | 37 | Traits des 7 SVG d'icônes de matière, `app/helpers/application_helper.rb:144-236` |
| `#A7F3D0` | 7 | Remplissage vert menthe (physique, SVT, EDHC) |
| `#4338CA` | 5 | Ombres « néo-brutalistes » de boutons |
| `#25D366` | 4 | Vert WhatsApp |
| `#FEF3C7` | 3 | Remplissage jaune crème (philo, français) |
| `#0066ff` | 3 | **La valeur de `--color-primary` recopiée à la main**, dont `app/views/layouts/application.html.erb:23` (`theme-color`) |
| `#E2E8F0`, `#E0E7FF`, `#10b981` | 2 chacun | Ombres, remplissage lilas |
| `#FFEDD5`, `#FED7AA`, `#EA580C`, `#DC2626`, `#DBEAFE`, `#C2410C`, `#BFDBFE` | 1 chacun | `level_icon`, `app/helpers/application_helper.rb:246-292` |

Soit **51 des 74** concentrées dans les helpers d'icônes de `application_helper.rb`.

#### Fuite 6 — Quatre classes CSS invoquées mais inexistantes

| Classe | Usages | Où | Effet |
|---|---|---|---|
| `btn-ln` | 2 | `app/views/components/_button.html.erb:39` | Le composant bouton officiel applique une classe fantôme |
| `font-sans` | 4 | dont `app/helpers/layout_helper.rb:15` | Fait tomber le corps de texte sur la pile système au lieu d'Inter |
| `safe-pb` | 1 | `app/views/layouts/application.html.erb:90` | Aucune gestion de safe-area sur la barre de navigation basse |
| `ring-ring` | 1 | `app/views/components/_badge.html.erb:38` | Anneau de focus inexistant sur les badges |

#### Fuite 7 — Trois iconographies concurrentes

| Système | Occurrences |
|---|---|
| Emojis servant d'icônes | **824** |
| Appels `heroicon` | 138 |
| SVG inline dans `application_helper.rb` | 7 fonctions (matières) + 1 générateur (`level_icon`) |

Les emojis les plus employés :
`📐 📖 🌍 🌿 ⚗️ 💬 🗣️ ⚽ 🎨 🏛️ 🧠 📊 💻 💎 🥇 🥈 🥉 🔒 📥 📚 💡 ✏️`

#### Fuite 8 — Effets visuels non tokenisés

- **109 gradients** `bg-gradient-to-*` — aucun n'est défini comme token.
- **41 `backdrop-blur`** (glassmorphism) — aucune convention.
- **14 valeurs de `max-w-*`** distinctes pour la largeur de contenu (voir §5).

### 1.9 Synthèse — tout ce qui existe et se fait contourner

C'est le motif le plus structurant de cet inventaire : **presque chaque brique du design system
existe, et presque chaque brique est court-circuitée par du code écrit à la main.** Le tableau
ci-dessous liste tous les cas relevés, avec le rapport entre l'usage conforme et le contournement.

| Brique existante | Usage conforme | Contournement | Rapport |
|---|---|---|---|
| `--radius-ln` → `rounded-ln` | **0** | `rounded-[var(--radius-ln)]` 29× · `rounded-xl` (même valeur) 339× | **0 / 368** |
| `--radius-card` → `rounded-card` | **0** | `rounded-[var(--radius-card)]` 7× · `rounded-2xl` (même valeur) 189× | **0 / 196** |
| `--radius-pill` → `rounded-pill` | **0** | `rounded-[var(--radius-pill)]` 4× · `rounded-full` 359× | **0 / 363** |
| `--color-border` → `border-border` | **0** (3 `bg-border`) | `border-[var(--color-border)]` 28× | **0 / 28** |
| `--color-surface` → `bg-surface` | 12 | `bg-white` brut 361× | **12 / 361** |
| `--color-surface-dim` → `bg-surface-dim` | 3 | `bg-slate-50` / `bg-gray-50` (palette par défaut) | marginal |
| `--color-neutral-*` → `text-neutral-*` | 284 | `text-[var(--color-neutral-…)]` 24× · `slate` 1666× · `gray` 245× | **284 / 1935** |
| `--color-primary` → `bg-primary` | 105 | `bg-[var(--color-primary)]` 6× · `#0066ff` en dur 3× · famille `blue` 746× | **105 / 755** |
| `--font-body` → `font-body` | 1 | `font-sans` (Tailwind) posé dans `body_classes` | **1 / tout le corps de texte** |
| `.input-ln` | 9 | 65 champs stylés à la main (`placeholder:` inline) | **9 / 65** |
| `.label-ln` | 9 | 84 `f.label` avec classes inline | **9 / 84** |
| `.btn-base` | **0** | styles de base dupliqués sur chaque sélecteur | **0 / 5** |
| `.btn-*` (toutes variantes) | 27 | ~74 boutons artisanaux (`inline-flex … rounded-… px-…`) · 30 `f.submit` bruts | **27 / ~104** |
| `components/_button` | 12 appels | 27 `.btn-*` posés directement + ~74 boutons artisanaux | **12 / ~101** |
| `.card-ln` | 55 | ~41 cartes artisanales (`bg-white` + `rounded-*` + `border`) | **55 / 41** |
| `.badge-<variante>` | 7 | `.badge` de base 55× sans variante, habillée à la main | **7 / 55** |
| `components/_badge` | 7 appels | 55 `.badge` posés directement | **7 / 55** |
| `components/_dropdown` | 13 appels | 9 `data-controller="dropdown"` écrits à la main | **13 / 9** |
| `components/_modal` | **0 appel** | 9 `data-controller="modal"` écrits à la main | **0 / 9** |
| `components/forms/_field` | **0 appel** | tous les champs écrits à la main | **0 / total** |
| `components/_empty_state` | 3 appels | `shared/_empty_state` 4× + 15 réimplémentations locales (~280 l.) | **3 / ~34** |
| `components/carousels/_navbar` | 3 appels | 5 copies locales (dont 2 identiques au bit près) | **3 / 5 fichiers** |
| `components/_import_*` (3 composants) | **0 appel** | 2 formulaires d'import locaux | **0 / 2** |
| `shared/_loading_state` | **0 appel** | aucun état de chargement ailleurs — le besoin n'est pas couvert du tout | **0 / 0** |
| `shared/_error_state` | **0 appel** | 14 boucles `errors.full_messages` à la main | **0 / 14** |
| `form_error_notification` (helper) | 1 | 14 boucles manuelles + 5 messages sous champ | **1 / 19** |
| `flash_class` (helper, 4 types) | 1 (dans un partial mort) | mapping binaire `notice → success` / reste → `danger` | 2 types sur 4 atteignables |
| `--animate-fade-in` | 16 | **redéfini en dur** dans `@layer utilities` avec d'autres keyframes | conflit |
| `.hover-scale` · `.text-shadow-sm` | **0** | effets réécrits à la main | **0 / n** |

#### Ce que ce motif implique pour la nouvelle bibliothèque

Trois conclusions se dégagent des rapports ci-dessus.

**1. Les composants sans API tolérante sont systématiquement contournés.**
`components/_modal` (0 appel contre 9 modales artisanales) et `components/forms/_field` (0 appel) ont
les API les plus rigides du lot — un `size` en symbole, un `form` + `method` obligatoires — et ce sont
exactement les deux qui n'ont jamais été adoptés. À l'inverse `components/_dropdown` (13 appels,
API minimale : un `icon` et un bloc) et `components/_button` (12 appels, qui accepte `label` **ou**
`text` pour ne jamais lever d'erreur) sont les plus utilisés. **L'adoption a suivi la tolérance de
l'API, pas sa qualité.** Une API stricte dans la nouvelle bibliothèque n'a de sens que si elle est la
seule voie possible — c'est-à-dire si le style brut correspondant n'est plus disponible.

**2. Les tokens qui exigent une syntaxe arbitraire sont morts en tant que tokens.**
Les trois rayons ont un score de **0 usage conforme sur 927 rayons posés**. Un token qui s'écrit
`rounded-[var(--radius-ln)]` ne fait économiser aucune frappe par rapport à `rounded-xl`, et il est
moins lisible — il ne sera jamais adopté spontanément. Les tokens de la nouvelle bibliothèque doivent
produire des utilitaires dont le nom est **plus court ou aussi court** que l'équivalent brut.

**3. Les briques adoptées sont celles qui font quelque chose que le style brut ne fait pas.**
`.card-ln` (55 usages, **seule brique dont l'usage conforme dépasse le contournement**) encapsule une
transition, un décalage au survol et deux ombres — reproduire cela à la main coûte cher, donc on
l'appelle. `.badge` (55 usages de la base, 7 des variantes) encapsule 5 déclarations triviales : on
prend la base et on habille soi-même. **Le seuil d'adoption se situe là où le composant devient moins
cher que sa réécriture.** Les composants de la nouvelle bibliothèque qui n'encapsulent que 2 ou
3 déclarations (badge, pastille, filet) seront contournés quoi qu'on fasse : mieux vaut les traiter
comme des tokens que comme des composants.

---

## 2. Le catalogue des composants existants

### 2.1 La bibliothèque déclarée : `app/views/components/`

Pour chaque composant : rôle, paramètres attendus (`locals`), **variantes et états gérés**, nombre
d'appelants. Les variantes sont ce qui détermine l'API dans la nouvelle bibliothèque.

---

#### `components/_button.html.erb` — 12 appelants

**Rôle** : bouton ou lien stylé, point d'entrée unique des actions.

**Paramètres**
| Nom | Type | Défaut | Note |
|---|---|---|---|
| `label` **ou** `text` | String | `"Bouton"` | Deux noms acceptés pour la même chose (dette d'API assumée en commentaire ligne 7) |
| `variant` | String | `"primary"` | |
| `size` | String | `"md"` | |
| `icon` | String | `nil` | Nom d'un heroicon, rendu en variante `:mini` à `w-4 h-4` |
| `href` | String | `nil` | Si présent → rend un `<a>` ; sinon un `<button>` |
| `type` | String | `"button"` | `submit` / `button` |
| `html_class` | String | `""` | Classes additionnelles |
| `data` | Hash | `{}` | Attributs `data-*` passés tels quels |

**Variantes** (5)
| Valeur | Rendu |
|---|---|
| `primary` | `.btn-primary` — `bg-primary text-white shadow-sm` |
| `secondary` | `.btn-secondary` — `bg-white text-neutral-800 border-neutral-200` |
| `ghost` | `.btn-ghost` — `bg-transparent text-primary shadow-none` |
| `danger` | `.btn-danger` — `bg-error text-white` |
| `outline` | **Pas de classe CSS** — classes inline `border border-[var(--color-border)] hover:bg-[var(--color-bg-paper)]`, donc **invisible** (fuite 3) |

Repli sur `primary` si la valeur est inconnue.

**Tailles** (3)
| Valeur | Classes |
|---|---|
| `sm` | `h-8 px-3 text-sm` |
| `md` | `h-10 px-4 text-sm` |
| `lg` | `h-12 px-6 text-base` |

**États gérés**
| État | Traitement |
|---|---|
| Survol | `bg-primary-hover shadow-md` (primary), `bg-neutral-50` (secondary), `bg-primary/10` (ghost), `bg-red-600` (danger) |
| Focus | `focus:outline-none focus:ring-4` + anneau par variante (`ring-primary/30`, `ring-neutral-200`, `ring-error/30`) |
| Actif | `active:scale-95` (base commune) |
| Désactivé | `disabled:opacity-50 disabled:cursor-not-allowed` — **purement CSS, aucun prop `disabled`** |
| Chargement | **Absent** |

**Défauts relevés** : applique `btn-ln`, classe inexistante (fuite 6) ; la variante `outline` est
invisible ; accepte un local `turbo_frame` depuis `_empty_state` mais l'ignore.

---

#### `components/_dropdown.html.erb` — 13 appelants (le plus utilisé)

**Rôle** : menu contextuel déclenché par un bouton icône.

**Paramètres**
| Nom | Type | Défaut |
|---|---|---|
| `icon` | String (heroicon) | `"ellipsis-vertical"` |
| `position` | String | `"bottom-right"` |
| bloc `yield` | ERB | contenu du menu |

**Variantes** : 2 positions — `bottom-right`, `bottom-left`.

**États gérés**
| État | Traitement |
|---|---|
| Ouvert / fermé | Classe `hidden` pilotée par Stimulus `dropdown` |
| Survol du déclencheur | `hover:bg-[var(--color-bg-main)] hover:text-[var(--color-primary)]` — **invisible** (fuite 3) |
| Focus | `focus:outline-none` **sans anneau de remplacement** |
| Clic extérieur | Fermeture (`clickOutside`) |
| Clavier | `Escape` ferme (`handleKeydown`) |
| Repositionnement | Méthode `position()` du contrôleur |

**Accessibilité** : `aria-haspopup="menu"` et `aria-expanded` présents ; **`aria-controls` absent**.

---

#### `components/_badge.html.erb` — 7 appelants

**Rôle** : pastille de statut ou de catégorie.

**Paramètres** : `text` **ou** `label` (String, défaut `""`), `variant` (défaut `"primary"`),
`size` (défaut `"md"`), `html_class`.

**Variantes** (7)
| Valeur | Rendu |
|---|---|
| `primary` | `.badge-primary` — `bg-primary/10 text-primary` |
| `success` | `.badge-success` — `bg-success/10 text-success` |
| `warning` | `.badge-warning` — `bg-warning/10 text-warning` |
| `danger` | `.badge-error` |
| `error` | `.badge-error` (alias de `danger`) |
| `neutral` | `bg-gray-100 text-gray-700 border border-gray-200` — **palette par défaut, hors tokens** |
| `brand` | `bg-blue-50 text-blue-700 border border-blue-100` — **palette par défaut, ajouté ad hoc pour `courses/show`** |

Accepte les symboles comme les chaînes (`.to_s`). Repli sur `primary`.

**Tailles** (3)
| Valeur | Classes |
|---|---|
| `sm` | `text-[10px] px-2 py-0.5` — **valeur arbitraire** |
| `md` | `text-xs px-2.5 py-1` |
| `lg` | `text-sm px-3 py-1.5` |

**États** : `transition-colors` ; `focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2`
où **`ring-ring` n'existe pas** (fuite 6). Aucun état interactif réel — c'est un `<span>`.

---

#### `components/_card.html.erb` — 3 appelants

**Rôle** : conteneur générique à trois zones.

**Paramètres** : soit un `builder` (via le helper `ui_card`, `app/helpers/components_helper.rb:17`),
soit les locals directs `header`, `body`, `footer` ; plus `padding` (ou `options[:padding]`).

**Variantes de padding** (3)
| Valeur | Classe |
|---|---|
| `:none` | `""` |
| `:normal` (défaut) | `p-6` |
| `:large` | `p-8` |

**États** : les 3 zones sont indépendamment optionnelles (`header_content.present?`, etc.) →
**8 combinaisons**. Survol hérité de `.card-ln` (`border-primary/20`, `translateY(-2px)`).

**Défaut relevé** : les zones header et footer utilisent `bg-gray-50/50` et `bg-gray-50` (palette par
défaut) alors que le conteneur utilise `border-[var(--color-border)]` — mélange des deux systèmes
dans un même fichier.

---

#### `components/_empty_state.html.erb` — 4 appelants

**Rôle** : état vide générique, encadré tireté.

**Paramètres**
| Nom | Type | Défaut |
|---|---|---|
| `title` | String | `"Aucune donnée"` |
| `description` | String | `""` |
| `icon` | HTML | `nil` → SVG de dossier par défaut |
| `action` | Hash `{text:, href:, variant:, icon:, turbo_frame:}` | `nil` |
| `html_class` | String | `""` |

**Variantes / états** : avec ou sans icône (4 combinaisons avec le CTA) ; le CTA délègue à
`components/_button` en propageant sa variante. Conteneur :
`border-2 border-dashed border-neutral-200 bg-surface rounded-[var(--radius-card)]`.

**Note d'API** : `action:` est un hash. C'est **incompatible** avec `shared/_empty_state` qui attend
`cta_text:` + `cta_url:` à plat (voir §2.3).

---

#### `components/_page_header.html.erb` — 1 appelant

**Rôle** : en-tête de page — titre, sous-titre, zone d'actions.

**Paramètres** : `title` (String, requis), `subtitle` (String, optionnel), bloc `yield` (actions).

**Variantes / états** : 4 combinaisons (avec/sans sous-titre × avec/sans actions).

**Défaut relevé** : `text-[var(--color-text-primary)]` sur le `<h1>` et
`text-[var(--color-text-secondary)]` sur le sous-titre — **les deux invisibles** (fuite 3). Ce
composant est donc aujourd'hui inutilisable en l'état.

---

#### `components/_read_more.html.erb` — 6 appelants

**Rôle** : bloc de texte tronqué avec bouton « Lire la suite ».

**Paramètres** : `content` (HTML/String), `line_clamp` (String, défaut `"line-clamp-3"`).

**Variantes** : le nombre de lignes est libre via `line_clamp`.

**États gérés**
| État | Traitement |
|---|---|
| Replié / déplié | Bascule de la classe de troncature (Stimulus `read-more#toggle`) |
| Pas de débordement | Le bouton est **masqué automatiquement** (`checkOverflow`) — bon comportement |
| Survol du bouton | `hover:underline` |

**Défaut relevé** : `text-[var(--color-text-secondary)]` et `text-[var(--color-primary)]` — invisibles.

---

#### `components/_back_path.html.erb` — 6 appelants

**Rôle** : lien « Retour » dont la destination est déduite du rôle.

**Paramètres** : `path` (optionnel).

**Variantes** : 4 destinations calculées — `teams_feed_path` si `team?`, `teachers_feed_path` si
`teacher?`, `students_feed_path` si `student?`, sinon `root_path`.

**États** : survol `hover:text-primary-600` — **sans effet** (fuite 2).

---

#### `components/courses/_course_card.html.erb` — 5 appelants

**Rôle** : carte de cours « premium », conforme à UDR-0001.

**Paramètres** : `course` (requis), `url` (défaut `course_path(course.slug)`), `meta_text` (optionnel).

**Variantes / états**
| Aspect | Traitement |
|---|---|
| Badge matière | 14 palettes via `subject_palette_for(course.material.name)` — `bg`, `text`, `gradient`, `icon` |
| Niveau / série | Pastille affichée uniquement si `course.level` présent ; série ajoutée si le modèle y répond |
| Nom de matière | Affiché seulement si `course.material` présent |
| Aperçu de texte | Repli en cascade : `subtitle` → `content` → rien |
| Survol | `-translate-y-1.5`, ombre `0_12px_24px_rgba(0,0,0,0.08)`, `border-slate-200`, badge `scale-110`, titre `text-blue-600` — `duration-300 ease-out` |
| Repos | Ombre `0_2px_12px_rgba(0,0,0,0.03)`, `border-slate-100` |

C'est le seul composant qui applique fidèlement `.interface-design/system.md`. Il utilise en
revanche exclusivement la palette `slate`/`blue`, pas les tokens.

---

#### `components/_exercise_card.html.erb` — 3 appelants (206 lignes)

**Rôle** : carte d'exercice avec aperçu des questions et actions.

**Paramètres** : `exercise` (requis), `user_session`, `user_badge`, `classroom`.

**Variantes / états**
| État | Traitement |
|---|---|
| Session existante | `has_session = local_assigns[:user_session].present?` — change l'action proposée |
| Badge acquis | Si `user_badge.level` présent → rend `components/_exercise_badge` en `scale-75` |
| Rôle équipe | Si `team?` → dropdown d'actions (modifier / supprimer) |
| Aperçu questions | 1 question visible + le reste replié |
| Description | Rendue via `components/_read_more` dans un conteneur `data-controller="math"` (KaTeX) |
| Survol | `hover:shadow-md hover:border-primary-300` — **bordure sans effet** (fuite 2) |
| Titre survolé | `group-hover:text-primary-600` — **sans effet** (fuite 2) |

---

#### `components/_exercise_badge.html.erb` — 3 appelants

**Rôle** : médaille de niveau acquis.

**Paramètres** : `level` (String/Symbol, requis), `size` (`:md` défaut, `:lg`).

**Variantes de niveau** (5)
| `level` | Fond | Texte | Bordure | Icône | Libellé |
|---|---|---|---|---|---|
| `diamond` | `bg-cyan-100` | `text-cyan-700` | `border-cyan-300` | 💎 | Diamant |
| `gold` | `bg-yellow-100` | `text-yellow-700` | `border-yellow-400` | 🥇 | Or |
| `silver` | `bg-slate-100` | `text-slate-600` | `border-slate-300` | 🥈 | Argent |
| `bronze` | `bg-orange-100` | `text-orange-700` | `border-orange-300` | 🥉 | Bronze |
| autre | `bg-gray-50` | `text-gray-400` | `border-gray-200` | 🔒 | Non acquis |

**Tailles** (2) : `:md` → `h-16 w-16 text-2xl` ; `:lg` → `h-24 w-24 text-4xl`.

**États** : animation d'apparition `animate-in fade-in zoom-in duration-300` — **classes du plugin
`tailwindcss-animate`, non installé** ; sans effet.

---

#### `components/messages/_card.html.erb` — 5 appelants

**Rôle** : carte de message style « Wave », avec image et audio.

**Paramètres** : `message` (requis), `index` (défaut `0`), `allow_dismiss` (Boolean).

**Variantes** : thème alterné par `card_theme(index)` (`app/helpers/messages_helper.rb`) qui fournit
`bg`, `text`, `close`.

**États gérés**
| État | Traitement |
|---|---|
| Fermable | Bouton × affiché seulement si `allow_dismiss` ; `button_to` DELETE ciblant le frame `message_card_<id>` |
| Contenu vide | Le paragraphe n'est rendu que si `message.content.present?` |
| Audio | Lecteur avec bascule lecture/pause (Stimulus `audio-player`, cibles `playIcon`/`pauseIcon`) |
| Survol | `hover:shadow-lg` |
| Hauteur | `h-[140px] sm:h-[150px]` — **valeurs arbitraires** |

**Accessibilité** : `role="article"`, `aria-label` sur la carte, `aria-label` sur le bouton fermer.
C'est le composant le mieux instrumenté du lot.

---

#### `components/carousels/_navbar.html.erb` — 3 appelants

**Rôle** : flèches précédent / suivant d'un carrousel.

**Paramètres** : aucun.

**Variantes / états**
| Aspect | Traitement |
|---|---|
| Visibilité | `hidden lg:flex` — **desktop uniquement** |
| Survol | `hover:border-blue-400 hover:bg-blue-50 hover:shadow-xl hover:scale-110` |
| Actif | `active:scale-95` |
| Position | `-left-3 sm:-left-4` / `-right-3 sm:-right-4`, padding `p-2.5 sm:p-3` |

**Accessibilité** : `aria-label="Précédent"` / `"Suivant"` présents.

---

#### `components/placeholders/_course.html.erb` — 7 appelants

**Rôle** : vignette de repli pour un cours sans image.
**Paramètres** : `icon` (emoji, requis).
**Variantes / états** : aucun. Fond `bg-gradient-to-br from-slate-100 to-slate-200`, emoji `text-5xl`.

---

#### `components/placeholders/_essential.html.erb` — 2 appelants

**Rôle** : vignette de repli d'une habileté, colorée par matière.
**Paramètres** : `material_name` (String, requis).
**Variantes** : 14 palettes via `subject_palette_for` (13 motifs + repli), chacune fournissant un
`gradient` et un `icon` emoji.

---

#### `components/schools/_school_card.html.erb` — 1 appelant

**Rôle** : carte d'établissement.
**Paramètres** : `school` (requis).
**Variantes / états** : aucun. 51 lignes.
**Doublon** : voir §2.3 — une seconde carte d'établissement existe, plus complète.

---

#### `components/_toast.html.erb` — 1 appelant (le layout)

**Rôle** : `<template id="toast-template">` cloné par JavaScript pour chaque notification.

**Paramètres** : aucun — les cibles sont remplies par Stimulus `toast-container`.

**Cibles remplies dynamiquement** : `accent` (barre de couleur supérieure), `iconContainer`, `icon`,
`title`, `message`, `element`.

**Variantes** : 4 types appliqués en JS par `toast-container#applyStyles`. **Mais seulement 2 sont
atteignables** depuis Rails (voir §5) : `notice → success`, tout le reste → `danger`.

**États gérés** : entrée / sortie animées (durée 500 ms) ; survol `-translate-y-1 hover:shadow-…` ;
fermeture manuelle ; auto-fermeture (`toast#disconnect`).

**Style** : glassmorphism — `bg-white/80 backdrop-blur-xl border-white/40 rounded-2xl
shadow-[0_8px_30px_rgb(0,0,0,0.08)]`. **Aucun token employé.**

**Accessibilité** : `role="alert"`, `aria-label="Fermer"` sur le bouton.

---

#### Composants morts de la bibliothèque — 0 appelant

##### `components/_modal.html.erb`
**Rôle** : fenêtre modale standard.
**Paramètres** : `id` (défaut `"modal_#{SecureRandom.hex(4)}"`), `title` (défaut `"Titre"`),
`size` (Symbol, défaut `:md`), bloc `yield`.
**Variantes de largeur** (4) : `:sm` → `sm:max-w-sm` · `:md` → `sm:max-w-lg` · `:lg` → `sm:max-w-2xl` · `:xl` → `sm:max-w-4xl`.
**États** : ouvert/fermé ; transitions entrée (`ease-out duration-300`, `opacity-0 translate-y-4 sm:scale-95` → `opacity-100 translate-y-0 sm:scale-100`) et sortie (`ease-in duration-200`) déclarées en `data-transition-*` ; fond cliquable (`click->modal#close`) ; empilement mobile (`items-end` → `sm:items-center`).
**Accessibilité** : `role="dialog"`, `aria-modal="true"`, `aria-labelledby` lié au titre. **Le mieux fait de la bibliothèque — et jamais rendu.**

##### `components/forms/_field.html.erb`
**Rôle** : champ de formulaire — label, input, message d'erreur.
**Paramètres** : `form` (FormBuilder), `method` (Symbol), `label` (String), `type` (Symbol), `placeholder`.
**Variantes** : `:text_field` (défaut), `:email_field`, `:password_field`, `:text_area`.
**États** : erreur (`form.object.errors[method].any?` → `<p class="text-sm font-medium text-red-500">`) ; focus (`focus:ring-2 focus:ring-[var(--color-primary)] focus:ring-offset-2`) ; désactivé (`disabled:cursor-not-allowed disabled:opacity-50`) ; `peer-disabled` sur le label.
C'est **le composant qui devait unifier les formulaires** — jamais rendu.

##### `components/_question_card.html.erb`
**Rôle** : aperçu repliable d'une question.
**Paramètres** : `question`.
**États** : replié 2 lignes / déplié (Stimulus `read-more` avec `moreText`/`lessText`) ; survol `hover:bg-slate-100` ; gère indifféremment `rich_text_content` et `content`.

##### `components/_import_card.html.erb`
**Rôle** : zone de dépôt de fichier (dropzone).
**Paramètres** : `url`, `title` (défaut `"Importer un fichier"`), `icon` (défaut `"arrow-up-tray"`), `accept` (défaut `"application/json"`).
**États** : survol du groupe (`group-hover:bg-… group-hover:border-…`) ; auto-soumission au choix du fichier (`onchange: this.form.requestSubmit()`).

##### `components/_import_inline.html.erb`
**Rôle** : import JSON compact, « boîte bleue ».
**Paramètres** : `url`, `title` (défaut `"Importer"`), `subtitle` (optionnel).
**États** : sous-titre optionnel ; empilement `flex-col sm:flex-row` ; style de bouton de fichier via `file:*`.

##### `components/_import_form.html.erb`
**Rôle** : import JSON avec exemple dépliable.
**Paramètres** : `course` (codé en dur dans le chemin `import_json_course_essentials_path`).
**États** : `<details>` replié/déplié montrant un exemple de JSON.

---

**Constat structurel** : **6 des 23 composants de la bibliothèque officielle ne sont appelés nulle
part**, dont la modale et le champ de formulaire — les deux briques les plus structurantes. Et
**8 des 17 composants vivants** dépendent de variables CSS non définies.

### 2.2 Les composants hors bibliothèque

| Composant | Rôle | Paramètres | Variantes / états | Appelants |
|---|---|---|---|---|
| `shared/_empty_state.html.erb` | État vide, **API différente** | `icon`, `title`, `description`, `cta_text`, `cta_url` | avec/sans icône (rendue via `render "shared/icons/#{icon}"` avec `rescue` sur un emoji 📁) ; avec/sans CTA | 4 |
| `shared/_error_state.html.erb` | Erreur avec récupération | `title`, `message`, `retry_url`, `retry_text` | avec/sans bouton « Réessayer » ; `role="alert"` | **0 — mort** |
| `shared/_loading_state.html.erb` | Indicateur de chargement | `message` | spinner double anneau `animate-spin` ; texte `animate-pulse` ; `role="status"` + `aria-live="polite"` + `sr-only` | **0 — mort** |
| `shared/_flash.html.erb` | Flash serveur | aucun (lit `flash`) | boucle sur `flash` ; `flash_class(type)` renvoie `"success"`/`"danger"`/`"warning"`/`"info"` — **chaînes qui ne sont pas des classes Tailwind valides** | **0 — mort** |
| `layouts/_toast_message.html.erb` | Conteneur de toasts + pont flash → JS | aucun | conteneur fixe `top-4 right-4 z-50`, `data-turbo-permanent` | 1 (layout) |

La trilogie `shared/_empty_state` / `_error_state` / `_loading_state` est la mieux instrumentée du
projet en accessibilité (`role`, `aria-live`, `sr-only`) — **et deux tiers ne sont jamais rendus**.

### 2.3 Les doublons

#### Doublon majeur — une arborescence entière copiée à l'octet près

`app/views/teachers/classrooms/` est **strictement identique** à
`app/views/classroom/teachers/classrooms/`. Vérifié par `diff` sur chacun des 10 fichiers :

```
_classroom_group.html.erb      IDENTIQUE
_course_assigned.html.erb      IDENTIQUE
course.html.erb                IDENTIQUE
_empty_state.html.erb          IDENTIQUE
essential.html.erb             IDENTIQUE
_examen_assigned.html.erb      IDENTIQUE
index.html.erb                 IDENTIQUE
show.html.erb                  IDENTIQUE
student_detail.html.erb        IDENTIQUE
_student_row.html.erb          IDENTIQUE
```

`config/routes.rb:134-139` route vers `/classroom/teachers/classrooms#…`, et seul
`app/controllers/classroom/teachers/classrooms_controller.rb` existe (il n'y a **pas** de
`Teachers::ClassroomsController`). **`app/views/teachers/classrooms/` est intégralement mort** —
10 fichiers, dont 5 écrans complets.

#### Doublon — 17 états vides

Deux composants génériques et **15 réimplémentations locales** :

| Chemin | Lignes | Appels |
|---|---|---|
| `components/_empty_state.html.erb` | 49 | 3 |
| `shared/_empty_state.html.erb` | 25 | 4 |
| `teams/feed/content/_empty_section.html.erb` | 7 | 6 |
| `students/feed/content/_empty_state.html.erb` | 7 | 5 |
| `teachers/feed/content/_empty_state.html.erb` | 9 | 5 |
| `assessment/exercises/_empty_state.html.erb` | 21 | 3 |
| `classroom/classrooms/_empty_state.html.erb` | 14 | 3 |
| `schoolstaff/feed/content/_empty_state.html.erb` | 9 | 3 |
| `catalog/drenas/_empty_state.html.erb` | 13 | 2 |
| `catalog/essentials/_empty_state.html.erb` | 23 | 2 |
| `catalog/levels/_empty_state.html.erb` | 17 | 2 |
| `catalog/materials/_empty_state.html.erb` | 17 | 2 |
| `teachers/classrooms/_empty_state.html.erb` | 25 | 2 |
| `catalog/courses/_empty_state.html.erb` | 18 | 1 |
| `catalog/schools/_empty_state.html.erb` | 7 | 1 |
| `messages/_empty_state.html.erb` | 11 | 1 |
| `teams/exam_subjects/_empty_state.html.erb` | 8 | 2 |

**280 lignes cumulées pour une seule intention.** Et les deux composants génériques ont des **API
incompatibles** : `components/_empty_state` attend `action: {text:, href:}`, `shared/_empty_state`
attend `cta_text:` + `cta_url:`. Le choix entre les deux est le premier arbitrage à trancher.

#### Doublon — 6 navigations de carrousel

| Chemin | Lignes | md5 (8 car.) |
|---|---|---|
| `components/carousels/_navbar.html.erb` | 19 | `ed37d78e` |
| `messages/_carousel_nav.html.erb` | 19 | `e38fcf26` |
| `students/feed/content/_carousel_nav.html.erb` | 21 | `bccec579` |
| `teachers/feed/content/_carousel_nav.html.erb` | 19 | `603d5538` |
| `schoolstaff/feed/content/_carousel_nav.html.erb` | 19 | `603d5538` |
| `teams/feed/content/_carousel_nav.html.erb` | 16 | `a932021a` |

Les versions `teachers` et `schoolstaff` sont **identiques au bit près**.

#### Doublon — 2 cartes d'établissement divergentes, appelées depuis le même écran

| Chemin | Lignes | Ce qu'elle fait |
|---|---|---|
| `catalog/schools/_school_card.html.erb` | 110 | `cache`, `turbo_frame_tag`, modes `grid` **et** `list`, sigle ou initiales, lien plein-carte (`after:absolute after:inset-0`) |
| `components/schools/_school_card.html.erb` | 51 | aucun des trois |

`app/views/catalog/schools/index.html.erb:47` rend la version `components/`, tandis que
`app/views/catalog/schools/_school.html.erb:4` rend la version `catalog/`.

#### Doublon — 2 cartes de question

`components/_question_card.html.erb` (36 lignes, **mort**) et
`assessment/exercise_sessions/_question_card.html.erb` (56 lignes, vivant, avec Stimulus `checkable`).

#### Doublon — 4 systèmes d'import JSON

Trois composants génériques **tous morts** (`components/_import_card`, `_import_inline`,
`_import_form`) et deux implémentations locales réellement utilisées
(`catalog/courses/_import_form` — 1 appel, `catalog/schools/_import_form` — 2 appels).

#### Doublon — 2 systèmes de notification

`shared/_flash` (Stimulus `toast` sur flash rendu serveur, **mort**) et la chaîne vivante
`layouts/_toast_message` → `components/_toast` → `toast-trigger` + `toast-container`.

#### Doublon — les partials de feed par rôle

Onze intentions déclinées en 3 ou 4 exemplaires, **tous divergents sauf `_carousel_nav`** :

| Partial | students | teachers | teams | schoolstaff |
|---|---|---|---|---|
| `_activities` | 75 l. | 152 l. | 50 l. | 152 l. |
| `_messages` | 42 l. | 47 l. | 59 l. | 47 l. |
| `_levels` | — | 31 l. | 60 l. | 31 l. |
| `_courses` | 86 l. | 58 l. | 60 l. | — |
| `_examens` | 42 l. | 41 l. | 41 l. | — |
| `_examen_dashboard` | 25 l. | 56 l. | 45 l. | — |
| `_feed_header` | 16 l. | 16 l. | 49 l. | — |
| `_dashboard` | 38 l. | 54 l. | 41 l. | — |
| `_placeholder_image` | 3 l. | 5 l. | 5 l. | — |
| `_empty_state` | 7 l. | 9 l. | 7 l. (`_empty_section`) | 9 l. |
| `_carousel_nav` | 21 l. | 19 l. | 16 l. | 19 l. |

**Environ 1 200 lignes pour 11 intentions.**

#### Doublon — 3 helpers de lien de navigation identiques

`student_nav_link_class`, `nav_link_class` et `teacher_nav_link_class`
(`app/helpers/application_helper.rb:98-116`) ont le même corps ; seul le `_path` de repli diffère.

### 2.4 Les autres partials morts

Au-delà des 10 fichiers de `teachers/classrooms/` et des 6 composants morts, jamais rendus :

```
app/views/catalog/drenas/_schools_section.html.erb
app/views/classroom/classrooms/_classroom_essential.html.erb
app/views/classroom/classrooms/_empty_state_essentials.html.erb
app/views/students/feed/content/_habiletes.html.erb
app/views/students/feed/content/_shared.html.erb
app/views/students/feed/content/_courses.html.erb
app/views/students/feed/content/_dashboard.html.erb
app/views/students/feed/content/_placeholder_image.html.erb
app/views/teachers/feed/content/_courses.html.erb
app/views/teachers/feed/content/_dashboard.html.erb
app/views/teachers/feed/content/_drenas.html.erb
app/views/teams/feed/content/_courses.html.erb
app/views/teams/feed/content/_dashboard.html.erb
app/views/teams/feed/content/_placeholder_image.html.erb
app/views/teachers/exam_subjects/_material_icon_card.html.erb
app/views/teams/dashboard/shared/_kpis.html.erb
app/views/teams/dashboard/shared/_levels_widget.html.erb
app/views/teams/dashboard/shared/_materials_widget.html.erb
app/views/teams/dashboard/shared/_messages_widget.html.erb
app/views/teams/dashboard/shared/_teachers_list.html.erb
app/views/layouts/shared/analytics/_analytics_script.html.erb
app/views/layouts/shared/_script.html.erb
```

---

## 3. Les écrans, par rôle

Environ **60 écrans distincts**, hors les 5 écrans morts de `teachers/classrooms/`.
Source : `config/routes.rb` croisé avec les `page_title` / `content_for :title` / `<h1>` des vues.

### 3.1 Public / non authentifié

Sur ces écrans, `hide_layout_components?` (`app/helpers/layout_helper.rb:38`) masque header,
sidebar et bottom nav.

| URL | Titre | Ce qu'on y voit | Ce qu'on peut y faire | Fichier |
|---|---|---|---|---|
| `/` | Comprends chap chap ! | Landing marketing plein écran | Ouvrir 2 modales de choix de parcours (élève / prof) | `homepage/index.html.erb` |
| `/login` | Connexion | Formulaire e-mail + mot de passe | Se connecter | `identity/sessions/new.html.erb` |
| `/student-signup` | Inscription — Bienvenue sur Lnclass | Formulaire élève + cascade école/classe ou code de classe | S'inscrire | `students/registrations/new.html.erb` |
| `/teacher-signup` | Enseignant — Inscription | Formulaire prof + cascade DRENA/école | S'inscrire | `teachers/registrations/new.html.erb` |
| `/staff-signup` | Direction — Inscription — Bienvenue sur Lnclass | Formulaire personnel de direction | S'inscrire | `school_admins/registrations/new.html.erb` |
| `/team-signup` | Équipe — Inscription | Formulaire équipe interne | S'inscrire | `teams/registrations/new.html.erb` |
| `/c/:unique_code` | Rejoindre la classe — Prepa BAC 2026 | Entrée élève par code de classe transmis par le prof | Rejoindre la classe | `students/prepa_registrations/new.html.erb` |

### 3.2 Élève (`student`)

**Navigation** — sidebar : Accueil · Découvre · École · Raccourcis. Bottom nav : `students_feed_path`,
`school_path` (**2 destinations seulement**).

| URL | Titre | Ce qu'on y voit | Ce qu'on peut y faire |
|---|---|---|---|
| `/students` | Accueil | Feed en 8 sections : en-tête, tableau examens, ma classe, examens, matières, messages, activités, exercices | Naviguer, lancer un exercice |
| `/students/classroom` | Ma Classe | Fiche de la classe : enseignants, cours, camarades | Consulter |
| `/students/examens` | Centre de Préparation aux Examens | Grille de sujets par matière (`_subject_card`, `_material_icon_card`) | Ouvrir un sujet |
| `/students/examens/:id` | — | Détail d'un sujet d'examen | Composer, `POST retry` (recommencer) |
| `/students/training-examens` | — | Sujets d'entraînement | Composer |
| `/students/subject-examens` | — | Sujets filtrés par matière | Composer |
| (paywall) | Accès Restreint — Prepa BAC 2026 — Contenu Premium | Écran de blocage | Débloquer l'accès |
| `/exercise_sessions/:id` | — | Passage d'exercice question par question (`_question_card`, Stimulus `checkable`, rendu KaTeX) | Répondre, valider |
| `/exercise_sessions/:id/result` | — | Résultat + animation de confettis (Stimulus `confetti`) | Rejouer, retourner au feed |

### 3.3 Enseignant (`teacher`)

**Navigation** — sidebar : Accueil · Découvre · Classes · Raccourcis. Bottom nav :
`teachers_feed_path`, `school_path` (**2 destinations**).

| URL | Titre | Ce qu'on y voit | Ce qu'on peut y faire |
|---|---|---|---|
| `/teachers` | Accueil | Feed en 7 sections : en-tête, tableau examens, classes, examens, niveaux, messages, activités | Naviguer |
| `/teachers/dashboard` | — | **Écran de scaffold Rails jamais implémenté** : `<h1>Teachers::Dashboard#index</h1>` + « Find me in app/views/… » | rien |
| `/teachers/setup` | choix des classes — Bienvenue sur Lnclass ! | Onboarding première connexion | Choisir ses classes |
| `/teachers/classrooms` | Sélection des classes — Quelles classes enseignez-vous ? | Cases à cocher groupées par niveau, compteur, barre d'action flottante (Stimulus `classroom-selection`) | Sélectionner, cocher un groupe entier, valider |
| `/teachers/classrooms/:id` | `<classe> - <école>` | Détail de classe : élèves, cours assignés, examens assignés | Assigner, retirer |
| `/teachers/classrooms/:id/courses/:course_id` | `<cours> — <classe>` | Cours dans le contexte d'une classe | Assigner des habiletés |
| `/teachers/classrooms/:id/essentials/:essential_id` | `<habileté> — <classe>` | Habileté et ses exercices | Assigner des exercices |
| `/teachers/classrooms/:cid/students/:public_id` | `<élève> - <classe>` | Fiche élève : progression, badges acquis | Consulter |
| `/teachers/classroom_exercises/:slug` | `<exercice> — Résultats` | Résultats d'un exercice passé en classe | Consulter |
| `/teachers/classroom_exercises/:slug/report` | — | Rapport détaillé par question | Consulter |
| `/teachers/classroom_exercises/:slug/remediation` | — | Écran de remédiation | Lancer une remédiation |
| `/teachers/examens` | Banque de Sujets d'Examens | Grille de sujets (`_subject_assignment_card`) | Assigner à une classe |
| `/teachers/examens/:id` | — | Détail d'un sujet | Assigner |
| `/teachers/training-examens` · `/teachers/subject-examens` | — | Sujets d'entraînement / par matière | Assigner |
| `/teachers/prepa_acquisitions/new` | Prepa BAC — Ressources Enseignants | Formulaire d'acquisition (cascade école) | Commander |
| `/teachers/prepa_acquisitions/download` | Téléchargement — Prepa BAC 2026 — Félicitations, M. … | Confirmation + lien | Télécharger |

### 3.4 Équipe interne (`team`)

**Navigation** — sidebar : Accueil · Messages · Cours · Panel Admin (+ `teams_dashboard_path`,
`teams_setup_path`, `teams_lnclassai_path`). Bottom nav : `teams_feed_path` seul
(**1 destination pour 6 dans la sidebar**).

| URL | Titre | Ce qu'on y voit | Ce qu'on peut y faire |
|---|---|---|---|
| `/teams` | Accueil | Feed en 7 sections : en-tête, tableau examens, DRENA, examens, niveaux, messages, activités | Naviguer |
| `/teams/dashboard` | Tableau de Bord Team — **Control Center** | 4 onglets (Stimulus `tabs`) : Pilotage, Communauté, Académie, Régions ; bandeau « Vue active » ; dropdown « Actions rapides » | Ajouter une DRENA, créer un cours |
| `/teams/setup` | Configuration Plateforme — Configuration | Onglets : niveaux, matières, séries, DRENA, messages | CRUD complet des référentiels |
| `/teams/lnclassai` | — | **Un `<iframe>` vers un artifact `claude.site` externe** (`teams/dashboard/lnclassai.html.erb:4`) | rien |
| `/teams/examens` | Gestion des Examens | Liste des sujets (`_exam_subject`) | Créer, importer JSON, supprimer |
| `/teams/examens/:id` | — | Détail d'un sujet | Supprimer |

### 3.5 Direction d'école (`school_admin` / schoolstaff)

**Navigation** — sidebar : Accueil · Classes · Enseignants · Élèves. Bottom nav : **les mêmes 4
destinations**. C'est le **seul rôle** dont la navigation mobile couvre la même arborescence que la
navigation desktop.

| URL | Titre | Ce qu'on y voit | Ce qu'on peut y faire |
|---|---|---|---|
| `/schoolstaff` | Tableau de bord - `<école>` | Carte KPI en dégradé bleu (classes / élèves / enseignants) + 3 sections : niveaux, messages, activités | Naviguer |
| `/schoolstaff/classrooms` | — | Liste des classes de l'établissement | Créer une classe |
| `/schoolstaff/classrooms/:id` | Classe : `<nom>` | Détail avec onglets (Stimulus `tabs`) + code de classe copiable (Stimulus `clipboard`) | Copier le code d'invitation |
| `/schoolstaff/teachers` | Enseignants | Liste du corps enseignant | Ajouter un enseignant |
| `/schoolstaff/students` | Élèves | Liste des élèves | Ajouter un élève |
| `/schoolstaff/profile` | Mon Profil | Fiche du responsable | — |
| `/schoolstaff/profile/edit` | Modifier mon Profil | Formulaire | Enregistrer |
| `/schoolstaff/settings` | Paramètres & Sécurité | Formulaire | Enregistrer |
| (pending) | En attente d'affectation | Écran d'attente avant rattachement à une école | — |

### 3.6 Catalogue — transversal

Accessible selon le rôle, sans espace dédié dans l'URL.

| URL | Titre | Ce qu'on y voit | Ce qu'on peut y faire |
|---|---|---|---|
| `/courses` | Les cours — Catalogue Pédagogique | Grille de `_course_card`, scroll infini (`infinite-scroll`), filtres (`filter`) | Créer, importer JSON |
| `/courses/:slug` | — | Détail d'un cours + ses habiletés | Modifier, supprimer |
| `/courses/new` | Nouveau cours | Formulaire | Enregistrer |
| `/courses/:id/edit` | Modifier — `<cours>` | Formulaire | Enregistrer |
| `/courses/:id/essentials` | Habilités - `<cours>` — Habilités du cours | Liste des habiletés | Créer, importer JSON |
| `/essentials/:id` | Habilité : `<nom>` | Détail + exercices rattachés | Modifier, supprimer |
| `/essentials/:id/exercises` | Exercices | Liste de `_exercise_card` | Créer, importer via le moteur de contenu |
| `/exercises/:id` | — | Détail d'un exercice + questions | Modifier |
| `/exercises/new` · `/exercises/:id/edit` | — | Formulaire imbriqué questions / réponses (`_question_fields`, `_answer_fields`, `_questions_list`) | Enregistrer |
| `/drenas` | Drenas — 🏛️ DRENA | Liste des directions régionales | Créer |
| `/drenas/:id` | DRENA : `<nom>` | Détail + écoles rattachées (Stimulus `filter`) | Ajouter une école, importer JSON |
| `/drenas/new` · `/drenas/:id/edit` | — | Formulaire | Enregistrer |
| `/schools` | — Organisation Scolaire | Liste en grille ou en liste, scroll infini | Créer, importer JSON |
| `/schools/:id` | — | Détail + classes de l'établissement | Modifier |
| `/schools/:id/edit` | Modifier l'école — ✏️ Modifier l'école | Formulaire | Enregistrer |
| `/schools/new` | Nouvel Etablissement | Formulaire | Enregistrer |
| `/schools/:id/school_roles` | — Rôles de `<école>` | Liste des rôles | Créer, supprimer |
| `/schools/:id/school_staffs` | — Personnel de `<école>` | Liste du personnel | Ajouter, retirer |
| `/levels` | Niveaux | Référentiel des niveaux | CRUD |
| `/levels/:id` | Niveau `<nom>` | Détail | Modifier, supprimer |
| `/materials` | — Matières | Référentiel des matières | CRUD |
| `/materials/:id` | Matière `<nom>` | Détail | Modifier, supprimer |
| `/series` | — | Référentiel des séries | CRUD |
| `/classrooms` | Classrooms | Liste des classes | — |
| `/classrooms/:id` | Classe : `<nom>` | Détail, onglets, code copiable | Assigner cours / habiletés / exercices |
| `/classrooms/:id/students` | — | Liste paginée des élèves (scroll infini) | — |
| `/messages` | Messages | Carrousel de `messages/_card` (Stimulus `message-carousel`) | Créer, modifier, supprimer, masquer |
| `/messages/new` · `/messages/:id/edit` | Nouveau message / Modifier le message | Formulaire avec **prévisualisation live** (Stimulus `preview`) : titre, image, audio | Enregistrer |
| `/messages/:id` | — | Détail d'un message | — |
| `/users` | — Gestion des utilisateurs | Liste des comptes | Modifier, supprimer |
| `/users/:public_id` · `/edit` | — Modifier le profil | Fiche / formulaire | Enregistrer |
| `/profile/edit` | — Paramètres du compte | Formulaire | Enregistrer |

---

## 4. Les contrôleurs Stimulus

31 fichiers dans `app/javascript/controllers/`, 30 enregistrés dans `index.js` (manifeste
auto-généré par `bin/rails stimulus:manifest:update`). `application.js` monte Turbo Rails,
Trix / ActionText, et le rendu KaTeX sur `turbo:load`.

### 4.1 Vivants

| Contrôleur | Ce qu'il fait | Cibles / valeurs | Sur quels écrans | Usages |
|---|---|---|---|---|
| `carousel` (132 l.) | Défilement horizontal, flèches, points de pagination, **masque la nav si tout tient à l'écran** | `scrollContainer`, `carousel`, `item`, `dot`, `navigation`, `pagination` | Tous les feeds (4 rôles), messages, listes de cours, examens | 18 |
| `modal` (38 l.) | Ouverture / fermeture, clic sur le fond, `stop` sur le panneau | `panel` | `layouts/shared/_support_modal` (4 appels) et modales locales — **pas `components/_modal`, qui est mort** | 16 |
| `toast` (42 l.) | Cycle de vie d'une notification, fermeture manuelle et auto | `element` | Toasts globaux | 10 |
| `dropdown` (85 l.) | Menu contextuel, positionnement, clic extérieur, `Escape` | `menu` | `components/_dropdown`, `_exercise_card`, `teams/dashboard/index` | 10 |
| `math` (27 l.) | Rendu KaTeX sur un sous-arbre | — | Exercices, questions, descriptions de cours | 7 |
| `schools` (73 l.) | Cascade DRENA → école | `drenaSelect`, `schoolSelect` | `teachers/registrations/new:79`, `teachers/prepa_acquisitions/new:50` | 5 |
| `slideover` (41 l.) | Tiroir latéral mobile | `dialog` | Les 4 `_navbar` de rôle (≈ ligne 9-11), en `lg:hidden` | 5 |
| `tabs` (52 l.) | Onglets avec onglet par défaut | `tab`, `panel` ; valeur `defaultTab` | `teams/dashboard/index`, `teams/dashboard/setup`, `classroom/classrooms/show:6`, `schoolstaff/classrooms/show:6` | 5 |
| `read-more` (64 l.) | Repli / dépli de texte, **masque le bouton si pas de débordement** | `content`, `button` | `components/_read_more`, `components/_question_card` | 5 |
| `classroom-selection` (61 l.) | Sélection multiple, cases de groupe, compteur, activation du bouton d'envoi | `checkbox`, `submitBtn`, `counter`, `groupCheckbox` | `classroom/teachers/classrooms/index:6` | 4 (dont 2 dans l'arbre mort) |
| `theme` (51 l.) | Bascule clair / sombre, `localStorage`, icônes | `sunIcon`, `moonIcon` | Les 4 `_navbar` de rôle (≈ ligne 95) — **voir §4.3** | 4 |
| `clipboard` (35 l.) | Copie du code de classe + retour visuel | `source`, `button`, `icon`, `checkIcon` | `classroom/classrooms/show:38`, `schoolstaff/classrooms/show:38` | 3 |
| `confetti` (52 l.) | Animation de réussite | — | `assessment/exercise_sessions/result:6` | 3 |
| `filter` (32 l.) | Recherche live + bascule grille / liste | `form` | `teams/dashboard/_tab_community:4`, `catalog/drenas/show:6` | 3 |
| `checkable` (39 l.) | Sélection d'une réponse avec classe active | `input`, `container` | `assessment/exercise_sessions/_question_card:24` | 3 |
| `redirect` (21 l.) | Redirection différée après un Turbo Stream | valeur `url` | `assessment/exercise_sessions/finish.turbo_stream:7` | 3 |
| `toast-trigger` (34 l.) | Convertit un flash Rails en toast JS | valeurs `type`, `message` | `layouts/_toast_message:16`, `application_helper.rb:44` | 3 |
| `toast-container` (73 l.) | Clone le `<template>`, applique le style par type, empile | — | `layouts/_toast_message:5` | 3 |
| `homepage-student-modal` (37 l.) | Modale « je suis élève » | `modal` | `homepage/index` | 3 |
| `homepage-teacher-modal` (37 l.) | Modale « je suis prof » | `modal` | `homepage/index` | 3 |
| `infinite-scroll` (53 l.) | Charge la page suivante à l'apparition du lien (IntersectionObserver) | `nextPage` | `catalog/courses/index:22`, `classroom/classrooms/students:6` | 2 |
| `preview` (46 l.) | Prévisualisation live titre / image / audio | `titleInput`, `titlePreview`, `imageInput`, `imagePreview`, `audioInput`, `audioStatus` | `messages/_form:4` | 2 |
| `message-carousel` (93 l.) | Carrousel de messages : auto-avance, points, **gestes tactiles** | `track`, `dots` | `messages/index:34` | 2 |
| `install-app` (94 l.) | Bandeau d'installation PWA, `beforeinstallprompt` | valeur `statusUrl` | `layouts/shared/_install_banner:20` | 2 |
| `audio-player` (92 l.) | Lecture / pause d'un extrait audio | `playIcon`, `pauseIcon` | `components/messages/_card:59` | 2 |
| `classrooms` (169 l.) | Bascule « code de classe » / sélection, cascade école → classe | — | `students/registrations/new:62` | 1 |
| `demo-toast` (18 l.) | Déclenche un toast de démonstration | — | `messages/index:6` | 1 |

Les contrôleurs les plus longs implémentent tous `disconnect()` proprement (`carousel`, `dropdown`,
`read-more`, `message-carousel`, `install-app`, `audio-player`, `toast`, `infinite-scroll`).

### 4.2 Morts — aucun `data-controller` correspondant dans les vues

| Contrôleur | Fichier | Constat |
|---|---|---|
| `hello` | `hello_controller.js` (15 l.) | Contrôleur d'exemple généré par Rails, jamais branché |
| `counter` | `counter_controller.js` (42 l.) | **Aucun `data-controller="counter"`.** Le seul `counter` du code est un *target* de `classroom-selection` (`classroom/teachers/classrooms/index:40`), pas ce contrôleur |

### 4.3 Cas particulier — `theme` : branché, sans effet

Le contrôleur `theme` est bien monté (4 boutons dans les navbars de rôle), et le layout contient un
script anti-FOUC qui pose `class="dark"` sur `<html>` (`app/views/layouts/application.html.erb:8-17`,
lecture `localStorage` + `prefers-color-scheme`).

Mais : **0 occurrence de la moindre variante `dark:`** dans `app/views` + `app/javascript`, et le
`@theme` ne définit **aucune palette sombre**. Le mode sombre est entièrement câblé — script,
contrôleur, persistance, icônes soleil/lune — et **n'a aucun effet visuel**.

---

## 5. Les patterns d'interaction

### 5.1 Turbo Frame

**57 fichiers** contiennent un `turbo_frame_tag` (63 occurrences). L'identifiant de frame est presque
toujours calculé par le helper maison `nested_dom_id` (`app/helpers/application_helper.rb:56`), qui
produit des ids composés du type `school_12_classrooms`.

Contre-pattern dominant : **63 occurrences de `data: { turbo_frame: "_top" }`** — autant de liens qui
sortent explicitement du frame courant. Il y a donc exactement autant d'échappements que de frames.

Les frames nommés hors `_top` sont rares et ad hoc :

```
exercise_report_<id>    4×
essential_modal         2×
new_series              1×
new_level               1×
new_drena               1×
community_results       1×
message_card_<id>       1×
```

### 5.2 Turbo Stream

**42 templates `.turbo_stream.erb`**, concentrés sur le CRUD du catalogue (courses, drenas,
essentials, levels, materials, schools, series, classrooms, messages, exercises) et le parcours
d'exercice (`update`, `finish`).

Répartition des actions :

| Action | Occurrences |
|---|---|
| `turbo_stream.update` | 23 |
| `turbo_stream.replace` | 23 |
| `turbo_stream.append` | 21 |
| `turbo_stream.remove` | 13 |
| `turbo_stream.prepend` | 10 |

Le pattern est régulier et reproductible : le stream met à jour la liste, puis fait un
`turbo_stream.append "toast-container"` pour la notification. Exemple type :
`app/views/catalog/series/create.turbo_stream.erb:5`.

**14 occurrences de `turbo: false`** — des formulaires qui désactivent Turbo, tous des formulaires
d'inscription ou de sélection en cascade.

### 5.3 Formulaires

- Les formulaires sont écrits **à la main, champ par champ**. Le composant `components/forms/_field`
  qui devait les unifier est mort.
- **84 appels `f.label`** contre **65 `placeholder:`** — les labels existent majoritairement.
- **Aucun `field_with_errors`** : le wrapper d'erreur de Rails n'est pas stylé.
- Les habillages `.input-ln` et `.label-ln` ne sont employés que **9 fois chacun**.
- 4 formulaires utilisent la syntaxe `has-[:checked]` (11 occurrences) pour styler une carte-choix
  selon l'état de sa case — pattern moderne, mais isolé.

### 5.4 Erreurs de validation — trois mécanismes concurrents

| Mécanisme | Où | Occurrences |
|---|---|---|
| `form_error_notification(object)` — bandeau récapitulatif rouge | `app/helpers/application_helper.rb:24` | **1** |
| Boucle manuelle sur `object.errors.full_messages` dans la vue | vues diverses | **14** |
| `form.object.errors[method].first` sous le champ | dont `components/forms/_field` (mort) | **5** |

Il n'existe **aucune convention unique**. Le helper officiel est le moins utilisé des trois.

### 5.5 États vides

**17 implémentations** (détail en §2.3). Aucune n'est partagée entre contextes bornés, et les deux
composants génériques ont des API incompatibles.

### 5.6 Chargement

| Mécanisme | État |
|---|---|
| Barre de progression Turbo `.turbo-progress-bar` | Stylée (CSS ligne 208) : `bg-primary h-1` + halo `--color-primary-100` |
| `html.turbo-loading body` | CSS ligne 213 : `cursor-wait opacity-80 transition-opacity duration-300`, piloté par les écouteurs `turbo:visit` / `turbo:load` de `application.js` |
| `shared/_loading_state` | Spinner propre, `role="status"`, `aria-live="polite"` — **mort** |
| `animate-pulse` | 20 occurrences, employées comme **décoration** (pastilles de notification), pas comme squelettes |
| Squelettes de chargement | **Aucun** |
| `aria-busy` | **Aucun** |

### 5.7 Confirmations de suppression

**22 `turbo_confirm`**, toujours sous forme de chaîne française en dur dans la vue. Ce sont des
`confirm()` natifs du navigateur — **pas de dialogue personnalisé, pas de piège de focus**.

Libellés relevés :

```
"Supprimer ce message ?"              "Supprimer cette classe ?"
"Supprimer cet exercice ?"            "Supprimer définitivement ce sujet ?"
"Retirer ce sujet ?"                  "Supprimer ce cours ?"
```

### 5.8 Toasts et notifications

**Chaîne vivante** :

```
flash Rails
  └─> layouts/_toast_message         conteneur #toast-container (fixed top-4 right-4 z-50,
      │                              data-turbo-permanent) + <template> de components/_toast
      └─> <div data-controller="toast-trigger">   un par flash, invisible
          └─> toast-container#show   clone le template, applique le style selon le type, empile
              └─> toast              cycle de vie, fermeture
```

Les Turbo Streams peuvent aussi injecter directement dans `#toast-container` (21 `append`).

**Limite structurelle** : le mapping des types est réducteur. `application_helper.rb:39` et
`layouts/_toast_message.html.erb:13` ne connaissent que :

```
notice → success
tout le reste → danger
```

Le helper `flash_class` (`application_helper.rb:67`) sait pourtant produire `success`, `danger`,
`warning` et `info` — mais il ne sert que dans `shared/_flash`, qui est mort. Et il y renvoie des
chaînes (`"success"`, `"danger"`) qui **ne sont pas des classes Tailwind valides**.
Les variantes `warning` et `info` du toast sont donc **inatteignables**.

### 5.9 Navigation et layouts

**Un seul layout applicatif** : `app/views/layouts/application.html.erb`, plus `mailer.html.erb` et
`mailer.text.erb`.

Structure (lignes 56 à 102) :

```
body (classes calculées par body_classes)
 ├─ 1. toast container                    layouts/_toast_message
 ├─ 2. header sticky h-14 lg:h-16 z-50    si show_header?      data-turbo-permanent
 ├─ 3. aside fixe w-72, hidden lg:flex    si show_sidebar?     data-turbo-permanent
 ├─ 4. main (lg:ml-72 si sidebar, pb-20 lg:pb-0 si bottom nav)
 │      └─ max-w-5xl mx-auto  OU  pleine largeur si content_for?(:full_width)
 ├─ 5. bottom nav fixe, lg:hidden z-40    si show_bottom_nav?  data-turbo-permanent
 ├─ 6. #modal-container z-[60] aria-live="polite"
 └─ 7. bandeau PWA                        si current_user.should_see_install_banner?
```

La variation par rôle passe par **trois dispatchers** qui font un `case current_user_role` sur
`:student`, `:teacher`, `:team`, `:school_admin` :

```
layouts/_header_dispatcher      → layouts/shared/<rôle>/_navbar
layouts/_sidebar_dispatcher     → layouts/shared/<rôle>/_sidebar
layouts/_bottom_nav_dispatcher  → layouts/shared/<rôle>/_bottom_navbar
```

Chaque rôle a donc **4 partials de chrome** (navbar, sidebar, drawer, bottom nav) → **16 fichiers**
dans `app/views/layouts/shared/<rôle>/`. Le mécanisme est propre ; en revanche **aucun de ces
16 fichiers ne partage de brique commune** — chaque lien de navigation est réécrit à la main.

L'affichage conditionnel est piloté par `LayoutHelper` (`app/helpers/layout_helper.rb`) :
`show_header?`, `show_sidebar?` et `show_bottom_nav?` dérivent tous de `hide_layout_components?`,
qui masque tout sur la racine ou hors connexion.

**Incohérence de couverture entre desktop et mobile** :

| Rôle | Destinations sidebar | Destinations bottom nav |
|---|---|---|
| `student` | 4 (Accueil, Découvre, École, Raccourcis) | **2** |
| `teacher` | 4 (Accueil, Découvre, Classes, Raccourcis) | **2** |
| `team` | 6 (Accueil, Messages, Cours, Panel Admin, Dashboard, LnclassAI) | **1** |
| `school_admin` | 4 (Accueil, Classes, Enseignants, Élèves) | **4** ✓ |

**Largeur de contenu** : le layout impose `max-w-5xl` par défaut (ligne 82), sauf `content_for
:full_width`. Mais les vues posent ensuite leurs propres conteneurs — **14 valeurs distinctes** :

```
max-w-7xl  21×     max-w-md    14×     max-w-none  9×     max-w-xl       2×
max-w-sm   20×     max-w-xs    12×     max-w-3xl   5×     max-w-[1400px] 1×
max-w-5xl  17×     max-w-lg    12×                        max-w-[120px]  1×
max-w-2xl  15×     max-w-full  12×     max-w-4xl   11×
```

À noter : la ligne 82 contient `lg:px-4 lg:px-8` — deux classes de padding contradictoires sur le
même point de rupture, dont seule la seconde s'applique.

### 5.10 Responsivité

L'approche est **mobile-first et réelle**, mais réduite à trois points de rupture utiles :

| Préfixe | Occurrences |
|---|---|
| `sm:` | 461 |
| `lg:` | 245 |
| `md:` | 123 |
| `xl:` | 7 |
| `2xl:` | **0** |

`lg:` est le **pivot structurel** : sidebar en `hidden lg:flex`, bottom nav en `lg:hidden`, flèches de
carrousel en `hidden lg:flex`, décalage du contenu en `lg:ml-72`. On compte 20 `lg:hidden` et
33 `hidden lg:`. `md:` est peu employé, et `xl:` / `2xl:` sont quasi absents — **aucun traitement des
très grands écrans**.

Points faibles factuels :

- **`min-h-[44px]`** (cible tactile de 44 px) apparaît **14 fois seulement**, et en valeur arbitraire
  plutôt qu'en token.
- **Aucune gestion de safe-area.** La classe `safe-pb` posée sur la bottom nav
  (`app/views/layouts/application.html.erb:90`) **n'est définie nulle part**, et il y a
  **0 occurrence de `env(safe-area-inset-*)`** dans tout le CSS. Sur iPhone à encoche, la barre de
  navigation basse passe sous l'indicateur système.
- L'application se déclare pourtant **PWA installable** : `manifest.json.erb`, `service-worker.js`,
  `apple-mobile-web-app-capable`, `mobile-web-app-capable`, `theme-color`, bandeau d'installation et
  contrôleur `install-app`.

### 5.11 Accessibilité

**Ce qui est présent**, compté sur `app/views` :

| Attribut | Occurrences |
|---|---|
| `aria-label` | 41 |
| `aria-hidden` | 35 |
| `role=` | 15 |
| `sr-only` | 9 |
| `aria-expanded` | 8 |
| `aria-live` | 2 |
| `aria-modal` | 1 |
| `aria-selected` | 1 |
| `aria-controls` | **0** |
| `aria-current` | **0** |
| `aria-describedby` | **0** |
| `tabindex` | **0** |
| `alt=` | **1** |

**Ce qui est bien fait** :

- `components/_modal` : `role="dialog"` + `aria-modal="true"` + `aria-labelledby` lié au titre.
- `components/_dropdown` : `aria-haspopup="menu"` + `aria-expanded`, contrôleur gérant `Escape` et le clic extérieur.
- `shared/_error_state` : `role="alert"`.
- `shared/_loading_state` : `role="status"` + `aria-live="polite"` + texte `sr-only`.
- `components/messages/_card` : `role="article"` + `aria-label` sur la carte et sur le bouton fermer.
- `components/carousels/_navbar` : `aria-label="Précédent"` / `"Suivant"`.
- `#modal-container` du layout : `aria-live="polite"`.

**Ce qui manque** :

- **Un seul `alt=` dans 316 vues.** Les images n'ont pas de texte alternatif.
- **Aucun `aria-current`** : l'état actif de la navigation est purement visuel (couleur + graisse, via
  les 3 helpers `*_nav_link_class`).
- **Aucun `aria-controls`** : les onglets (5 usages de `tabs`) et les dropdowns ne relient pas
  déclencheur et panneau. Un seul `aria-selected` dans tout le projet.
- **48 `focus:outline-none` pour seulement 19 fichiers contenant aussi un `focus:ring`** : sur environ
  60 % des cas, le contour de focus est supprimé **sans remplacement**. On compte 205 `focus:ring`
  mais seulement 20 `focus-visible` — l'anneau s'affiche donc aussi au clic à la souris.
- Les **824 emojis** servant d'icônes ne sont pas masqués aux lecteurs d'écran (`aria-hidden`).
- Les confirmations de suppression reposent sur `confirm()` natif — pas de piège de focus personnalisé.
- **0 `tabindex`** : aucun ordre de tabulation explicite, aucun élément non natif rendu focusable.

### 5.12 Internationalisation

La règle d'or n° 3 de `CLAUDE.md` impose `t(".key")` avec `:fr` comme locale par défaut.

| Mesure | Résultat |
|---|---|
| `t(".key")` dans `app/views` | **0** |
| `t("clé.absolue")` dans `app/views` | 2 |
| Chaînes françaises en dur dans le balisage (échantillon sur textes accentués entre balises) | ~432 |
| `page_title` avec libellé en dur | 45 |
| `turbo_confirm` avec message en dur | 22 |

**Il n'existe aucune couche i18n dans les vues.** Tout le texte d'interface est écrit en dur dans
l'ERB.

---

## 6. Le verdict

### 6.1 À garder tel quel

1. **Le mécanisme de dispatch de layout par rôle.**
   `layouts/_header_dispatcher`, `_sidebar_dispatcher`, `_bottom_nav_dispatcher` + `LayoutHelper` :
   un seul layout, une variation propre sur `current_user_role`, des zones `data-turbo-permanent`
   bien placées. Le mécanisme est bon ; ce sont les 16 partials qu'il appelle qui sont à unifier.

2. **La chaîne de toasts.**
   `_toast_message` → `<template>` → `toast-trigger` → `toast-container` est un vrai système : un
   point d'entrée unique depuis les flash Rails comme depuis les Turbo Streams, un conteneur
   `data-turbo-permanent` qui survit aux navigations, une file d'attente. Seul le mapping des types
   (2 au lieu de 4) est à corriger.

3. **Les contrôleurs Stimulus à forte valeur.**
   `carousel` (132 l., pagination et masquage automatique de la nav), `dropdown` (85 l.,
   positionnement + `Escape` + clic extérieur), `read-more` (64 l., détecte le débordement avant
   d'afficher le bouton), `message-carousel` (93 l., auto-avance + gestes tactiles),
   `infinite-scroll`, `install-app`, `clipboard`, `preview`. Bien écrits, `disconnect()` propre,
   transposables tels quels.

4. **`components/courses/_course_card.html.erb`.**
   Le seul composant qui applique fidèlement `.interface-design/system.md` : élévation au survol
   (`-translate-y-1.5`, `duration-300 ease-out`), badge matière coloré par `subject_palette_for`, pas
   de bordure dure, épuration des informations secondaires. C'est le modèle de carte à généraliser.

5. **La trilogie `shared/_empty_state` / `_error_state` / `_loading_state`.**
   Sémantique correcte (`role="alert"`, `role="status"`, `aria-live`, `sr-only`), API par
   `local_assigns` lisible, repli sur des valeurs par défaut françaises. Deux sur trois sont morts —
   mais le code est le bon point de départ.

6. **Le `@theme` comme structure.**
   Le découpage typographie / couleurs / rayons / animations est le bon squelette, et les valeurs de
   rayon correspondent effectivement à l'usage réel (`--radius-ln` = `rounded-xl`, `--radius-card` =
   `rounded-2xl`). Il est simplement incomplet (ni espacements, ni ombres, ni échelle `primary`
   complète, ni palette sombre) et non appliqué.

7. **`subject_palette_for`** (`app/helpers/application_helper.rb:294-329`).
   13 motifs de reconnaissance de matière + un repli, chacun fournissant `icon`, `bg`, `text`,
   `gradient`. C'est une vraie table de correspondance métier → design, à convertir en tokens.

8. **L'approche mobile-first sur le pivot `lg:`.**
   Sidebar desktop / bottom nav mobile est une décision claire, tenue dans tout le code.

9. **Le pattern Turbo Stream du CRUD catalogue.**
   `update` de la liste + `append` au `#toast-container` : régulier sur 42 templates, reproductible
   tel quel.

### 6.2 À unifier

1. **Les 17 états vides** → un composant unique.
   Arbitrage préalable obligatoire : `components/_empty_state` attend `action: {text:, href:}`,
   `shared/_empty_state` attend `cta_text:` + `cta_url:`. Les deux API sont incompatibles.
   280 lignes à ramener à une.

2. **Les ~1 200 lignes de partials de feed déclinés par rôle** → une section de feed paramétrée.
   Les 11 intentions (`_activities`, `_messages`, `_levels`, `_courses`, `_examens`,
   `_examen_dashboard`, `_feed_header`, `_dashboard`, `_placeholder_image`, `_empty_state`,
   `_carousel_nav`) sont les mêmes d'un rôle à l'autre ; seuls les données et quelques libellés
   changent.

3. **Les 6 navigations de carrousel** → `components/carousels/_navbar` seul.
   Les versions `teachers` et `schoolstaff` sont déjà identiques au bit près.

4. **Les 2 cartes d'établissement**, appelées depuis le même écran.
   La version `catalog/schools/_school_card` (110 l.) est la plus complète — cache, turbo_frame,
   modes grille et liste — contre `components/schools/_school_card` (51 l.) qui n'a rien de tout cela.

5. **Les 4 systèmes d'import JSON** → un composant unique de dépôt de fichier.
   Trois génériques morts, deux implémentations locales vivantes.

6. **Les 16 partials de chrome par rôle** → une navigation pilotée par une liste de destinations.
   Objectif mesurable : que la bottom nav couvre la même arborescence que la sidebar pour les
   4 rôles — aujourd'hui seul `school_admin` est cohérent (4 vs 4), contre 2 vs 4 pour `student` et
   `teacher`, et 1 vs 6 pour `team`.

7. **Les 3 helpers de lien de navigation** (`application_helper.rb:98-116`) → un seul, avec
   `aria-current` au passage.

8. **Les 3 mécanismes d'erreur de validation** (bandeau 1×, boucle `full_messages` 14×, message sous
   le champ 5×) → un seul, porté par un composant de champ.

9. **Les 3 iconographies concurrentes** : 824 emojis, 138 `heroicon`, 8 générateurs SVG inline
   (51 hex en dur). À ramener à un système, avec `aria-hidden` systématique.

10. **L'échelle des rayons** : 19 valeurs distinctes pour 3 tokens définis.

11. **Les 3 définitions concurrentes de « l'ombre de carte »** (`.card-ln` dans le CSS,
    `.interface-design/system.md`, et les valeurs arbitraires des vues).

12. **La largeur de contenu** : 14 valeurs de `max-w-*` en aval d'un `max-w-5xl` posé par le layout.

13. **Les 2 cartes de question** (`components/_question_card` mort, `assessment/…/_question_card`
    vivant).

### 6.3 À refaire

1. **La palette.**
   Les tokens sont minoritaires (~1 000 usages) face à la palette Tailwind par défaut (3 659). Le
   fichier `.interface-design/system.md` prescrit lui-même `slate`/`blue`, **en contradiction directe
   avec le `@theme`**. Deux palettes concurrentes, aucun arbitrage. C'est la décision fondatrice du
   nouveau design system.

2. **L'échelle `primary`.**
   34 classes `primary-300/500/600/700` ne produisent **aucun style**, faute de tokens — y compris
   sur le lien « Retour » global et sur l'état de sélection d'une réponse d'exercice.

3. **Les 5 variables CSS jamais définies**
   (`--color-text-primary`, `--color-text-secondary`, `--color-text-tertiary`, `--color-bg-main`,
   `--color-bg-paper`). Elles cassent visuellement **8 des composants de `app/views/components/`**,
   dont `_page_header` (titre sans couleur) et `_modal` (panneau sans fond).

4. **La bibliothèque `app/views/components/`.**
   6 des 23 composants sont morts, dont la modale et le champ de formulaire — les deux briques les
   plus structurantes. Les 17 vivants s'appuient à moitié sur des variables inexistantes et sur une
   classe `btn-ln` fantôme. **À reconstruire, pas à réparer.**

5. **`app/views/teachers/classrooms/`** — 10 fichiers, copie à l'octet près de
   `app/views/classroom/teachers/classrooms/` vers lequel pointent les routes. À supprimer.

6. **Les 22 autres partials morts** (§2.4), plus `shared/_flash`, `shared/_error_state`,
   `shared/_loading_state`, et les contrôleurs Stimulus `hello` et `counter`.

7. **Le mode sombre.**
   Entièrement câblé — script anti-FOUC, contrôleur `theme`, 4 boutons de bascule, persistance
   `localStorage`, icônes soleil/lune — et **0 variante `dark:`**, aucune palette sombre dans le
   `@theme`. Soit on l'implémente, soit on retire les 4 boutons.

8. **L'internationalisation.**
   0 usage de `t(".key")` contre ~500 chaînes en dur dans les vues, alors que c'est une règle d'or
   du projet (`CLAUDE.md` § Les règles d'or, point 3). La réécriture est le bon moment.

9. **`/teachers/dashboard`** (`app/views/teachers/dashboard/index.html.erb`) : écran de scaffold
   Rails jamais implémenté (`<h1>Teachers::Dashboard#index</h1>` + « Find me in… »), pourtant routé
   dans `config/routes.rb:130`.

10. **`/teams/lnclassai`** (`app/views/teams/dashboard/lnclassai.html.erb:4`) : un `<iframe>` vers un
    artifact `claude.site` externe en guise de fonctionnalité produit.

11. **Le focus visible.**
    48 `focus:outline-none` dont ~60 % sans `focus:ring` de remplacement ; 205 `focus:ring` pour
    seulement 20 `focus-visible`. La navigation au clavier est invisible sur une grande partie de
    l'interface, et l'anneau s'affiche au clic souris là où il existe.

12. **Les textes alternatifs d'images** : **1 seul `alt=` dans 316 vues**.

13. **La safe-area mobile.**
    `safe-pb` invoquée sur la bottom nav n'existe pas ; 0 `env(safe-area-inset-*)` dans le CSS ;
    `min-h-[44px]` seulement 14 fois. Le tout pour une application qui se déclare PWA installable.

14. **Les 559 valeurs arbitraires et 74 hex en dur**, dont 93 `text-[10px]` (plus fréquent que
    `text-base`) et `#0066ff` recopié à la main à 3 endroits alors qu'il est déjà `--color-primary`.

15. **Les états de chargement.** Aucun squelette, aucun `aria-busy` ; `animate-pulse` détourné en
    décoration ; le seul composant prévu (`shared/_loading_state`) est mort.

---

## Annexe — Fichiers de référence pour la construction du design system

| Besoin | Fichier |
|---|---|
| Les tokens actuels | `app/assets/stylesheets/application.tailwind.css` lignes 16-58 (`@theme`) |
| Les composants CSS actuels | `app/assets/stylesheets/application.tailwind.css` lignes 96-202 (`@layer components`) |
| La philosophie visuelle déclarée (en contradiction partielle avec le `@theme`) | `.interface-design/system.md` |
| Le châssis de layout à conserver | `app/views/layouts/application.html.erb` + `app/helpers/layout_helper.rb` + les 3 dispatchers |
| Le modèle de carte à généraliser | `app/views/components/courses/_course_card.html.erb` |
| La table matière → design | `app/helpers/application_helper.rb:294-329` (`subject_palette_for`) |
| Les icônes de matière et de niveau (51 hex en dur) | `app/helpers/application_helper.rb:120-292` |
| La bibliothèque à reconstruire | `app/views/components/` (23 fichiers) |
| Le système de notification à reprendre | `app/views/layouts/_toast_message.html.erb` + `app/views/components/_toast.html.erb` + `toast*_controller.js` |
| La carte des routes | `config/routes.rb` |
