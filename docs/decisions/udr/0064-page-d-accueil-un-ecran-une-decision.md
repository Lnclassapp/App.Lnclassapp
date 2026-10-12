# UDR-0064 : Page d'accueil publique — un écran, une décision
<!-- index
titre: Page d'accueil publique : un écran, une décision
statut: Proposé
adr-lie: [0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md), [0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md), [0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md)
problematique: Le visiteur a une seule décision à prendre, élève ou enseignant, visible sans défiler à 360 × 640 : en-tête réduit au logo et à « Se connecter », héros à deux entrées de 56 px offertes une seule fois (UDR-0059), les matières de la grille élève (UDR-0058) sans « et plus encore », trois étapes, quatre promesses, section « Enseignants » vouvoyée, pied avec les pages publiques (UDR-0063) ; photo en WebP (1,3 Mo → 22 Ko) ; `ui_modal` gagne `trigger_full:`. Famille ordinateur de l'UDR-0059, rendue à toutes les largeurs jusqu'au lot M2 ; remplace la §3 de l'UDR-0012 ; amende UDR-0005
-->

| | |
|---|---|
| **Statut** | Proposé *(2026-10-02 ; à accepter par le porteur en revue de PR)* |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/refonte-homepage`](../../chantiers/refonte-homepage/prd.md) — critères RH-01 à RH-13 |
| **ADR lié** | [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (aucune ressource tierce, aucun script en ligne) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (Android d'entrée de gamme, Chrome 111 et Safari 16.4 : WebP lu partout) · [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (quatre badges) · [ADR-0034](../adr/0034-reprise-des-donnees-et-referentiel-seede.md) (référentiel) · [UDR-0005](0005-design-system-fondateur.md) (tokens, composants) · [UDR-0012](0012-landing-et-modales-de-role.md) (§2, décisions 1 à 5 : deux entrées, deux modales, aucun lien sans route) · [UDR-0054](0054-finitions-d-interface.md) (§3.1 titre de l'onglet, logo des pages publiques) · [UDR-0057](0057-ecrans-eleve-epures.md) (R1, R6) · [UDR-0058](0058-accueil-eleve.md) (§3, les matières) · [UDR-0059](0059-homepage-telephone-et-tablette.md) (famille ordinateur ; écran d'entrée du lot M2 sous 1 024 px) · [UDR-0061](0061-carte-d-aide-et-faq.md) (`trigger_size:`) · [UDR-0062](0062-echeances.md) (§4, l'enseignant n'assigne que des exercices) · [UDR-0063](0063-pages-publiques-mission-confidentialite-cgu-cgv.md) (§3.4, pied) |
| **Amende** | UDR-0012 (sa §3 « Structure », qui ne gouverne plus que la landing à partir de 1 024 px depuis l'UDR-0059, est remplacée par la §3 ci-dessous) · UDR-0005 (option `trigger_full:` de `ui_modal` ; `trigger_size:` vient de l'UDR-0061) |
| **Remplacé par** | — |

---

## 1. Contexte

Le visiteur de `/` est le plus souvent un élève sur un Android d'entrée de gamme, en 3G, avec des données payées par la famille ; ou un enseignant à qui un collègue a parlé de Lnclass. Il a une seule décision à prendre, élève ou enseignant, et la page actuelle la lui fait payer cher : une photo de 1,3 Mo avant le premier bouton, trois ancres et deux boutons dans l'en-tête, sept blocs qui répètent l'espace enseignant trois fois, un enseignant tutoyé alors que l'application le vouvoie, six matières suivies de « et plus encore », et deux couleurs d'identité (orange, noir) qui concurrencent le bleu de la marque ([memo](../../chantiers/refonte-homepage/memo.md)).

**Périmètre.** Cette UDR décrit la **famille ordinateur** de l'[UDR-0059](0059-homepage-telephone-et-tablette.md) (à partir de 1 024 px), celle que l'UDR-0059 §2.2 laissait à l'UDR-0012 « avec une seule épuration ». Sous 1 024 px, l'écran d'entrée dessiné par le porteur (UDR-0059 §3) reste à construire par le lot M2 d'[`interface-epuree`](../../chantiers/interface-epuree/plan.md) ; jusque-là, cette page s'affiche à toutes les largeurs, et c'est pourquoi elle tient aussi dans le premier écran d'un téléphone (RH-03). Le lot M2 l'enveloppera dans `div.hidden.lg:block` sans la changer.

## 2. Décision

1. **Un écran, une décision.** Le premier écran, même à 360 × 640 px, montre le logo, la promesse et les deux entrées « Je suis élève » et « Je suis enseignant », sans défiler. Rien d'autre n'y concourt : l'en-tête ne porte que le logo et « Se connecter ».
2. **Dire chaque chose une fois.** La page descend du général au particulier : héros (la décision), matières (ce qu'on y apprend), trois étapes (comment l'élève entre), quatre promesses (ce qu'il trouve), enseignants (ce qu'ils y font, une seule fois, avec leur bouton), pied. Les deux entrées ne sont pas répétées en bas de page (UDR-0059 §2.2, R6 de l'UDR-0057) : qui a tout lu remonte, ou ouvre « Se connecter ».
3. **Les deux entrées et leurs modales ne changent pas** (UDR-0012 §2) : mêmes identifiants, même contenu, même porte de rôle. Chaque modale nomme désormais l'onglet par son titre tant qu'elle est ouverte (UDR-0054 §3.1).
4. **L'élève est tutoyé, l'enseignant vouvoyé**, comme dans l'application.
5. **Une seule couleur d'identité, le bleu**, sur le papier et le blanc du design system. Aucune surface orange (`teacher`), violette (`team`) ni noire (`bg-ink`) : l'or (`gold/20`) n'apparaît que sur la tuile du badge Or, qui en parle.
6. **La page ne promet que ce que la V1 livre** : les matières de la grille de l'accueil élève (UDR-0058 §3 ; EDHC au 1er cycle, Philosophie au 2nd) sans « et plus encore », les quatre badges de l'ADR-0033, les trois gestes de l'enseignant (déclarer ses classes, assigner des exercices, suivre les scores ; jamais de cours assignés, UDR-0062 §4). Ni tarif, ni parent, ni établissement.
7. **La photo reste, à 22 Ko.** Le même cadrage, en WebP 960 × 640, avec ses dimensions déclarées et un test qui refuse plus de 100 Ko. Les logos sont ceux de l'application, réutilisés ; aucune nouvelle illustration.
8. **Le mode sombre suit celui de l'application** (porteur, 2026-10-03) : il passe par les tokens du design system, chantier `mode-sombre` ; cette page n'écrit aucune classe `dark:`.

**Pourquoi des boutons de 56 px pleine largeur plutôt que les 48 px d'aujourd'hui ?** Au téléphone, le pouce vise un bouton large sans regarder ; deux boutons empilés sur toute la largeur se lisent comme une alternative, pas comme deux liens. Sur un écran large, ils se placent côte à côte, à largeur égale, dans une grille à deux colonnes.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure** — `app/views/homepage/index.html.erb` ouvre par `page_title t(".page_title")` (« Accueil »). Tous les textes viennent de `config/locales/homepage/index.fr.yml` par `t(".clé")` ; aucun libellé en dur dans la vue, sauf le nom « Lnclass » et les noms des matières.

```
div.min-h-screen.bg-paper
├─ header.sticky.top-0.z-50.border-b.border-ink/10.bg-paper/90.backdrop-blur
│  └─ nav[aria-label=t(".nav.label")].mx-auto.flex.h-bar.max-w-page.items-center.justify-between.gap-4.px-gutter
│     ├─ link_to root_path, aria-label: t(".nav.home")        .flex.min-h-tap.items-center.gap-2.5.rounded-full.focus-visible:outline-2.focus-visible:outline-brand
│     │  ├─ image_tag "logo/lnclass.jpeg", alt: "", width: 36, height: 36   .size-9.rounded-sm
│     │  └─ span.font-display.text-xl.font-extrabold.tracking-tight  « Lnclass »
│     └─ ui_button t(".nav.sign_in"), href: new_session_path, variant: :secondary, size: :sm, icon: "arrow-right-end-on-rectangle"
├─ main
│  ├─ section#hero[aria-labelledby=hero-title].bg-brand
│  │  └─ div.mx-auto.grid.max-w-page.items-center.gap-10.px-gutter.py-10.pb-14.md:grid-cols-2.md:gap-16.md:py-20
│  │     ├─ div
│  │     │  ├─ p.inline-flex.items-center.gap-2.rounded-full.bg-ink/10.px-3.py-1.text-sm.font-medium   (span.size-2.rounded-full.bg-ink[aria-hidden] + t(".hero.eyebrow"))
│  │     │  ├─ h1#hero-title.mt-5.font-display.text-4xl.leading-display.font-extrabold.tracking-tight.text-balance.sm:text-5xl.lg:text-6xl   t(".hero.title")
│  │     │  ├─ p.mt-5.max-w-lg.text-base.text-ink/90.sm:text-lg   t(".hero.lead")
│  │     │  └─ div.mt-8.grid.gap-3.sm:max-w-md.sm:grid-cols-2
│  │     │     ├─ render "role_modal", role: :student, placement: :hero, variant: :primary
│  │     │     └─ render "role_modal", role: :teacher, placement: :hero, variant: :secondary
│  │     └─ figure.relative.mx-auto.w-full.max-w-lg.md:max-w-none
│  │        ├─ image_tag "homepage/student.webp", alt: t(".hero.image_alt"), width: 960, height: 640, decoding: "async"   .aspect-3/2.w-full.rounded-card.object-cover.object-hero.shadow-pop
│  │        └─ figcaption.absolute.-bottom-5.left-4.flex.items-center.gap-3.rounded-card.bg-white.p-3.pr-5.shadow-pop
│  │           ├─ span.grid.size-11.place-items-center.rounded-ln.bg-gold/20   (ui_icon "trophy", size: :lg)
│  │           └─ span.text-sm.leading-tight   (strong.block.font-bold t(".hero.card_title") + span.text-mute t(".hero.card_meta"))
│  ├─ section#matieres[aria-labelledby=matieres-title].border-b.border-ink/10.bg-white
│  │  └─ div.mx-auto.flex.max-w-page.flex-wrap.items-center.justify-center.gap-2.px-gutter.py-5.sm:justify-start
│  │     ├─ h2#matieres-title.w-full.text-center.text-sm.font-medium.text-mute.sm:mr-2.sm:w-auto.sm:text-left   t(".subjects.label")
│  │     └─ ui_subject_badge name, category:   × 7, dans l'ordre et avec la catégorie du référentiel (voir Contenu)
│  ├─ section#comment[aria-labelledby=comment-title].scroll-mt-20.py-16.md:py-24
│  │  └─ div.mx-auto.max-w-page.px-gutter
│  │     ├─ p.text-sm.font-bold.tracking-widest.text-brand-strong.uppercase   t(".how.eyebrow")
│  │     ├─ h2#comment-title.mt-3.font-display.text-3xl.font-extrabold.tracking-tight.sm:text-4xl   t(".how.title")
│  │     └─ ol.mt-10.grid.gap-5.md:grid-cols-3
│  │        └─ li.rounded-card.border.border-line.bg-white.p-6.shadow-card   × 3 (code, join, learn)
│  │           ├─ span.grid.size-12.place-items-center.rounded-full.bg-brand.font-display.text-lg.font-extrabold[aria-hidden]   1 · 2 · 3
│  │           ├─ h3.mt-5.font-display.text-xl.font-extrabold   t(".how.steps.<step>.title")
│  │           └─ p.mt-2.text-mute   t(".how.steps.<step>.text")
│  ├─ section#fonctionnalites[aria-labelledby=fonctionnalites-title].scroll-mt-20.border-y.border-ink/10.bg-white.py-16.md:py-24
│  │  └─ div.mx-auto.max-w-page.px-gutter
│  │     ├─ div.max-w-2xl   (p eyebrow · h2#fonctionnalites-title · p.mt-4.text-lg.text-mute t(".features.lead"))
│  │     └─ div.mt-10.grid.gap-5.sm:grid-cols-2
│  │        └─ ui_card title: t(".features.items.<item>.title"), icon:, heading: :h3   × 4 (exercises · curriculum · badges · light)
│  │           ├─ p.text-mute   t(".features.items.<item>.text")
│  │           └─ (badges seulement) div[data-badges].mt-4.flex.flex-wrap.gap-2   ui_badge t("badges.bronze"), tone: :warning · silver :neutral · gold :gold · diamond :info
│  └─ section#enseignants[aria-labelledby=enseignants-title].scroll-mt-20.bg-brand-soft.py-16.md:py-24   (dernière section : les entrées ne sont pas répétées en bas, UDR-0059 §2.2)
│     └─ div.mx-auto.max-w-page.px-gutter > div.max-w-2xl
│        ├─ p eyebrow t(".teachers.eyebrow") · h2#enseignants-title t(".teachers.title") · p.mt-4.text-lg.text-mute t(".teachers.lead")
│        ├─ ul.mt-6.space-y-3
│        │  └─ li.flex.items-start.gap-3   × 3 (classrooms · assign · follow) : ui_icon "check-circle", class: "mt-0.5 text-brand-strong" + span
│        └─ div.mt-8.sm:max-w-xs : ui_button t(".teachers.cta"), href: new_teacher_registration_path, size: :lg, full: true, icon_end: "arrow-right"
└─ footer.border-t.border-ink/10
   ├─ div.mx-auto.flex.max-w-page.flex-col.items-center.justify-between.gap-4.px-gutter.py-8.text-sm.text-mute.sm:flex-row
   │  ├─ p.flex.items-center.gap-2   (image_tag "lnclass/lnclass.png", alt: "", width: 24, height: 24, .size-6.rounded-sm · span.font-display.font-extrabold.text-ink « Lnclass » · span t(".footer.copyright", year:))
   │  └─ ul.flex.flex-wrap.justify-center.gap-6 > li × 3 : a[href=#comment] · a[href=#enseignants] · link_to new_session_path   .inline-flex.min-h-tap.items-center.hover:text-ink
   └─ (UDR-0063 §3.4, rendu seulement si public_page_links.any?) div.mx-auto.max-w-page.px-gutter.pb-8
      └─ ul#public_pages[aria-label=t(".footer.public_pages")].flex.flex-wrap.justify-center.gap-x-6.gap-y-2.text-sm.text-mute.sm:justify-end
         └─ li × pages en ligne, dans l'ordre de PAGES : link_to label, href   .inline-flex.min-h-tap.items-center.hover:text-ink
```

- **`app/views/homepage/_role_modal.html.erb`** (locals `role:` `:student` | `:teacher`, `placement:` `:hero` (`:join` n'existe plus ; le lot M2 ajoutera `:entry`, UDR-0059 §3), `variant:` `:primary` | `:secondary`) : `ui_modal(title: t(".<role>.title"), id: "role-modal-<role>-<placement>", size: :sm, trigger: t(".<role>.trigger"), trigger_variant: variant, trigger_size: :lg, trigger_full: true, document_title: page_title(t(".<role>.title")))`. Corps inchangé (UDR-0012 §3) : chapeau `text-mute`, « Se connecter » (`primary`, `lg`, pleine largeur, icône `arrow-right-end-on-rectangle`, vers `new_session_path`), la porte du rôle (`secondary`, `lg`, pleine largeur : `new_join_code_path` pour l'élève, `new_teacher_registration_path` pour l'enseignant), une indication `text-xs text-mute`. L'élève est en `primary`, l'enseignant en `secondary`.
- **`ui_modal`** : `trigger_size:` (UDR-0061 ; `:sm` | `:md` | `:lg`, défaut `:md`) et `trigger_full:` (UDR-0005, amendement du 2026-10-02 ; défaut `false`) sont passés tels quels à `ui_button` pour le déclencheur. Le conteneur du contrôleur `modal` est un bloc : dans une grille, la cellule le fait occuper toute la largeur, et `trigger_full: true` y étire le bouton.

**Contenu**
- Les matières, dans la vue, dans l'ordre de la grille de l'accueil élève (UDR-0058 §3) et avec la catégorie du référentiel (ADR-0034) : Mathématiques, Physique-Chimie, SVT (`science`) ; Français, Histoire-Géographie, EDHC, Philosophie (`literature` ; jamais `other`, dont la teinte `team` est interdite ici). Nom complet, jamais le sigle. Lnclass ne propose pas l'Anglais (porteur, 2026-10-03 ; retiré aussi du référentiel, amendement de l'ADR-0034). Si la grille change (`StudentHomeHelper::SUBJECT_TILES`), cette liste la suit.
- Les badges, dans cet ordre et avec ces tons (ADR-0033, `Assessment::BadgesHelper::BADGE_LEVEL_TONES`) : Bronze `warning`, Argent `neutral`, Or `gold`, Diamant `info`, libellés `t("badges.<level>")`.
- Ton : tutoiement pour tout ce qui s'adresse à l'élève (héros, étapes, promesses), vouvoiement dans la section « Enseignants » et dans la modale enseignant ; phrases courtes ; jamais de tarif.
- Le `h1` est le slogan de l'application, « Lnclass, tu comprends chap chap ! » (porteur, 2026-10-03 ; le même sous 1 024 px, amendement de l'UDR-0059).
- L'année du pied de page est `Date.current.year`.

**Tokens**
- Couleurs : `brand` (héros, disques des étapes ; le texte posé dessus est `ink`, `ink/90` pour le chapeau), `brand-soft` (section « Enseignants », tuiles d'icône des cartes), `brand-strong` (sur-titres, coches, texte des badges de Sciences), `paper` (fond de page, en-tête), `white` (cartes, bande des matières, section des promesses, carte du badge), `ink` et ses opacités `ink/10` (filets, pastille), `mute` (textes secondaires, pied), `line` (bordure des cartes), `gold/20` (tuile du trophée). Aucun `teacher`, `team`, `school`, `success`, `warning` ni `error` en surface ; `warning` et `info` seulement par `ui_badge` pour Bronze et Diamant.
- Typographie : `font-display font-extrabold` pour h1, h2, h3, les numéros et le nom « Lnclass » ; h1 `text-4xl sm:text-5xl lg:text-6xl leading-display tracking-tight text-balance` ; h2 `text-3xl sm:text-4xl` (`sm:text-5xl` dans l'appel final) ; h3 `text-xl` ; sur-titres `text-sm font-bold tracking-widest uppercase` ; chapeaux `text-lg` (celui du héros `text-base sm:text-lg`, pour que la décision tienne dans le premier écran d'un téléphone) ; pied `text-sm`.
- Rayons et ombres : `rounded-card` (cartes, photo, carte du badge), `rounded-full` (pastille, disques, boutons), `rounded-ln` (tuile du trophée), `rounded-sm` (logos) ; `shadow-card` (cartes des étapes), `shadow-pop` (photo, carte du badge).
- Espacements : sections `py-16 md:py-24`, héros `py-10 pb-14 md:py-20` (la carte du badge déborde de 20 px sous la photo ; 36 px la séparent de la bande des matières), bande des matières `py-5`, pied `py-8` ; gouttière `px-gutter` ; largeur `max-w-page` ; grilles `gap-5`, entrées `gap-3`. Ancres `scroll-mt-20` (l'en-tête mesure `h-bar`).

**Comportement**
- Modales : contrôleur `modal` du socle, par `ui_modal` ; le déclencheur porte `data-action="modal#open"`, `aria-haspopup="dialog"`, `aria-controls` ; la `<dialog>` native fournit le piège du focus, Échap et le fond cliquable ; la modale se ferme avant la mise en cache Turbo ; suivre un lien de la modale est une navigation Turbo (UDR-0012). Le titre de l'onglet est celui de la modale tant qu'elle est ouverte, puis « Accueil · Lnclass ».
- Aucun autre contrôleur Stimulus, aucun script ni style en ligne (CSP, ADR-0049), aucun Turbo Frame ni Stream : la page est statique.
- Un visiteur connecté n'arrive jamais sur la page : il est renvoyé vers son accueil (contrôleur inchangé).
- Sans JavaScript : les deux entrées sont inertes ; « Se connecter », « Créer mon compte enseignant » et les ancres restent des liens.

**États obligatoires**
- Sans objet : page statique, sans donnée ni erreur possible. La photo absente laisse son texte alternatif et sa place (dimensions déclarées).

**Accessibilité**
- Un seul `h1` ; chaque section est nommée par `aria-labelledby` vers son `h2` ; la bande des matières a son `h2` (petit, `text-mute`) ; les étapes sont un `ol`, les promesses enseignant un `ul`.
- Cibles ≥ 48 px : entrées et bouton enseignant `lg` (56 px), « Se connecter » `sm` (40 px, zone de 48 px par le pseudo-élément), logo `min-h-tap`, liens du pied `min-h-tap`. Focus visible par les composants et `focus-visible:outline-brand` sur le logo.
- Contrastes : `ink` sur `brand` 5,38 ; `ink/90` sur `brand` ≥ 4,5 ; `brand-strong` sur `brand-soft` 4,75 ; `mute` sur `brand-soft` 6,1 ; `mute` sur `white` et `paper` ≥ 6.
- Images : la photo a un `alt` qui décrit la scène ; logos décoratifs `alt=""` ; toute image déclare `width` et `height`.
- À 390 px, 360 px et 320 px : aucun défilement horizontal (le bouton enseignant est pleine largeur au téléphone, borné à `max-w-xs` au-delà) ; les deux entrées du héros sont visibles sans défiler à 360 × 640 ; à 320 px la pastille du héros passe sur deux lignes et les entrées restent dans le premier écran.
- Au téléphone, la bande des matières centre son titre et ses pastilles (deux, trois, deux) ; à partir de `sm`, titre et pastilles s'alignent à gauche sur une ligne.

**Poids**
- `app/assets/images/homepage/student.webp` : 960 × 640, ≤ 100 Ko (22 Ko mesurés). Le PNG de 1,3 Mo est supprimé.
- Aucune autre image que les logos déjà servis par l'application ; aucune police ni icône nouvelle ; CSS compilée sous le plafond de l'ADR-0051.

**Vérification**
- `test/controllers/homepage_controller_test.rb` : RH-01, RH-02, RH-04 à RH-10 (en-tête, h1, photo et son poids, matières et teintes, étapes, promesses et badges, vouvoiement et lien enseignant, entrées offertes une seule fois (UDR-0059), pages publiques du pied (UDR-0063), exercices seulement (UDR-0062), liens et boutons, interdits).
- `test/system/homepage_test.rb` : RH-02 (modales sans rechargement, titre de l'onglet), RH-03 (360 × 640, entrées visibles sans défiler).
- `test/system/finitions/narrow_screens_test.rb` (RH-11), `test/views/page_titles_test.rb` et `test/design/design_tokens_test.rb` (RH-12), `test/helpers/components_helper_test.rb` (RH-13).

## 4. Conséquences

- La §3 « Structure » de l'UDR-0012, qui ne gouvernait plus que la landing à partir de 1 024 px (UDR-0059), n'est plus la consigne : celle-ci la remplace, et s'applique à toutes les largeurs jusqu'au lot M2 d'`interface-epuree`. Les décisions 1 à 5 de l'UDR-0012 (deux entrées, deux modales, leurs portes, aucun lien sans route) restent et sont toujours vérifiées par les mêmes tests.
- Toute nouvelle promesse sur la page (un rôle, une fonctionnalité, une matière) entre avec la vague qui la livre, par un amendement de cette UDR ; la page ne promet jamais en avance.
- Une image servie par la page ne dépasse pas 100 Ko ; une photo entre en WebP avec ses dimensions. Un garde-fou général sur `app/assets/images` reste à décider par un amendement de l'ADR-0051 (dette du chantier).
- Interdit désormais sur la page publique : une navigation par ancres dans l'en-tête, un bouton qui défile vers un autre bouton, une surface `teacher`, `team` ou `bg-ink`, le tutoiement de l'enseignant, « et plus encore », tout tarif, la répétition des deux entrées en bas de page, une promesse de cours assignés.
- `ui_modal` gagne `trigger_full:` (UDR-0005 amendée), visible sur `/design` à côté de `trigger_size:` (UDR-0061).
