# UDR-0014 : Formulaire cours — créer et modifier un cours dans une modale large, contenu dans l'éditeur riche, statut changé hors du formulaire

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/) (Lot B2 ; CA-05, CA-06, CA-07) |
| **ADR lié** | [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (cycle de vie, pas de retour au brouillon) · [ADR-0029](../adr/0029-identifiants-exposes-public-id-et-slugs.md) (slug figé) · [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (CSP stricte) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (Trix hors du bundle commun) · UDR-0006 (CRUD Hotwire) · UDR-0007 (vocabulaire) |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe saisit les cours du catalogue : nom, sous-titre, niveau, série, matière et un contenu mis en forme (gras, listes, titres). Dans l'ancienne application :

- le formulaire occupait une page entière, avec un encart « Import JSON Express » dont la saisie était toujours jetée (CA-09) et un champ d'image de couverture jamais enregistré ;
- le statut se choisissait dans le formulaire, parmi trois cartes, dont « Brouillon — Visible uniquement par vous », qui était faux ;
- le nom passait en `titleize` : « les atouts de la Côte d'Ivoire » devenait « Les Atouts De La Côte D'Ivoire » ;
- la modification levait une erreur avant toute écriture (CA-06) : aucun cours ne se modifiait ;
- la série proposait toutes les séries, même fermées au niveau choisi ;
- la suppression détruisait en cascade les fiches, les exercices, les sessions et les assignations.

## 2. Décision

**Un seul formulaire, `_form`, ouvert dans une modale large (`ui_modal size: :lg`) pour la création comme pour la modification.** Le statut n'y figure pas : il se change par les boutons du panneau de statut (`content_status_panel`), sur la page du cours.

- **Modale plutôt que page.** L'équipe reste sur le catalogue ou sur la page du cours. Au succès, cette page est re-demandée et fusionnée par morphing (`turbo_stream.refresh`) : la carte ou le titre changent sans rechargement de la fenêtre, et sans que B2 rende un partial d'un autre lot.
- **Taille `lg`.** L'éditeur riche a besoin de largeur : sa barre d'outils tient sur une ligne en `lg`, et défile dans sa propre bande sur téléphone.
- **Statut hors du formulaire.** Un cours naît en brouillon. Publier ou archiver sont des transitions nommées (ADR-0035), avec leur journal d'audit. Un choix libre dans un formulaire permettrait le retour au brouillon, qui est interdit.
- **Séries rangées par niveau.** Le menu des séries n'offre que les couples niveau–série ouverts, groupés sous leur niveau (`<optgroup>`). Le filtrage est fait côté serveur, sans Stimulus. Le premier choix, « Aucune série », reste toujours proposé : un cours de premier cycle n'a pas de série. Un couple fermé qui serait envoyé quand même est refusé sous le champ.
- **Éditeur texte seul.** Trix se charge à la demande (contrôleur `rich-text-editor`) et refuse tout fichier, qu'il soit glissé, collé ou choisi : aucune pièce jointe en V1.
- **Archiver, jamais supprimer.** Il n'y a pas de bouton « Supprimer ». L'archivage masque le cours aux élèves et aux enseignants, et garde ses fiches, ses exercices et ses assignations.

## 3. Règles d'implémentation

**Structure**

- `teams/courses/new` et `edit` : `turbo_frame_tag "modal"` → `ui_modal(title:, id: "course-modal", size: :lg, open: true)` → une ligne d'état (`content_status_badge` et une phrase), puis `_form`. Le pied porte « Annuler » (`modal#close`) et le bouton d'envoi, `form: "course-form"`.
- `_form` : `stylesheet_link_tag "trix"` en tête, dans le frame, car une réponse de frame n'apporte pas de `<head>`. Ensuite `form_with scope: :course, id: "course-form"`, avec, dans l'ordre :
  1. Nom : `ui_field`, obligatoire, 200 caractères au plus.
  2. Sous-titre : facultatif, 150 caractères au plus.
  3. Une grille `sm:grid-cols-3` : niveau (`prompt`), série (« Aucune série », puis `optgroup` par niveau), matière (`prompt`).
  4. Le contenu : libellé, conteneur `data-controller="rich-text-editor"`, `f.rich_textarea :content` (id `course_content`), puis une aide reliée par `aria-describedby`.
- Les champs portent des slugs (`level_slug`, `series_slug`, `material_slug`), jamais d'id numérique (ADR-0029).

**Tokens**

- Aucune couleur en dur : `ui_field`, `ui_modal`, `ui_button` et `ui_badge` seulement. Le texte d'aide est en `text-mute`, l'erreur en `text-error`, via `ui_field`.
- Le CSS propre à l'éditeur vient de `builds/trix.css` ; la typographie du contenu vient de `.trix-content`, dans les tokens.

**Comportement**

- `create` et `update` : Turbo Stream avec un toast, `update "modal"` (modale vidée) et `refresh(request_id: nil)`. Le toast survit au morphing du refresh : chaque toast est permanent, avec un id unique (UDR-0006).
- `publish` et `archive` rendent `transition.turbo_stream.erb` : un toast et le `replace` de `content_status_course_<slug>`. Une transition refusée (`:conflict`) répond en **422**, avec un toast d'erreur et le panneau re-rendu dans son état relu.
- Une saisie invalide re-rend `new` ou `edit` en **422** dans la modale : l'erreur est sous son champ, et les valeurs saisies sont conservées, contenu riche compris.
- Repli sans Turbo : chaque écriture redirige en 303 vers la page du cours (`course_path`), avec un flash `notice` ou `alert`.

**États obligatoires**

- Vide : sans objet. Le formulaire de création s'ouvre vide, avec les invites « Choisir un niveau » et « Choisir une matière ».
- Chargement : Turbo marque `aria-busy` pendant l'envoi. La barre d'outils de Trix apparaît dès que le module est chargé.
- Erreur :
  - nom vide, trop long ou déjà pris (même niveau, série et matière) ;
  - niveau ou matière manquant ou inconnu ;
  - série inconnue ou fermée au niveau ;
  - chacune s'affiche sous son champ. Une transition refusée s'affiche dans un toast d'erreur, en `role="alert"`.
- Succès : « Cours « … » créé (brouillon). », « Cours « … » modifié. », « … publié : il est visible des élèves et des enseignants. », « … archivé : il n'est plus visible des élèves ni des enseignants. ».

**Accessibilité**

- La modale est une `<dialog>` native : le focus y reste piégé et Échap la ferme. Le nom reçoit le focus à l'ouverture (`autofocus`).
- L'éditeur `trix-editor` est relié à son libellé (`for="course_content"`) et à son aide (`aria-describedby`).
- Sur téléphone (390 px), ouvrir la modale ne fait jamais défiler la page sur le côté : la barre d'outils de Trix défile dans sa propre bande.

## 4. Conséquences

- La page du cours (Lot B1) porte les points d'entrée : « Modifier » (`edit_teams_course_path`, `data-turbo-frame="modal"`) et le panneau de statut. Le catalogue porte « Nouveau cours ».
- Interdit désormais :
  - un statut choisi dans le formulaire ;
  - le `titleize` du nom ;
  - une série fermée au niveau ;
  - une pièce jointe dans l'éditeur ;
  - la suppression d'un cours.
- Le formulaire des fiches essentielles (Lot B4) peut reprendre la même structure : modale `lg`, éditeur riche, statut hors du formulaire.
