# UDR-0075 : Annonces — thème de couleur, illustrations de l'équipe, décompte des caractères, trois annonces en ligne

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-05 : palette des 10 thèmes comprise)* |
| **Date** | 2026-10-05 |
| **Chantier** | `docs/chantiers/annonces-v2` |
| **ADR liés** | [0081](../adr/0081-annonces-trois-en-ligne-themes-et-illustrations-de-l-equipe.md), [0078](../adr/0078-annonces-trois-auteurs-classes-ciblees-et-retrait.md) |
| **Amende** | [UDR-0071](0071-annonces.md) §3.2 (carte), §3.3 (bibliothèque), §3.8 (formulaire) ; [UDR-0068](0068-configuration-et-pilotage-par-etablissement.md) §3.4 (page « Référentiel ») |

---

## 1. Contexte

Le porteur veut des cartes d'annonce colorées « comme sur Wave », une bibliothèque d'illustrations que l'équipe enrichit, un décompte des caractères et plus de date de fin à saisir. Chaque auteur garde 3 annonces en ligne au plus (ADR-0081). L'UDR-0071 décrit une carte unique (`bg-brand-soft text-school`), 8 illustrations figées et un champ « Visible jusqu'au ».

## 2. Décision

- Une carte prend le thème de son annonce, l'un des 10 de Lnclass. Le thème redéfinit 4 tokens à l'échelle de la carte.
- Le formulaire montre le décompte du titre et du texte, sur le modèle du résumé d'article (UDR-0067 §3.3). Il propose 10 pastilles de thème et les illustrations de l'équipe après les 8 de base. Il n'a plus de date de fin. Il prévient quand la publication archivera une annonce.
- L'équipe gère la bibliothèque sur une page « Illustrations d'annonce », atteinte par une tuile du Référentiel.

## 3. Règles d'implémentation

### 3.1 Thèmes — tokens et carte (amende l'UDR-0071 §3.2)

Liste fermée, dans cet ordre (`Entities::Communication::Message::THEMES`). Libellés `communication.themes.<clé>`. Valeurs : le fond (`--color-brand-soft`), le texte (`--color-school`), l'illustration (`--color-brand`) et l'illustration forte ou le badge (`--color-brand-strong`).

