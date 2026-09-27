# UDR-0034 : Gestion des matières — catégorie obligatoire choisie sur son badge, CRUD en modale, suppression confirmée dans la page

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/) (Lot R3 ; CA-20, CA-22, CA-25, CA-26) |
| **ADR lié** | [ADR-0034](../adr/0034-reprise-des-donnees-et-referentiel-seede.md) (référentiel créé par l'équipe) · [ADR-0029](../adr/0029-identifiants-exposes-public-id-et-slugs.md) (slug figé) · [ADR-0036](../adr/0036-suppression-archivage-et-anonymisation.md) (suppression refusée) · UDR-0005, UDR-0006, UDR-0007 |
| **Remplacé par** | — |

---

## 1. Contexte

Dans l'ancienne application, l'équipe créait une matière avec un nom et un alias court, mais **aucun champ n'exposait sa catégorie** : elle restait à `NULL` (C-07). La couleur et l'icône des cartes de cours étaient alors devinées par deux tables d'expressions régulières sur le **nom** (CA-26) : « Physique-Chimie » sortait en violet, une matière renommée changeait de couleur, une matière inconnue tombait sur l'ardoise. Le formulaire annonçait « 50 caractères » pour une colonne de 25 ; le nom était `titleize` (« SVT » devenait « Svt ») ; la suppression détruisait en cascade tous les cours de la matière.

En V1 la production démarre vide (ADR-0034) : l'équipe crée toutes les matières à l'écran. Une matière mal catégorisée à ce moment-là porte la mauvaise couleur partout où elle apparaît, pour les élèves comme pour les enseignants.

## 2. Décision

**La catégorie est un choix explicite, fait sur le badge qu'elle produira.** Le formulaire propose les trois catégories (`literature`, `science`, `other`) en boutons radio ; chaque option **est** le badge `ui_subject_badge` de la catégorie. L'équipe voit la couleur et l'icône avant de valider, sans script : c'est l'aperçu du badge. Aucune catégorie n'est cochée d'avance, et le champ ne porte pas `required` : une matière sans catégorie revient du serveur en 422, avec son message, dans la modale.

Pourquoi des radios-badges plutôt qu'un `select` suivi d'un aperçu dynamique : trois choix tiennent sur une ligne, le badge est l'information que l'on choisit vraiment, et l'aperçu ne demande aucun contrôleur Stimulus (UDR-0006, règle 6).

**La couleur ne se déduit jamais du nom.** Partout, le badge d'une matière est `ui_subject_badge(name, category:)`. Renommer une matière ne change ni sa couleur, ni son icône, ni son slug ; changer sa catégorie les change sur-le-champ.

**Le CRUD suit la règle Hotwire du plan** : création et modification dans le frame `modal`, erreurs en 422 dans la modale, succès en Turbo Stream. La suppression se confirme dans une `<dialog>` de la ligne (pas de `confirm()` du navigateur) ; une matière utilisée est refusée avec sa raison, jamais supprimée en cascade.

## 3. Règles d'implémentation

**Structure**

- Écran : `GET /teams/materials` (`materials_path`), `Teams::MaterialsController`, lecture par `Queries::Catalog::MaterialsQuery`.
- `ui_page_header` « Matières », action « Nouvelle matière » (`ui_button`, icône `plus`, `data-turbo-frame="modal"`).
- Tableau dans un conteneur `relative overflow-x-auto rounded-card border border-line bg-white shadow-card` ; `tbody#materials`, une ligne `tr#material_<slug>` par matière, triées par nom.
- Colonnes : Matière (`ui_subject_badge`), Abrégé, Catégorie (texte), Cours, Enseignants, actions (`sr-only`).
- Actions de ligne : « Modifier » (`ui_button` `secondary` `sm`, `data-turbo-frame="modal"`), « Supprimer » (`ui_modal` à déclencheur `ghost`, id `delete-material-<slug>`, formulaire `DELETE` `delete-material-form-<slug>`, bouton `danger`).
- Modale `material-modal`, formulaire `material-form` (`_form.html.erb`) : `ui_field` nom (40 au plus), `ui_field` abrégé (10 au plus), puis un `fieldset` « Catégorie » : une `label` par catégorie contenant le radio et son `ui_subject_badge`.

**Tokens**

- Teintes des catégories : `ComponentsHelper::SUBJECT_CATEGORIES` uniquement (`literature` → `gold` + `book-open`, `science` → `brand` + `beaker`, `other` → `team` + `academic-cap`).
- Option cochée : `has-checked:border-brand has-checked:ring-4 has-checked:ring-brand/20` ; radios `accent-brand`, `min-h-tap`.
- Aucune valeur en dur (UDR-0005).

**Comportement**

- `new` / `edit` : `turbo_frame_tag "modal"` → `ui_modal(open: true)` ; hors frame, la même modale s'ouvre sur le shell.
- Échec de saisie ou nom / abrégé déjà pris : `render :new` ou `:edit`, 422, erreurs sous chaque champ, saisie conservée.
- `create` / `update` : toast de succès, `update "materials"` (le tableau entier, pour garder l'ordre des noms et le nouveau badge), `update "materials_empty"` vidé à la création ; la modale se ferme par `modal#submitEnd`.
- `destroy` : succès → toast, `remove "material_<slug>"`, état vide rendu dans `#materials_empty` si c'était la dernière ; refus (`:conflict`, matière portée par un cours ou un profil enseignant) → 422, toast d'erreur persistant, `replace` de la ligne, ce qui referme la confirmation.
- Repli HTML : chaque écriture redirige vers `materials_path` avec `notice` ou `alert`.
- Le slug, dérivé du nom à la création, ne change jamais (ADR-0029). La casse saisie est gardée : « SVT » reste « SVT ».

**États obligatoires**

- Vide : `ui_empty_state` « Aucune matière pour l'instant », icône `book-open`.
- Chargement : sans objet (page rendue côté serveur ; Turbo pose `aria-busy` pendant l'envoi).
- Erreur : message sous le champ fautif ; refus de suppression en toast d'erreur.
- Succès : toast « Matière « … » créée. », « … enregistrée. », « Matière supprimée. ».

**Accessibilité**

- La catégorie est aussi écrite en toutes lettres dans sa colonne : jamais la couleur seule.
- Radios reliés à l'aide et à l'erreur de la catégorie par `aria-describedby`, `aria-invalid` en erreur ; `legend` « Catégorie ».
- « Modifier » porte un `aria-label` qui nomme la matière ; le tableau a une `caption` `sr-only`.
- Cibles ≥ 48 px (`min-h-tap`, boutons `sm` agrandis par leur pseudo-élément).
- Sur téléphone, seul le tableau défile horizontalement, jamais la page.

## 4. Conséquences

- Toute vue qui affiche une matière (catalogue, carte de cours, classe) passe sa `category` à `ui_subject_badge` ; aucune ne teinte une matière d'après son nom.
- Une matière ne peut plus exister sans catégorie : ni à l'écran (422), ni en base (`NOT NULL` + `CHECK`).
- Aucune suppression en cascade : une matière utilisée se garde, l'équipe retire d'abord ses cours ou change la matière de ses enseignants.
- Le libellé de la catégorie `other` vient de la locale commune (`materials.categories.other`, « Autres ») ; le plan écrivait « Autre ».
