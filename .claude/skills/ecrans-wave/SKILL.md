---
name: ecrans-wave
description: Applique les règles « écrans minimalistes, style Wave » de Lnclass à tout écran de l'élève — un écran, une chose de valeur, jamais de section vide, fond gris, cartes blanches groupées, listes plates, « Voir plus (n) ». Utilise-la pour créer un nouvel écran, relire ou auditer un écran, retoucher une interface élève, ou quand l'utilisateur tape /ecrans-wave.
---

# Écrans minimalistes, style Wave

**L'UDR fait autorité** : [`docs/decisions/udr/`](../../../docs/decisions/udr/) « Écrans minimalistes, style Wave » (numéro posé à la fusion ; cherche `ecrans-minimalistes-style-wave`). Cette skill en est le mode d'emploi. En cas de contradiction, l'UDR gagne.
Maquettes validées : [`docs/chantiers/simplification-ecrans-eleve/maquettes/`](../../../docs/chantiers/simplification-ecrans-eleve/maquettes/) (`accueil-avec-devoirs.html`, `accueil-sans-devoirs.html`, `matiere.html`, `lecon.html`).

Charge aussi `.claude/skills/test-ecrans` pour les captures. Ne code qu'avec les tokens (`test/design/design_tokens_test.rb`) : pas de hex, de `style=`, de `dark:`, de valeur arbitraire, de graisse > 500.

## Les 8 règles

1. **Un écran, une chose de valeur.** Accueil : la classe. Matière : ses leçons. Leçon : réviser et s'entraîner.
2. **Jamais de section vide** : elle est masquée, titre compris. Pas de phrase « rien à faire ».
3. **Pas de raccourci en double** : une action, une porte par écran. Ce qu'on ajoute en retire un autre.
4. **Écrans intérieurs sans barre de navigation** : flèche retour + grand titre (`content_for :inner`).
5. **Fond `bg-mist`, groupes dans des cartes `bg-white rounded-card`**, libellé de section gris (`text-mute`) au-dessus.
6. **Recherche dans un champ gris plein** (`bg-line`), sans bordure ni bouton visible.
7. **Listes plates, valeur alignée à droite** (« 0/4 ») : titre, détail, valeur.
8. **3 éléments au plus par section, puis « Voir plus (n) »** (n = les cachés, sans requête).

## Gabarits (composants existants : `app/views/shared/screens/`)

**Écran intérieur** (matière, leçon) :
```erb
<% content_for :inner, "1" %>
<div class="mx-auto max-w-180 space-y-6 pb-12">
  <%= render "shared/screens/inner_header", title: @title, back_href: parent_path, subtitle: "Leçon 3 · Maths · 6e" %>
  <!-- groupes, grille… -->
</div>
```

**Bandeau et jonction arrondie** (accueil) : `content_for :home_band` (bleu, 187 px, avatar à gauche, aide en icône seule) + `content_for :wave_home`, puis le blanc recouvre le bandeau :
```erb
<div class="-mt-wave-lap rounded-t-wave bg-white pb-6 lg:mt-0 lg:rounded-none lg:bg-transparent">…</div>
```

**Carte héros** (classe), à cheval sur la jonction : voir `classroom/student_homes/_class_card.html.erb`.
```erb
<section class="relative z-10 mx-gutter rounded-card bg-white p-5 shadow-lift max-lg:-top-wave-card max-lg:-mb-wave-card">
  <p class="text-xs font-medium tracking-wide text-brand-strong uppercase">Ta classe</p>
  <h2 class="mt-1 text-2xl font-medium text-ink">3E B</h2> … <%= ui_button "Entrer en classe", href: path %>
</section>
```

**Grille de tuiles** (4 colonnes, pastille pastel + libellé court + sous-libellé) : voir `catalog/courses/_lesson_tile.html.erb`.
```erb
<ul class="grid grid-cols-4 gap-x-1 gap-y-5 px-2 pt-4 pb-3">
  <li><a class="flex min-h-tap flex-col items-center gap-1.5 text-center">
    <span class="grid size-12 place-items-center rounded-ln bg-tint-… text-brand-strong"><%= icon %></span>
    <span class="line-clamp-2 text-sm font-medium text-ink">Fractions</span>
    <span class="-mt-1 text-xs text-mute">Leçon 3</span></a></li>
</ul>
```

**Carte blanche groupée + liste plate + « Voir plus (n) »** (règles 5, 7, 8) :
```erb
<%= render layout: "shared/screens/group", locals: { id: "student_x", title: "Prépare devoirs", total: items.size } do %>
  <% items.each_with_index do |i, n| %>
    <%= render "shared/screens/row", title: i.title, detail: i.detail, value: "0/4", href: i.path, icon: ui_icon("book-open"), folded: n >= ComponentsHelper::REVEAL_LIMIT %>
  <% end %>
<% end %>
```
Dans le bloc, `t(".clé")` se résout sur la partial du groupe : utilise des clés absolues.

**Champ de recherche gris** : `form_with … role: "search"`, `search_field_tag` en `block min-h-tap w-full rounded-ln border-0 bg-line py-3 pr-4 pl-12 text-base text-ink placeholder:text-mute`, loupe à gauche, contrôleur Stimulus `search`.

## Checklist de revue (cocher les 8)

- [ ] L'écran dit **une** chose de valeur, en une place ?
- [ ] Aucune section vide ni phrase « rien à faire » ; aucune action en double ?
- [ ] Écran intérieur : pas de navbar, flèche retour (`aria-label`) + `h1` ?
- [ ] Fond `bg-mist`, groupes en `rounded-card bg-white`, libellés `text-mute` ?
- [ ] Lignes plates, valeur à droite, ≥ 3 éléments → « Voir plus (n) » ?
- [ ] Tokens seulement, graisse ≤ 500, textes en `t(".clé")`, UI en français ?
- [ ] Cibles ≥ 48 px, `aria-label` des icônes seules, rien porté par la couleur seule ?
- [ ] Captures 390 px et bureau, clair et sombre, envoyées (jamais commitées) ?

## Hors périmètre

La carte « Prochain exercice » n'apparaît plus sur aucun écran élève ; son code est conservé pour le guidage d'activation après l'inscription (issue « Réutiliser « Prochain exercice » dans l'activation après l'inscription »). Ne le réaffiche pas sans nouvelle décision.