| Clé | Libellé | Clair : fond · texte · illus. · forte | Sombre : fond · texte · illus. · forte |
|---|---|---|---|
| `ciel` | Ciel *(par défaut, l'apparence actuelle)* | `#e5f5ff` · `#1b365d` · `#00a0ff` · `#0070b3` | `#132c42` · `#a9c4ee` · `#0070b3` · `#7fd0ff` |
| `lagune` | Lagune | `#d9f7f3` · `#0b4a45` · `#14b8a6` · `#0f766e` | `#0f2e2b` · `#99e6dc` · `#0f766e` · `#5eead4` |
| `menthe` | Menthe | `#e3f9e5` · `#14452a` · `#22c55e` · `#15803d` | `#13301c` · `#a7e8b8` · `#15803d` · `#86efac` |
| `citron` | Citron | `#fff6c7` · `#4a3b05` · `#eab308` · `#a16207` | `#332a0c` · `#f5e08a` · `#a16207` · `#fde047` |
| `mangue` | Mangue | `#ffe9d2` · `#5a2a05` · `#f97316` · `#c2410c` | `#3a220f` · `#fdc897` · `#c2410c` · `#fdba74` |
| `corail` | Corail | `#ffe3df` · `#5f1a12` · `#f2554a` · `#b91c1c` | `#3d1b18` · `#fbb4ac` · `#b91c1c` · `#fca5a5` |
| `hibiscus` | Hibiscus | `#ffe1f3` · `#5c1642` · `#ec4899` · `#be185d` | `#3d1a30` · `#f9b4dc` · `#be185d` · `#f9a8d4` |
| `lavande` | Lavande | `#efe5ff` · `#3b1d6e` · `#8b5cf6` · `#6d28d9` | `#2a1e45` · `#d4c2fb` · `#6d28d9` · `#c4b5fd` |
| `indigo` | Indigo | `#2e3a8c` · `#ffffff` · `#a5b4fc` · `#e0e7ff` | `#1e2563` · `#e0e7ff` · `#6366f1` · `#c7d2fe` |
| `nuit` | Nuit | `#1f2937` · `#f9fafb` · `#60a5fa` · `#fbbf24` | `#0b0f17` · `#e5e7eb` · `#3b82f6` · `#fbbf24` |

Contrastes mesurés à l'écriture de cette UDR, et revérifiés par `test/design/announcement_themes_test.rb` :
- texte ≥ 8,06:1 (« Ciel » en sombre) ;
- signature (texte à 80 %) ≥ 5,2:1 ;
- badge (forte) ≥ 4,4:1.

Seuils exigés : 4,5:1 pour le texte et la signature, 3:1 pour le badge.

- **CSS** (`app/assets/stylesheets/application.tailwind.css`, après les tokens) :
  - un bloc `[data-announcement-theme="<clé>"] { --color-brand-soft: …; --color-school: …; --color-brand: …; --color-brand-strong: …; }` par thème ;
  - le même jeu en sombre, dans **les deux** blocs de l'UDR-0065 : `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) [data-announcement-theme="<clé>"] {…} }` et `:root[data-theme="dark"] [data-announcement-theme="<clé>"] {…}`.

  Aucune classe `dark:`, aucune valeur arbitraire dans les vues (UDR-0005).
- **Carte** : `article#announcement_<public_id>` reçoit `data-announcement-theme="<card.theme>"`, sans autre changement de classes. Le fond (`bg-brand-soft`), le texte (`text-school`), la signature (`text-school/80`), la croix, le badge (`text-brand-strong`), les illustrations (`fill-brand`, `fill-brand-strong`, `fill-school`) et ▶ suivent le thème. Les autres couleurs des illustrations de base (`fill-white`, `fill-gold`, `fill-teacher`, `fill-success`, `fill-error`) ne changent pas.
- Partout où la carte est rendue (carrousel, « Reçues », modération), le thème s'applique. Dans « Mes annonces », une pastille de thème (`span.size-3.rounded-full.bg-brand-soft.ring-1.ring-school/30` portant `data-announcement-theme`) précède le titre de chaque ligne, avec son libellé en `sr-only` : « Thème : Mangue ».

### 3.2 Illustrations de l'équipe — rendu (amende l'UDR-0071 §3.3)

- `announcement_illustration(ref, class:)` accepte une clé de base (rendu inchangé) ou une illustration de l'équipe.
- Une illustration de l'équipe est rendue en `<svg viewBox="<view_box>" aria-hidden="true" focusable="false" class="<class> fill-brand-strong">`, avec ses formes reconstruites par le constructeur de balises : `path`, `rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`, `g`, chacun avec ses seuls attributs géométriques. Le dessin est d'une seule couleur, celle de l'illustration forte du thème.
- Une illustration retirée reste rendue sur les annonces qui la portent.

### 3.3 Formulaire (amende l'UDR-0071 §3.8)

L'ordre des champs devient :

1. **Titre**. `ui_field :title`, inchangé (`maxlength: 60`, aide « 60 caractères au plus. »), est enveloppé dans `div` `data-controller="communication--character-count"` (contrôleur de l'UDR-0067, réutilisé tel quel) avec :
   - `data-communication--character-count-max-value="60"` ;
   - `…-near-value="Il reste %{count} caractères."` ;
   - `…-full-value="Limite atteinte : %{max} caractères."`.

   Le champ porte `data-communication--character-count-target="input"` et `data-action="input->communication--character-count#update"`. Sous le champ, `p.mt-1.text-right.text-xs.tabular-nums.text-mute` `data-communication--character-count-target="count"` rendu par le serveur (« 18 / 60 »). Puis `span.sr-only` `aria-live="polite"` `data-communication--character-count-target="status"`.
2. **Texte**. `ui_field :body`, inchangé (`maxlength: 140`, aide « 140 caractères au plus. Les détails peuvent aller dans l'audio. »), avec le même décompte et `max = 140`.
3. **Destinataires**, inchangés.
4. **Thème**. `fieldset` (`legend` « Thème »), `div.grid.grid-cols-5.gap-2`, dix options. Chaque option :
   - `label.flex.min-h-tap.cursor-pointer.flex-col.items-center.gap-1.rounded-ln.p-1.text-xs.font-medium.has-focus-visible:outline-2.has-focus-visible:outline-brand` ;
   - à l'intérieur, `radio_button :theme, <clé>` (`sr-only`), puis une pastille `span.grid.size-10.place-items-center.rounded-full.bg-brand-soft.ring-1.ring-school/30` qui porte `data-announcement-theme="<clé>"` et contient un point `span.size-3.rounded-full.bg-brand-strong` ;
   - puis le libellé du thème.

   Option cochée : le `label` prend `has-checked:bg-mist has-checked:font-bold` (aucun sélecteur arbitraire, UDR-0005). « Ciel » est coché par défaut.

   Le `fieldset` porte `data-controller="communication--theme-preview"`. Au changement de thème, ce contrôleur pose `data-announcement-theme` sur le `fieldset` de l'**Illustration**, pour que les dessins se recolorent. Sans JavaScript, l'aperçu reste en « Ciel ».
5. **Illustration**. La grille de l'UDR-0071 (`grid-cols-4`) propose d'abord les 8 de base, puis les illustrations de l'équipe non retirées (`name` pour libellé), par date d'ajout. La valeur d'une option de l'équipe est son `public_id`.
6. **Image** (facultative), inchangée.
7. **Audio** (facultatif) : aide « MP3 ou M4A, 10 Mo au plus. Un enregistrement de téléphone convient. ». Refus : « Ce fichier n'est pas accepté. Exportez l'enregistrement en MP3 ou M4A. ».
8. **Publier le**, inchangé.
9. *(supprimé)* « Visible jusqu'au » disparaît. Sous « Publier le », `p.text-xs.text-mute` « L'annonce reste visible 30 jours. ».

**Encadré du plafond**, juste avant le pied : en création, ou en modification d'un brouillon ou d'une annonce programmée, si l'auteur a 3 annonces en ligne, `div.rounded-ln.bg-info-soft.p-4.text-sm.text-info` `role="status"` `id="announcement-cap-notice"` :
- « Tu as déjà 3 annonces en ligne. En publiant, « <titre de la plus ancienne> » sera archivée. » ;
- puis `p.mt-1.text-xs` « Programmée, elle archivera à sa parution la plus ancienne alors en ligne. ».

Il est absent avec 2 annonces en ligne ou moins, et en modification d'une annonce publiée.

**Toasts** :
- « Annonce publiée. « <titre> » est archivée. » quand une annonce est archivée ;
- avec plusieurs archivées : « « <titre 1> » et « <titre 2> » sont archivées. » ;
- sinon, inchangés.

### 3.4 « Mes annonces » (complète l'UDR-0071 §3.7)

- La ligne d'une annonce archivée par le plafond est « Archivée le <date> », comme un archivage par l'auteur.
- La fin affichée (« · jusqu'au <date> ») est la date de la fin elle-même : elle tombe à l'heure de parution, 30 jours après (ADR-0081 §4.1), c'est donc le dernier jour de visibilité. La règle « fin − 1 jour » de l'UDR-0071 valait pour une fin à minuit.

### 3.5 Page « Illustrations d'annonce » — équipe

Route `GET/POST /teams/announcement-illustrations`, `GET /teams/announcement-illustrations/:public_id/edit`, `PATCH` du même chemin, `POST …/:public_id/retirement`. `page_title` « Illustrations d'annonce » (« Illustrations d'annonce · Équipe · Lnclass »). `content_for :nav_key, "referential"`. Lien de retour « Référentiel » au-dessus du titre (comme les écrans du référentiel, UDR-0068).

```
ui_page_header title: "Illustrations d'annonce", subtitle: "Les auteurs les choisissent pour leurs annonces."
ui_card title: "Ajouter une illustration", icon: "plus"     ← form_with … multipart, id: "illustration-form"
  ui_field :name, label: "Nom", maxlength: 30, required: true, hint: "30 caractères au plus. Les auteurs le lisent dans le choix."
  ui_field :file, type: "file", value: nil, accept: "image/svg+xml,.svg", label: "Dessin",
           hint: "SVG d'une seule couleur, 50 Ko au plus. Il prend la couleur du thème de l'annonce."
  pied : ui_button "Ajouter", type: :submit
section#team_illustrations  aria-labelledby="team_illustrations_title"
  h2#team_illustrations_title « Ajoutées par l'équipe »
  vide : ui_empty_state title: "Aucune illustration ajoutée pour l'instant.", icon: "photo"
  ul.grid.gap-3.sm:grid-cols-2 > li#illustration_<public_id>.flex.items-center.gap-3.rounded-ln.border.border-line.p-3
     ├─ trois aperçus size-12 dans des pastilles data-announcement-theme="ciel" | "mangue" | "nuit" (bg-brand-soft rounded-ln p-1)
     ├─ div.min-w-0.flex-1 : p.font-bold.truncate <nom> ; p.text-xs.text-mute « Ajoutée le 5 oct. » (+ ui_badge "Retirée", tone: :neutral si retirée)
     └─ si active : ui_dropdown ⋮ (UDR-0042) : « Renommer » (→ edit), « Retirer » (ui_modal « Retirer cette illustration ? »
          texte « Elle ne sera plus proposée. Les annonces qui l'utilisent la gardent jusqu'à leur fin. » ; pied « Annuler » · « Retirer » danger)
section « Fournies par Lnclass » : ul.grid.grid-cols-4.gap-2 des 8 de base (illustration size-12 + libellé), sans action
```

- **Erreurs (422)**, sous le champ « Dessin » :
  - « Ce dessin n'est pas accepté : il contient autre chose que des formes. » ;
  - « Ce fichier n'est pas un dessin SVG. » ;
  - « Ce fichier est trop lourd (50 Ko au plus). » ;
  - « Ce dessin est vide. ».

  Sous « Nom », les erreurs habituelles de `ui_field`.
- **Succès** : redirection vers la page, avec le toast « Illustration ajoutée. », « Illustration renommée. » ou « Illustration retirée. ».
- **Accès** : équipe seulement. Tout autre rôle reçoit 403, et un visiteur va à « Se connecter ».

### 3.6 Tuile du Référentiel (amende l'UDR-0068 §3.4)

La page « Référentiel » gagne une tuile, au même gabarit que les autres :
- icône `photo` ;
- chiffre : 8 + les illustrations de l'équipe non retirées ;
- libellé « illustration d'annonce » ou « illustrations d'annonce » ;
- « Gérer → » vers `/teams/announcement-illustrations`.

### États obligatoires

| État | Où | Rendu |
|---|---|---|
| Vide | bibliothèque de l'équipe | `ui_empty_state` du §3.5 ; le formulaire d'annonce propose alors seulement les 8 de base |
| Chargement | aucun | pages entières, pas de frame différé |
| Erreur | formulaire d'annonce, formulaire d'illustration | 422, erreurs sous les champs |
| Succès | idem | redirection et toast |

### Accessibilité

- Chaque pastille de thème a son nom visible. Le `fieldset` a sa `legend`.
- Le décompte annonce seulement le passage d'un seuil, dans une zone `aria-live="polite"` (UDR-0067).
- L'encadré du plafond porte `role="status"` : il est lu à l'ouverture du formulaire.
- Les illustrations restent décoratives (`aria-hidden="true"`). Leur nom est porté par le libellé de l'option.

## 4. Conséquences

- La carte de l'UDR-0071 ne change que par un attribut. Les thèmes passent par les tokens, comme le mode sombre.
- Un 11ᵉ thème demandera une nouvelle clé, ses 8 valeurs et le test de palette : rien d'autre.
- Les dessins de l'équipe sont monochromes, par choix de sécurité (ADR-0081 §4.3).

## Amendement du 2026-10-05 — phase 5 : l'encadré nomme toutes les annonces qui partiraient

Décision de l'orchestrateur du chantier `annonces-v2`, prise à la revue de phase 5 (Lot F). Un auteur peut avoir plus de 3 annonces en ligne : celles publiées avant le chantier ne sont pas archivées d'office. Sa prochaine parution en archive alors « en ligne − 2 » d'un coup, les plus anciennes (ADR-0081 §4.1). L'encadré du plafond (§3.3) les nomme toutes, la plus ancienne d'abord :

- à 3 en ligne, le texte du §3.3 ne change pas : « Tu as déjà 3 annonces en ligne. En publiant, « <titre> » sera archivée. » ;
- au-delà : « Tu as déjà <n> annonces en ligne. En publiant, « <titre 1> », « <titre 2> » et « <titre 3> » seront archivées. », les titres en liste française (virgules, puis « et »).

La seconde ligne de l'encadré (« Programmée, elle archivera à sa parution la plus ancienne alors en ligne. ») et les toasts ne changent pas : le toast nommait déjà toutes les annonces archivées.
