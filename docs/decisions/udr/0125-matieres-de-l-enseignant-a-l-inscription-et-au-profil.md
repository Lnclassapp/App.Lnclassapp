# UDR-0125 : Matières de l'enseignant — une seconde matière facultative à l'inscription, une ligne « Matières » modifiable en modale sur le profil
<!-- index
titre: Matières de l'enseignant à l'inscription et au profil
statut: Accepté *(porteur, 2026-10-16 ; matières par établissement)*
adr-lie: [0103](../adr/0103-matieres-de-l-enseignant-par-une-table-de-jointure.md), [0083](../adr/0083-inscription-enseignant-en-deux-voies.md)
problematique: L'enseignant ne choisit qu'une matière, à l'inscription, et ne peut plus la changer. Inscription : « Matière enseignée » puis « Autre matière (facultatif) », deux listes simples. Profil : ligne « Matières » (badges), « Modifier » ouvre la modale « Mes matières » (cases, 1 à 3) ; refus sous le groupe, toast au succès. Amende UDR-0079 et UDR-0041.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16) — matières par rattachement enseignant-établissement |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/enseignant-plusieurs-matieres`](../../chantiers/enseignant-plusieurs-matieres/memo.md) — Lot A |
| **ADR lié** | [ADR-0103](../adr/0103-matieres-de-l-enseignant-par-une-table-de-jointure.md) §4.4 |
| **Amende** | [UDR-0079](0079-inscription-enseignant-en-deux-voies.md) (rubrique « Établissement ») · [UDR-0041](0041-page-profil.md) (ligne « Matière » de l'enseignant) |
| **Remplacé par** | — |

---

## 1. Contexte

L'enseignant bivalent (PC et SVT, Maths et PC) choisit une matière à l'inscription et n'a ensuite aucun moyen d'en déclarer une seconde : la ligne « Matière » de « Mon profil » est en lecture seule (UDR-0041). Son seul recours est un second compte.

## 2. Décision

> **Réponse du porteur (2026-10-16)** : les matières sont celles du **rattachement enseignant-établissement** (ADR-0103 §4). « Mes matières » remplace la liste de l'**établissement courant** ; les autres établissements de l'enseignant gardent la leur. Un enseignant sans établissement courant n'a ni la ligne ni la modale.

1. **Inscription : deux listes simples**, pas de cases à cocher. La première reste obligatoire ; la seconde, « Autre matière (facultatif) », couvre la bivalence. Une liste de 6 à 15 cases rallongerait un formulaire déjà long sur téléphone, pour la majorité qui n'a qu'une matière (memo Q11).
2. **Profil : une modale « Mes matières »** avec des cases, sur le modèle des autres modifications du profil (UDR-0041, UDR-0006). C'est là qu'on ajoute la troisième, qu'on retire ou qu'on corrige.
3. **Pas de matière principale** à choisir (memo Q4) : l'ordre d'affichage est l'ordre d'ajout.
4. **Pas de validation** par la direction (memo Q3) : l'enregistrement est immédiat.

## 3. Règles d'implémentation

### 3.1 Inscription (`identity/teacher_registrations/_form.html.erb`), les deux voies

Dans la rubrique « Établissement », juste après le champ existant `ui_field form, :material_slug, as: :select, …` :

```erb
<%= ui_field form, :second_material_slug, as: :select, choices: material_options,
             prompt: t(".second_material_prompt"), hint: t(".second_material_hint") %>
```

- Le champ est **facultatif** (pas d'astérisque). La voie « lien » (bandeau `_school_preview`) le porte aussi.
- Ordre de tabulation (amende UDR-0079) : DRENA → établissement → matière → **autre matière** → nom → prénoms → genre → numéro → code secret → confirmation → bouton.
- La même matière choisie deux fois n'est pas une erreur : une seule est enregistrée.
- Après un refus (422), les deux listes gardent leur valeur.

| Clé (`identity.teacher_registrations`) | Texte |
|---|---|
| `activemodel…attributes.second_material_slug` | « Autre matière (facultatif) » |
| `form.second_material_prompt` | « Aucune autre matière » |
| `form.second_material_hint` | « Si vous enseignez aussi une autre matière. Vous pourrez en ajouter une troisième dans votre profil. » |

### 3.2 Profil — ligne « Matières » (`identity/profiles/_information.html.erb`)

- Pour l'enseignant, la ligne « Matière » devient : `dt` « Matière » s'il en a une, « Matières » au-delà ; `dd` = un `ui_subject_badge(tag.name, category: tag.category, size: :sm)` par matière, dans l'ordre, dans un `div.flex.flex-wrap.gap-1.5`.
- À droite, bouton « Modifier » : `ui_button` `variant: :secondary`, `size: :sm`, icône `pencil-square`, `href: edit_profile_materials_path`, `data: { turbo_frame: "modal" }`, `aria-label` « Modifier mes matières ». Même alignement que la ligne « Nom ».
- Les autres rôles n'ont ni la ligne ni le bouton (inchangé).

### 3.3 Modale « Mes matières » (`identity/profile_materials/edit.html.erb`)

Route : `resource :materials, only: %i[edit update], controller: :profile_materials` dans `resource :profile` (`config/routes/identity.rb`) → `GET /profile/materials/edit`, `PATCH /profile/materials`. Aucun identifiant : toujours le compte de la session (ADR-0055).

Même gabarit que `identity/profile_names/edit.html.erb` (frame `modal`, `profile_modal_layout`, `open: true`, bouton dans `modal.footer`) :

```erb
<% tab_title = page_title(t(".title")) %>
<%= turbo_frame_tag "modal" do %>
  <%= ui_modal title: t(".title"), id: "profile-materials-modal", **profile_modal_layout, open: true,
                document_title: tab_title do |modal| %>
    <% modal.footer do %>
      <%= ui_button t(".cancel"), variant: :secondary, data: { action: "modal#close" } %>
      <%= ui_button t(".submit"), type: :submit, form: "profile-materials-form", icon: "check" %>
    <% end %>
    <%= form_with model: @form, scope: :profile_materials, url: profile_materials_path, method: :patch,
                  id: "profile-materials-form" do |form| %>
      <%= ui_checkbox_group form, :material_slugs, choices: material_options, label: t(".label"), hint: t(".hint"), columns: 2 %>
      <p class="mt-3 text-sm text-mute"><%= t(".kept_assignments") %></p>
    <% end %>
  <% end %>
<% end %>
```

- Les cases cochées à l'ouverture sont les matières actuelles. `material_options` : toutes les matières du référentiel, par nom (comme l'inscription).
- **Pas de blocage côté client** du nombre de cases : la règle (1 à 3) est vérifiée par le serveur, la seule source.
- Les matières gardées conservent leur rang ; les nouvelles viennent après, dans l'ordre de la liste.

**États**

| État | Comportement |
|---|---|
| Succès | `update.turbo_stream.erb` : remplace `#profile_information`, ferme la modale, toast « Vos matières sont enregistrées. ». Sans Turbo : `redirect_to profile_path`, `notice`, 303 |
| Aucune case | 422 dans la modale ; sous le groupe, `p#profile_materials_material_slugs_error` « Gardez au moins une matière. » ; le `fieldset` porte `aria-describedby` et `aria-invalid` |
| Plus de 3 cases | 422 ; « 3 matières au plus. » ; les cases restent cochées comme envoyées |
| Matière inconnue (supprimée entre-temps, formulaire forgé) | 422 ; « Cette matière n'existe plus. Rechargez la page. » |
| Liste identique | succès, même toast, rien n'est écrit (ni audit) |
| Rôle autre qu'enseignant | `ManageOwnMaterialsPolicy` refuse (`:forbidden`) ; rendu par `render_result` comme tout refus ; aucune modale ne s'ouvre |

| Clé (`identity.profile_materials`) | Texte |
|---|---|
| `edit.title` | « Mes matières » |
| `edit.label` | « Les matières que vous enseignez » |
| `edit.hint` | « 1 à 3 matières, pour %{school}. Votre catalogue, vos classes et votre accueil y montrent les cours de chacune. » |
| `edit.kept_assignments` | « Retirer une matière ne retire pas les exercices déjà assignés. » |
| `edit.submit` · `edit.cancel` | « Enregistrer » · « Annuler » |
| `update.updated` | « Vos matières sont enregistrées. » |
| erreurs `material_slugs.blank` / `.too_many` / `.inclusion` | voir le tableau des états |

**Accessibilité** : le groupe est un `fieldset` avec `legend` (fourni par `ui_checkbox_group`) ; cases ≥ 48 px de cible (`min-h-tap` sur le `label`) ; le focus va au premier champ en erreur après un 422 ; la modale garde le piège de focus et la fermeture par Échap (UDR-0006).

**Téléphone (390 px)** : `columns: 2` passe à une colonne sous 640 px ; la modale suit `profile_modal_layout` comme les autres modales du profil.

## 4. Conséquences

- Le profil de l'enseignant gagne sa première ligne modifiable propre à son rôle.
- L'en-tête (`ShellUserQuery`) et la signature d'annonce reflètent la modification à la requête suivante, sans cache à invalider.
- Interdit désormais : une ligne « Matière » au singulier pour un enseignant qui en a plusieurs ; une case « principale ».
