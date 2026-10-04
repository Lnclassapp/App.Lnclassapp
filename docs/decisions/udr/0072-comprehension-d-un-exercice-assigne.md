# UDR-0072 : Compréhension d'un exercice assigné — badges et cercle au bord bas de l'exercice, section « Compréhension » du suivi

| | |
|---|---|
| **Statut** | Accepté (2026-10-04, porteur, avec le plan du chantier) |
| **Date** | 2026-10-04 |
| **Chantier** | [`docs/chantiers/rapports-exercices`](../../chantiers/rapports-exercices/prd.md) |
| **ADR lié** | [ADR-0079](../adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md) (règles de lecture) · [ADR-0072](../adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) (« fait », policy de suivi) · [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (seuils, badges) |
| **Amende** | [UDR-0062](0062-echeances.md) §3.4 (ligne d'un exercice assigné sur la page classe) et §3.5 (page de suivi) |
| **Remplacé par** | — |

---

## 1. Contexte

Sur la page de sa classe, l'enseignant voit pour chaque exercice assigné son échéance et « 18 faits, dont 3 en retard · 7 pas encore faits » (UDR-0062). Il ne sait pas si l'exercice a été compris, ni qui progresse. Pour l'apprendre, il devrait ouvrir chaque copie, ce qu'il ne fait pas.

Le porteur demande (2026-10-04) :
- trois couleurs par élève : rouge pour « En difficulté », jaune pour « Fragile », vert pour « Acquis » ;
- un cercle de la couleur dominante ;
- au clic sur une catégorie, le taux de réussite des questions ;
- au **bord bas de l'exercice**, les **badges à gauche** et la **statistique à droite, isolée** ;
- un signe de progrès : progrès, stagne, en baisse.

## 2. Décision

1. **L'information vient à l'enseignant là où il passe.** Elle se place sur la ligne d'exercice de la page classe, sous l'échéance et les faits, et non sur une page de rapport qu'il devrait chercher. Le cercle reste gris tant que moins de 5 élèves ont fait l'exercice : une couleur ne s'affiche que quand elle veut dire quelque chose.
2. **Le détail est une section de la page de suivi**, pas un écran de plus. Cette page est déjà le lieu de l'exercice assigné et elle nomme déjà des élèves sous la même policy. La section s'insère sous les trois chiffres.
3. **Les catégories sont des liens dans un Turbo Frame**, pas des onglets JavaScript. La catégorie vit dans l'adresse (`?category=`) : la page se recharge et se partage sans perdre le choix, et marche sans JavaScript.
4. **Couleur et texte toujours ensemble.** Le cercle n'est jamais seul : la catégorie est écrite à côté (charte §14, R6).
5. **Chaque lecture appelle un geste**, selon la mission de Lnclass : aider chaque acteur à progresser (porteur, 2026-10-04). La section marque la question à reprendre en classe, montre ce que la classe a appris entre le premier et le meilleur essai, et place en tête les élèves qui ont besoin de l'enseignant.
6. **Trois couleurs propres à la compréhension**, nouvelles et réservées aux écrans enseignant. L'ambre reste l'urgence (charte §5) : la ligne affiche déjà une échéance en retard en ambre, le jaune « Fragile » ne doit pas s'y confondre. Le vert « Acquis » est le vert « réussi » existant.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Tokens (Lot 0)

Dans `app/assets/stylesheets/application.tailwind.css`, bloc `@theme`, sous « Couleurs d'état » :

```css
  /* Compréhension d'un exercice (UDR-0072) — écrans enseignant seulement, jamais une note d'élève */
  --color-struggling: #c8322b;
  --color-struggling-soft: #fdecea;
  --color-fragile: #e0a800;
  --color-fragile-soft: #fff8d2;
```

Mode sombre, dans **les deux** blocs existants (`:root:not([data-theme="light"])` sous `prefers-color-scheme: dark`, et `:root[data-theme="dark"]`) :

```css
    --color-struggling: #ff7b72;
    --color-struggling-soft: #3d2023;
    --color-fragile: #facc15;
    --color-fragile-soft: #3a3214;
```

- « Acquis » utilise `--color-success` et `--color-success-soft`, déjà définis dans les deux thèmes.
- « Pas encore lisible » utilise `--color-line` (fond) et `--color-mute` (texte).
- Ces couleurs ne colorent que des **pastilles et des barres**. Tout texte reste en `text-ink` ou `text-mute` : le jaune ne porte jamais de texte.
- `test/design/dark_mode_test.rb` couvre les quatre nouveaux tokens.

### 3.2 Helper (Lot 0) — `Assessment::ComprehensionHelper`

Fichier `app/helpers/assessment/comprehension_helper.rb`. Aucune vue ne choisit elle-même une couleur, une icône ou un libellé de catégorie ou de signe.

| Méthode | Retour |
|---|---|
| `comprehension_dot_class(category)` | `:struggling` → `bg-struggling` · `:fragile` → `bg-fragile` · `:acquired` → `bg-success` · `nil` → `bg-line` |
| `comprehension_soft_class(category)` | `bg-struggling-soft` · `bg-fragile-soft` · `bg-success-soft` · `bg-mist` |
| `comprehension_label(category)` | `t("assessment.comprehension.categories.#{category}")` : « En difficulté », « Fragile », « Acquis » ; `nil` → « Pas encore lisible » |
| `trend_icon(trend)` | `:progress` → `arrow-trending-up` · `:decline` → `arrow-trending-down` · `:stable` et `:stagnant` → `arrow-long-right` · `nil` → `nil` (pas d'icône) |
| `trend_label(trend)` | « En progrès » · « En baisse » · « Stable » · « Stagne » ; `nil` → « 1 session » |
| `comprehension_badge_class(level, count)` | teinte de l'icône d'un palier (§3.3) ; `text-line` si `count` vaut 0 |

Une catégorie ou un signe inconnu lève `KeyError` : jamais de gris silencieux.

### 3.3 Partiels partagés (Lot 0) — `app/views/assessment/comprehension/`

**`_circle.html.erb`** — `locals: (category:, done:, present:, size: :sm)`
- Conteneur : `span.inline-flex.items-center.gap-2`.
- Pastille : `span` ronde (`rounded-full`), `aria-hidden="true"`, classe `comprehension_dot_class(category)`. Taille `:sm` = `size-4`, `:lg` = `size-14`.
- Texte : `span.text-sm.text-ink` « <libellé> · 18/25 », c'est-à-dire `comprehension_label(category)`, puis « · », puis `t("assessment.comprehension.done_ratio", done:, present:)`. Le ratio est en `tabular-nums`. En `:lg`, le libellé passe en `font-display text-xl font-extrabold` et le ratio va dessous, en `text-sm text-mute`.
- `category` vaut `nil` sous 5 faits (`Comprehension.readable?`).

**`_badge_counts.html.erb`** — `locals: (counts:)` (`{ bronze:, silver:, gold:, diamond: }`, entiers)
- `ul.flex.items-center.gap-3`, `aria-label` = « Badges de la classe ».
- Une `li` par palier, **toujours les quatre**, dans l'ordre Bronze, Argent, Or, Diamant :
  - `ui_icon "trophy", variant: :mini, size: :sm`, `aria-hidden` ;
  - le nombre en `text-sm tabular-nums` ;
  - un `span.sr-only` qui dit le palier : « 3 Bronze ».
- Couleur de l'icône : `text-warning` pour le Bronze, `text-mute` pour l'Argent, `text-gold` pour l'Or, `text-info` pour le Diamant. Ce sont les tons existants de `BadgesHelper::BADGE_LEVEL_TONES`, appliqués à l'icône seule.
- Un palier à 0 : icône et nombre en `text-line`, `sr-only` « 0 Bronze ». Le nombre visible est `aria-hidden` : le `sr-only` le dit déjà. Le Bronze n'est jamais omis (défaut AS-25 de l'ancienne application).

### 3.4 Page classe — bord bas d'un exercice assigné (Lot A, amende UDR-0062 §3.4)

Fichier `app/views/classroom/classrooms/_assigned_exercises.html.erb`. **Seulement quand `counts` est présent** (policy de suivi), comme les comptes.

- La `li` garde sa structure : lien étiré, flèche à droite.
- Sous la ligne de résumé « N faits… », on ajoute un pied :
  - `div.mt-3.flex.items-center.justify-between.gap-4.border-t.border-line.pt-3` ;
  - **gauche** : `render "assessment/comprehension/badge_counts", counts: assignment.comprehension.badge_counts` ;
  - **droite**, isolé par le `justify-between` : `render "assessment/comprehension/circle", category: assignment.comprehension.category, done: counts.done, present: counts.done + counts.pending`.
- Le pied est dans la zone du lien étiré : toute la ligne mène à la page de suivi, sans second lien. Le pied ne contient aucun élément interactif.
- Le `div` du pied porte `class="relative"` seulement s'il doit passer au-dessus du lien. Ce n'est pas le cas ici.
- Sur téléphone, le pied reste sur une ligne : badges à gauche, cercle à droite. Sous 360 px, le ratio peut passer sous la pastille (`flex-wrap` sur le partiel `_circle`).
- **Équipe** : identique.
- **Sans `counts`** : ni pied, ni badges, ni cercle.

### 3.5 Page de suivi — section « Compréhension » (Lot B, amende UDR-0062 §3.5)

Fichier `app/views/classroom/assignment_follow_ups/show.html.erb`. On ajoute `render "assessment/comprehension/section", comprehension: @comprehension, classroom: @classroom, assignment_public_id: @follow_up.public_id` **entre** la carte d'en-tête (avec ses trois chiffres) et la liste des rendus en retard. Rien d'autre ne change sur la page.

**`app/views/assessment/comprehension/_section.html.erb`**

```
section#comprehension [aria-labelledby=comprehension_title] .mb-8
  h2#comprehension_title  « Compréhension »   (font-display text-xl font-extrabold, mb-4)
  turbo-frame#comprehension_frame [data-turbo-action=advance] .block.transition-opacity.aria-busy:opacity-50
    ─ état vide, OU :
    ui_card padding: :md
      div.flex.flex-col.gap-4.sm:flex-row.sm:items-center.sm:justify-between
        render _circle, size: :lg
        p#comprehension_trends .text-sm   (synthèse des signes)
      p.mt-4.text-sm.text-mute   (avertissement < 5, seulement si non lisible)
    nav [aria-label="Catégories"] .mt-6.grid.grid-cols-3.gap-2
      a × 3   (une par catégorie)
    div#comprehension_panel .mt-6.space-y-8
      section [aria-labelledby=comprehension_questions_title]  h3 « Questions »  + ol
      section [aria-labelledby=comprehension_students_title]   h3 « Élèves »     + ul
```

**Synthèse des signes** (`#comprehension_trends`) :
- Trois groupes séparés par « · » : « 8 en progrès », « 7 sans évolution », « 3 en baisse ».
- Chaque groupe est précédé de son icône `trend_icon` (`mini`, `aria-hidden`) et écrit en `tabular-nums`.
- Si aucun élève n'a deux essais, la phrase est remplacée par « Pas encore de progrès à lire : chaque élève n'a fait qu'un essai. »

**Avertissement sous 5 faits** : « Moins de 5 élèves ont fait l'exercice : la tendance n'est pas encore fiable. » Le détail reste affiché.

**Catégories** (`nav`) — trois liens, dans l'ordre En difficulté, Fragile, Acquis :
- Adresse : `classroom_assignment_path(classroom.public_id, assignment_public_id, category:)`. Le frame remplace son seul contenu, et `data-turbo-action="advance"` met l'adresse à jour. Sans JavaScript, la page entière se recharge avec la catégorie.
- Contenu de chaque lien :
  - `div.flex.flex-col.items-center.gap-1.rounded-ln.border.px-2.py-3.text-center`, de 48 px de haut au moins ;
  - une pastille `size-3 rounded-full` `comprehension_dot_class`, `aria-hidden` ;
  - le libellé en `text-sm font-medium` ;
  - le nombre d'élèves en `font-display text-2xl font-extrabold tabular-nums`.
- Lien choisi : `aria-current="true"`, fond `comprehension_soft_class(category)`, `border-transparent`. Les autres : `bg-white border-line hover:bg-mist`. Focus : `focus-visible:outline-2 focus-visible:outline-brand`.
- Catégorie choisie par défaut : `comprehension.selected`, fourni par la query (dominante, ou « En difficulté » sans élève).

**Questions** (`ol`, `divide-y divide-line rounded-card border border-line bg-white shadow-card`) — une `li` par question de l'exercice, dans l'ordre de l'exercice, `flex items-center gap-3 px-4 py-3 sm:px-5` :
- « Q1 » en `w-8 shrink-0 font-display font-extrabold text-mute tabular-nums` ;
- l'énoncé en texte brut, `min-w-0 flex-1 line-clamp-2 text-sm text-ink` ;
- à droite, `w-28 shrink-0`, une barre `h-2 rounded-full bg-mist` dont le remplissage a pour largeur le taux et pour couleur `comprehension_dot_class(Grading.mastery_for(taux))`, puis le taux « 50 % » en `text-sm tabular-nums text-ink` ;
- sans tentative : « — » et pas de barre.
- **Progrès** : si `first_rate` est présent et différent du taux, sous le taux à droite, `text-xs text-mute tabular-nums` : « 1re session : 20 % ».
- **À reprendre** : si `to_revisit`, sous l'énoncé, `ui_badge t(".to_revisit"), tone: :brand, size: :sm, icon: "arrow-path"` : « À reprendre en classe ». Le bleu de la marque dit l'action, jamais l'ambre de l'urgence.
- La barre est `aria-hidden`. Le taux écrit suffit : l'`aria-label` de la `li` est « Question 1 : 50 % de réussite », complété par « , 20 % à la première session » et « , à reprendre en classe » quand c'est le cas.

**Élèves** (`ul`, même carte) — une `li` par élève de la catégorie, **dans l'ordre fourni par la query** (ADR-0079 §4.7 : en baisse, stagne, un seul essai, stable, en progrès, puis par nom), `flex items-center justify-between gap-3 px-4 py-3 sm:px-5` :
- gauche : le nom, `min-w-0 truncate font-medium` ;
- droite, `shrink-0 flex items-center gap-3 text-sm` : le meilleur score « 85 % » (`tabular-nums`), puis le signe, avec l'icône `trend_icon` (`mini`, `aria-hidden`) et `trend_label` en `text-mute`.
- Les lignes ne sont pas des liens : la fiche élève (CL-13) n'est pas encore là.

### 3.5 bis Page de suivi — élèves pas encore faits (Lot B, amende UDR-0062 §3.5)

Décision du porteur (2026-10-04, ADR-0079 §4.8). Dans `app/views/classroom/assignment_follow_ups/show.html.erb`, **après** la liste des rendus en retard (ou à sa place si elle n'existe pas) :

- `section#pending_students [aria-labelledby=pending_students_title]`, avec `h2#pending_students_title` « Pas encore faits · 7 » en `mb-4 font-display text-xl font-extrabold`, où le nombre est `t("assessment.comprehension.pending.title", count:)`.
- Une `ul`, avec la même carte que les rendus en retard (`divide-y divide-line rounded-card border border-line bg-white shadow-card`). Chaque `li` contient le nom seul, `px-4 py-3 sm:px-5 truncate font-medium`, trié par nom. Les lignes ne sont pas des liens.
- Aucun élève en attente : la section est **absente**. Le chiffre « Pas encore faits : 0 » de la carte d'en-tête suffit.
- Aucun identifiant d'élève dans le HTML, comme pour les rendus en retard.

### 3.6 États obligatoires

| État | Où | Rendu |
|---|---|---|
| **Vide** (0 fait) | section | `ui_empty_state title: « Personne n'a encore fait cet exercice. », description: « La compréhension s'affiche dès le premier exercice rendu. », icon: "chart-pie"` à la place de la carte, des catégories et du panneau |
| **Vide** (0 fait) | page classe | badges tous à 0, cercle gris « Pas encore lisible · 0/25 » |
| **Catégorie vide** | panneau | `ui_empty_state title: « Aucun élève dans cette catégorie. », icon: "user-group"` à la place des deux listes |
| **Non lisible** (1 à 4 faits) | page classe | cercle gris « Pas encore lisible · 4/25 » |
| **Non lisible** (1 à 4 faits) | section | cercle gris, avertissement, détail affiché |
| **Chargement** | frame | `aria-busy` posé par Turbo → `opacity-50` ; aucun squelette (réponse < 100 ms, ADR-0067) |
| **Erreur** | — | Celles de la page : 403 (policy), 404 (assignation archivée ou inconnue). Une `category` inconnue n'est pas une erreur : elle est ignorée |
| **Succès** | — | Rendus décrits aux §3.4 et §3.5 |
| **Classe archivée** | — | Tout est lisible, sans changement |

### 3.7 Libellés — `config/locales/assessment/comprehension.fr.yml` (Lot 0)

`assessment.comprehension` :
- `categories` :
  - `struggling` : « En difficulté » ;
  - `fragile` : « Fragile » ;
  - `acquired` : « Acquis » ;
  - `unreadable` : « Pas encore lisible ».
- `trends` :
  - `progress` : « En progrès » ;
  - `decline` : « En baisse » ;
  - `stable` : « Stable » ;
  - `stagnant` : « Stagne » ;
  - `single` : « 1 session » (vocabulaire de l'UDR-0007 : « essai » est interdit à l'écran).
- `done_ratio` : « %{done}/%{present} ».
- `badges_label` : « Badges de la classe ».
- `badge_count` : « %{count} %{level} ».
- `section` :
  - `title` : « Compréhension » ;
  - `categories_label` : « Catégories » ;
  - `questions_title` : « Questions » ;
  - `students_title` : « Élèves » ;
  - `question_label` : « Question %{number} : %{rate} de réussite » ;
  - `question_number` : « Q%{number} » ;
  - `no_attempt` : « — » ;
  - `first_rate` : « 1re session : %{rate} » ;
  - `first_rate_label` : « , %{rate} à la première session » ;
  - `to_revisit` : « À reprendre en classe » ;
  - `to_revisit_label` : « , à reprendre en classe ».
- `trends_summary` (imbriqué : une clé YAML ne peut être à la fois une phrase et un groupe de pluriels) :
  - `sentence` : « %{progress} · %{flat} · %{decline} » ;
  - `progress` : `one`/`other` « %{count} en progrès » ;
  - `flat` : `one`/`other` « %{count} sans évolution » ;
  - `decline` : `one`/`other` « %{count} en baisse ».
- `no_trend` : « Pas encore de progrès à lire : chaque élève n'a fait qu'une session. »
- `unreliable` : « Moins de 5 élèves ont fait l'exercice : la tendance n'est pas encore fiable. »
- `empty` :
  - `title` : « Personne n'a encore fait cet exercice. » ;
  - `description` : « La compréhension s'affiche dès le premier exercice rendu. ».
- `empty_category` : « Aucun élève dans cette catégorie. »
- `pending` :
  - `title` : `one` « Pas encore fait · 1 », `other` « Pas encore faits · %{count} ».

Les pourcentages s'écrivent avec l'espace insécable de la charte (§12) : `number_to_percentage(rate, precision: 0, format: "%n %")`.

### 3.8 Accessibilité

- Cibles tactiles : chaque lien de catégorie fait au moins 48 px de haut et le tiers de la largeur. La ligne d'exercice est entièrement cliquable (inchangé).
- La couleur n'est jamais seule :
  - cercle : libellé écrit ;
  - badges : nombre et `sr-only` ;
  - barres : taux écrit ;
  - signe : texte.
- `aria-current="true"` sur la catégorie choisie. Ordre de tabulation : catégories, puis rien d'autre dans la section (les listes ne sont pas interactives).
- Mode sombre : uniquement par les tokens (UDR-0065). Aucune classe `dark:`.
- Sur téléphone, la page ne défile jamais en largeur. La grille des catégories reste à trois colonnes, en `text-xs` pour le libellé sous 360 px.

## 4. Conséquences

- **Rouge et jaune entrent dans l'application, réservés à la compréhension sur les écrans enseignant.** La charte (§5) interdit le rouge et l'ambre sur une note d'élève, et elle reste vraie : un élève ne voit jamais ces couleurs. Le jaune « Fragile » est un token distinct de l'ambre d'urgence.
- La ligne d'un exercice assigné a désormais un pied. Toute nouvelle information sur un exercice assigné va dans ce pied ou dans la page de suivi, pas dans une troisième ligne de texte.
- La page de suivi devient la page du rapport d'un exercice assigné. La fiche élève (CL-13) et le suivi des remédiations (AS-17) s'y brancheront.
- La fiche essentielle dans la classe (UDR-0029) garde sa « Réussite de la classe ». Les deux lectures diffèrent (toutes les sessions contre celles de l'assignation) : elles ne sont jamais sur la même page.
