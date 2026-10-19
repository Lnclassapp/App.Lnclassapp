# UDR-0129 : Insérer une image dans une fiche ou une question, remplir les emplacements de l'import, et la montrer à l'élève
<!-- index
titre: Images dans l'éditeur de fiche, la question et la lecture élève
statut: Proposé
adr-lie: [0104](../adr/0104-images-des-fiches-et-des-questions.md)
problematique: Où et comment l'équipe insère une image (emplacement annoncé ou libre), écrit son texte de remplacement, et comment l'élève la voit sur téléphone sans payer d'avance
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-10 |
| **Chantier** | `docs/chantiers/images-dans-les-cours` |
| **ADR lié** | ADR-0104 |
| **Complète** | UDR-0067 (éditeur d'article en mode images, réutilisé) · UDR-0016 (modale de fiche) · UDR-0014 (éditeur riche) |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe importe une leçon dont le texte annonce des images (`[[image: …]]` dans une fiche, `image.description` sur une question), les produit dans Claude Design, puis doit les placer exactement là où la leçon les attend. Sans repère visible, une image s'oublie et la publication est refusée sans que l'on sache où chercher. L'élève, lui, lit sur un téléphone à 390 px avec peu de données : une image doit arriver à sa place, à la bonne taille, et seulement quand il y arrive.

## 2. Décision

- **Même éditeur que le blog**, pas un nouveau : la modale de fiche passe `rich-text-editor` en mode images (UDR-0067 §3.4) et réutilise `communication--image-alts` pour les textes de remplacement. Un seul geste à apprendre pour l'équipe.
- **L'emplacement est remplacé, pas complété** : insérer une image quand le curseur est dans un emplacement remplace le paragraphe entier et copie la description dans le texte de remplacement. On évite ainsi l'emplacement oublié à côté d'une image déjà là.
- **Un compteur au-dessus de l'éditeur** (« 2 images à insérer ») plutôt qu'un surlignage dans Trix : Trix ne permet pas de styler un paragraphe selon son texte sans le modifier.
- **Question : un champ image unique au-dessus de l'énoncé**, pas d'éditeur riche : l'énoncé reste un texte simple (ADR-0104 §4.2).
- **Lecture élève : `<img loading="lazy">` avec `width`/`height`**, sans JavaScript : la mise en page ne saute pas et rien n'est chargé avant le défilement.

## 3. Règles d'implémentation

> Contrat d'exécution. Chaque nouveau fichier de `app/` porte l'en-tête HITL et cite « UDR : 0129 ».

### 3.0 Routes et constantes (contrat du Lot 0)

| Geste | Verbe et chemin | Helper |
|---|---|---|
| Envoyer une image de fiche | `POST /teams/essential-images` | `teams_essential_images_path(essential: slug)` (absent à la création de la fiche) |
| Envoyer une image de question | `POST /teams/question-images` | `teams_question_images_path` |
| Lire une image de fiche | `GET /images/fiches/:public_id` | `essential_image_path(public_id)` |
| Lire une image de question | `GET /images/questions/:public_id` | `question_image_path(public_id)` |

- Réponses d'envoi : `201 { public_id, sgid, url, width, height }`, `422 { error }` (raison en français), `403`, `401 { error: "unauthenticated" }`.
- Constantes lues par les vues et passées au JavaScript, jamais écrites en dur : `Entities::Shared::ContentImage::CONTENT_TYPES`, `MAX_BYTES` (300 Ko), `MAX_SIDE` (1200), `MAX_PER_ESSENTIAL` (30), `ALT_MAX` (150).
- `lib/image_upload.js` : `uploadImage(file, { url, field })` — `field` remplace le nom en dur `article_image[file]` (défaut inchangé pour le blog) ; `prepareImage` réencode en WebP qualité 0,8 puis 0,6 avant de refuser `too_heavy`.

### 3.1 Modale de fiche — `teams/essentials/_form`

**Structure**, dans l'ordre, sous le champ « Sous-titre » :
1. `div#essential_image_slots[aria-live=polite]` : si `input.image_slots.any?`, `ui_badge t(".slots_left", count:), tone: :warning, size: :sm` puis `ul.mt-2.space-y-1.text-sm.text-mute`, un `li` par emplacement : `ui_icon "photo", variant: :mini, size: :sm` + `t(".slot", description:)` (« Image à insérer : … »). Sinon le div est vide (`hidden`).
2. `div#essential_editor.space-y-2` avec `data-controller="rich-text-editor communication--image-alts essential-image-slots"`, les données de `essential_editor_data(upload_url:)` (helper calqué sur `article_editor_data`, plafonds de `ContentImage`, `field: "essential_image[file]"`), et les mêmes `data-action` que `#article_editor` (UDR-0067 §3.4.2) plus `trix-change->essential-image-slots#refresh`.
3. Ligne d'en-tête : `form.label :content` à gauche, à droite `ui_button t(".insert_image"), variant: :secondary, size: :sm, icon: "photo", id: "essential_insert_image", hidden: true` (`rich-text-editor#pickImages`).
4. `input#essential_image_files[type=file][hidden][accept=…]` (une seule image à la fois : pas de `multiple`).
5. `form.rich_textarea :content, value: essential_editor_content(input.content)`.
6. `p#essential_content_hint` : `t(".content_hint_images", max_bytes:, max_side:)`.
7. `ul#essential_image_alts.space-y-4` : une ligne `teams/articles/_image_alt_row` par image, nom de champ `essential[image_alts][<public_id>]`.

**Comportement — `essential_image_slots_controller.js`** (Stimulus, `app/javascript/controllers/catalog/`)
- `refresh()` : relit le document Trix, compte les paragraphes dont le texte entier correspond à `/^\[\[image:\s*(.{1,150}?)\s*\]\]$/`, met à jour le badge et la liste de §3.1.1.
- Sur `rich-text-editor:uploaded` : si la sélection Trix est dans un paragraphe-emplacement, sélectionner tout ce paragraphe avant l'insertion (l'image le remplace), puis remplir le champ `image_alts[<public_id>]` avec la description et masquer son badge « À compléter ».
- Hors emplacement : l'image s'insère au curseur, champ de texte de remplacement vide et marqué « À compléter » (comportement du blog).
- 31ᵉ image : refus côté navigateur, message `t(".too_many", count: 30)` dans la zone de statut de l'éditeur.

