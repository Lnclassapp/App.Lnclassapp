# UDR-0016 : Formulaire fiche essentielle (création, modification, publication, archivage)

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/) (Lot B4 ; CA-12, CA-13, CA-14) |
| **ADR lié** | [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (cycle de vie) · [ADR-0047](../adr/0047-stockage-objet-s3-sur-railway.md) et [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (aucune pièce jointe, CSP stricte) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (Trix hors du bundle commun) · UDR-0006 (CRUD Hotwire) · UDR-0007 (vocabulaire) |
| **Amendé par** | [UDR-0065](0065-gestion-du-blog-par-l-equipe.md) : éditeur riche, images admises pour le blog seul |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe écrit, pour chaque cours, les fiches essentielles que l'élève lit avant de s'exercer. Dans l'ancienne application :

- n'importe quel compte connecté, élève compris, pouvait créer, modifier ou supprimer une fiche en postant directement ;
- la création enregistrait la fiche, puis la réponse plantait : l'équipe voyait une erreur, rechargeait, et risquait un doublon ;
- la modification ne fonctionnait jamais ;
- le nom était passé en `titleize` ;
- un encart « Import JSON Express » inerte et un champ d'image jeté encombraient le formulaire ;
- supprimer une fiche détruisait en cascade ses exercices, leurs questions, les lacunes et les assignations ;
- l'écran disait « Habilité ».

## 2. Décision

**Une modale unique pour créer et modifier, un éditeur riche en texte seul, et un cycle de vie par boutons de statut. Il n'y a pas de suppression.**

- La modale s'ouvre sur la page du cours (« Nouvelle fiche essentielle », lot B1) ou sur la page de la fiche (« Modifier », lot B3). Après l'enregistrement, la page hôte est rafraîchie par morphing : l'équipe voit sa fiche dans la liste sans quitter la page.
- Le contenu se saisit dans Trix (Action Text). Trix est chargé à la demande quand la modale s'ouvre, jamais sur une page de lecture. Il accepte les titres, le gras, l'italique, les listes, les citations et les formules `$…$`. Il refuse tout fichier.
- Une fiche naît en **brouillon**. La modale le dit avant l'enregistrement, et l'édition affiche le statut sans permettre de le changer. Publier et archiver passent par le panneau de statut du socle (`content_status_panel`), sur la page de la fiche.
- Archiver remplace la suppression : les exercices, leurs sessions et les assignations restent (ADR-0036).

Pourquoi une modale plutôt qu'une page : la fiche se lit dans le contexte de son cours, et la modale garde ce contexte sous les yeux (UDR-0006).

## 3. Règles d'implémentation

**Structure**

- Routes : `new_teams_course_essential_path(course_slug)`, `teams_course_essentials_path` (POST), `edit_teams_essential_path(slug)`, `teams_essential_path` (PATCH), `publish_teams_essential_path` et `archive_teams_essential_path` (PATCH). Toutes sont réservées à l'équipe (`Teams::BaseController`).
- `new.html.erb` et `edit.html.erb` : `turbo_frame_tag "modal"`, qui contient `stylesheet_link_tag "trix"` (dans le frame, parce qu'une réponse de frame n'apporte pas son `<head>`), puis `ui_modal(id: "essential-modal", size: :lg, open: true)` et enfin `_form`. Les boutons du pied de modale visent `form: "essential-form"`.
- `new` affiche `#essential-course` (« Cours : … ») et le rappel du brouillon. `edit` affiche `#essential-status` avec `content_status_badge`.
- `_form.html.erb` : `form#essential-form`, avec dans l'ordre :
  - une erreur `base` en tête (`role="alert"`) ;
  - `ui_field` Nom (obligatoire, 150 caractères au plus, avec une aide) ;
  - `ui_field` Sous-titre (150 caractères au plus) ;
  - Contenu : un libellé relié à `trix-editor#essential_content`, placé dans `div[data-controller="rich-text-editor"]`, puis l'aide `#essential_content_hint` et l'erreur `#essential_content_error`.
- Il n'y a ni champ d'image, ni encart d'import JSON. L'import vit dans l'écran des imports (lot I2).

**Tokens**

- Uniquement les tokens `@theme` et les composants `ui_*` (UDR-0005).
- Éditeur : `trix-content`, `rounded-ln`, `border-line` (`border-error` en erreur), `bg-white`, `min-h-48`. La barre d'outils vient de `builds/trix.css`. Son bouton de fichier est masqué par `application.tailwind.css`.

**Comportement**

- Création : `create.turbo_stream.erb`, qui envoie un toast « Fiche essentielle « … » créée (brouillon). » puis `turbo_stream.update "modal"` et `turbo_stream.refresh(request_id: nil)`. La modale se ferme sur `turbo:submit-end` réussi, et le frame est vidé.
- Modification : `update.turbo_stream.erb`, qui envoie un toast, vide la modale et rafraîchit la page.
- Publication et archivage : `transition.turbo_stream.erb`, qui envoie un toast et `replace "content_status_essential_<slug>"` avec `content_status_panel`.
- Refus d'une transition (cours non publié, transition interdite) : **422** et un toast d'erreur, titré « Publication impossible » ou « Archivage impossible », qui en donne la raison. Le panneau reste tel quel.
- Saisie invalide, nom déjà pris dans le cours, pièce jointe ou image dans le contenu : la modale est re-rendue en 422, avec l'erreur sous son champ et les valeurs saisies, contenu compris.
- Repli sans Turbo :
  - création : redirection vers la page du cours ;
  - modification : redirection vers le catalogue, parce que la fiche ne porte que l'identifiant de son cours ;
  - transition : retour à la page du bouton (`redirect_back_or_to`), sinon au catalogue.
- Le nom garde sa casse ; seuls les espaces en trop sont retirés.

**États obligatoires**

- Vide : sans objet (formulaire).
- Chargement : la modale arrive dans son frame ; Trix se charge au `connect` du contrôleur `rich-text-editor`.
- Erreur : 422 dans la modale ; toast d'erreur persistant pour un refus de transition ; 404 pour un cours ou une fiche inconnus ; 403 hors équipe.
- Succès : toast, modale refermée, page hôte à jour sans rechargement de la fenêtre.

**Accessibilité**

- Le libellé « Contenu » vise l'éditeur (`for="essential_content"`). L'éditeur porte `aria-describedby` (aide, puis erreur) et `aria-invalid` en erreur.
- Les boutons du pied de modale ont une cible d'au moins 48 px (`ui_button`). La modale est une `<dialog>` native (focus piégé, Échap).
- Sur téléphone (390 px), la barre d'outils de Trix défile dans sa propre rangée ; la page ne défile jamais sur le côté.

## 4. Conséquences

- Interdits désormais : la suppression d'une fiche, une pièce jointe ou une image dans son contenu, un changement de statut depuis le formulaire, et les mots « Habileté » et « Leçon » (UDR-0007).
- Le formulaire cours (UDR-0014, lot B2) suit la même forme d'éditeur.
- Preuve : `test/system/teams/essential_management_test.rb` crée une fiche (nom déjà pris puis corrigé, gras et liste saisis dans Trix), la rouvre avec son contenu et la renomme, le tout sous `assert_no_page_reload` et sans violation de CSP. Il vérifie aussi qu'un fichier inséré dans l'éditeur est refusé et que la page ne défile pas sur le côté à 390 px.

## Amendement du 2026-10-02 — éditeur du blog (blog)

*Chantier [`docs/chantiers/blog`](../../chantiers/blog/plan.md), Lot 0. Statut : accepté (porteur, 2026-10-02 : délégation). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- La règle « l'éditeur refuse tout fichier » devient : **l'éditeur refuse tout fichier, sauf s'il est posé avec la valeur Stimulus `attachments` vraie**, ce que seul le formulaire d'article du blog fait ([UDR-0065](0065-gestion-du-blog-par-l-equipe.md) §3.4.4, §3.7).
- **Ce formulaire ne change pas** : `teams/essentials/_form` ne pose pas `attachments`, un fichier déposé ou collé y est toujours refusé, et `Repositories::Shared::RichTextSanitizer` retire toujours toute pièce jointe d'une fiche (BL-15).