**États obligatoires**
- Vide : pas d'emplacement, pas d'image → §3.1.1 caché, `#essential_image_alts` vide.
- Chargement : zone de statut de `rich-text-editor` « Envoi de l'image… » (`aria-live=polite`) ; bouton d'insertion `disabled` pendant l'envoi.
- Erreur : raison du serveur ou du navigateur dans la zone de statut, `role=alert`, couleur `text-error` ; l'image n'est pas insérée.
- Succès : image dans le texte, ligne de texte de remplacement ajoutée, compteur décrémenté.

**Publication refusée** (`teams/essentials/transition.turbo_stream.erb`) : toast d'erreur `t("teams.essentials.transition.image_slots_left", count:)` ou `t(".image_alt_blank")` ; « Tout publier » : `t("teams.courses.transition.essential_not_ready", name:)`.

### 3.2 Question — `teams/exercises/_question_fields`

Au-dessus du champ « Énoncé » :
- Si la question a une image : `figure.flex.items-start.gap-3` → `img.size-20.rounded-sm.bg-mist.object-cover[alt=""]` + colonne : champ texte `exercise[questions_attributes][i][image_alt]` (maxlength 150, libellé « Texte de remplacement », badge « À compléter » si vide), bouton `ui_button t(".replace_image"), variant: :ghost, size: :sm` et `ui_button t(".remove_image"), variant: :ghost, size: :sm, icon: "trash"`.
- Sinon, si `image_description` : `div.rounded-ln.border.border-dashed.border-warning.bg-warning-soft.p-3` → `p.text-sm` `t(".image_expected", description:)`, bouton `ui_button t(".add_image"), variant: :secondary, size: :sm, icon: "photo"` et lien `t(".drop_description")` (vide la description).
- Sinon : bouton discret `ui_button t(".add_image"), variant: :ghost, size: :sm, icon: "photo"`.
- Champ caché `image_public_id` ; envoi par `question_image_controller.js` (`app/javascript/controllers/assessment/`) via `lib/image_upload.js` (`field: "question_image[file]"`), description recopiée dans `image_alt`.
- Question verrouillée (déjà tentée) : image et boutons en lecture seule, comme l'énoncé.
- Erreurs : `p.text-sm.text-error[role=alert]` sous le bloc ; publication refusée : toast `t("teams.exercises.transition.image_missing", number:)`.

### 3.3 Lecture élève

- **Fiche** (`catalog/essentials/show`, rendu Action Text) : partiel `catalog/essentials/_body_image` = `figure.my-6` → `img.mx-auto.h-auto.max-w-full.rounded-ln.bg-mist[src=essential_image_path][alt][width][height][loading=lazy][decoding=async]`. Pas de `figcaption`. Pas de lien vers l'image en grand (hors périmètre).
- **Question** (`assessment/exercise_sessions/_question_card`) : avant la `legend`, `img.mb-4.h-auto.max-h-72.w-full.rounded-ln.bg-mist.object-contain[alt][width][height][loading=lazy][decoding=async]`.
- Image qui ne charge pas : le navigateur affiche le texte de remplacement dans le cadre `bg-mist` (aucun JavaScript).
- 0 Ko de JavaScript ajouté aux pages de lecture.

**Accessibilité**
- Cibles tactiles ≥ 48 px pour tous les boutons ajoutés (`ui_button` `sm` a une zone de 48 px).
- `alt` toujours présent en lecture (garanti par la condition de publication) ; `alt=""` sur les vignettes de l'équipe (décoratives à côté de leur champ).
- Compteur d'emplacements et zone de statut en `aria-live=polite`, erreurs en `role=alert`.
- Focus : après une insertion réussie, il revient dans l'éditeur ; après une erreur, il reste sur le bouton d'insertion.
- Captures à fournir (CLAUDE.md) : modale de fiche avec 2 emplacements, après insertion, fiche élève et question élève, à 390 px et sur ordinateur.

## 4. Conséquences

- La modale de fiche devient plus haute ; elle défile déjà (UDR-0016).
- L'éditeur des **cours** reste sans image : seul le texte des fiches et l'image des questions s'ouvrent.
- Interdit désormais : afficher une image de cours sans `width`/`height`, sans `loading="lazy"`, ou par une autre adresse que `essential_image_path` / `question_image_path`.
