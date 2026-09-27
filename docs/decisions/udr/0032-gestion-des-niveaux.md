# UDR-0032 : Gestion des niveaux (référentiel de l'équipe)

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/) (Lot R1 ; CA-16, CA-18, CA-25) |
| **ADR lié** | [ADR-0029](../adr/0029-identifiants-exposes-public-id-et-slugs.md) (slug figé) · [ADR-0034](../adr/0034-reprise-des-donnees-et-referentiel-seede.md) (référentiel créé par l'équipe) · [ADR-0036](../adr/0036-suppression-archivage-et-anonymisation.md) (suppression refusée) · UDR-0006 (CRUD Hotwire) |
| **Remplacé par** | — |

---

## 1. Contexte

La production démarre vide (ADR-0034) : l'équipe crée elle-même les niveaux, de la 6ème à la Tle, avant toute classe et tout cours. Le slug d'un niveau est le code du plan de génération des classes et des imports (`6eme` … `tle`, ADR-0030).

Dans l'ancienne application, les niveaux se géraient depuis un onglet « Setup » du tableau de bord et depuis `/levels`, avec trois défauts :

- le formulaire annonçait « Maximum 10 caractères » alors que la base en accepte 20 ;
- modifier un niveau inconnu répondait 500 ;
- supprimer un niveau détruisait **en cascade** tous ses cours et toutes ses classes, derrière un simple « Supprimer ce niveau ? ».

L'équipe ne voyait ni le code d'un niveau, ni ce qui l'utilisait.

## 2. Décision

**Un écran « Niveaux », un tableau trié par position, des modales pour écrire.**

- Le tableau montre, pour chaque niveau : son nom, son **code** (le slug), sa position, son cycle, ses séries liées et ce qui l'utilise (nombre de classes et de cours). L'équipe voit avant d'agir qu'un niveau est utilisé.
- Une aide au-dessus du tableau dit pour quels niveaux les classes sont générées (6ème, 5ème, 4ème, 3ème, 2nde, 1ère, Tle). Un niveau dont le code n'est pas une clé du plan porte le badge « Hors génération des classes » ; le formulaire rappelle les noms reconnus sous le champ Nom. Un niveau mal nommé se voit à la création, pas à la génération.
- La création et la modification se font dans la modale du layout (UDR-0006). La position suivante est proposée. En modification, le code est affiché en lecture seule avec la mention qu'il ne change jamais : renommer « 6ème » en « Sixième » garde `6eme`.
- La suppression se confirme **dans la page** : une `<dialog>` propre à la ligne, ouverte sans requête. On n'utilise pas `confirm()` du navigateur, qui est illisible sur mobile et n'explique rien. Un niveau lié à une série, ou utilisé par une classe ou un cours, **n'est jamais supprimé**. Le refus nomme ce qui le retient (« 1 série, 2 classes et 1 cours »), et la ligne reste en place.

## 3. Règles d'implémentation

**Structure**

- Route : `GET /teams/levels` (`levels_path`), `param: :slug` ; réservée à l'équipe (`Teams::BaseController`).
- `app/views/teams/levels/index.html.erb` : `ui_page_header` (titre, sous-titre, action « Nouveau niveau » en `ui_button` avec `data-turbo-frame="modal"`), l'aide `p#levels-generation-help` (codes lus dans `LevelsQuery::GENERATED_SLUGS`, union des clés du plan public et privé), puis un conteneur `relative overflow-x-auto` qui porte la `<table>`. Le corps du tableau est `tbody#levels`. Sans niveau, `div#levels_empty` rend `ui_empty_state`.
- `_level_row.html.erb` : `tr#level_<slug>`. Colonnes : Nom (suivi, hors génération, d'un `ui_badge` `warning` `sm` dans `[data-generation=outside]`, avec `title` et texte `sr-only`) · Code (`<code>`) · Position · Cycle · Séries (`ui_badge` taille `sm`, ou « Aucune ») · Classes · Cours · actions. Les actions sont « Modifier » (`ui_button` `secondary` `sm`, lien vers la modale) et « Supprimer » (`ui_modal` avec `trigger:`, `id: "delete-level-<slug>"`). Le pied de cette modale porte « Annuler » et « Supprimer le niveau » (`danger`), qui vise `form#delete-level-<slug>-form` (DELETE).
- `new.html.erb` et `edit.html.erb` : `turbo_frame_tag "modal"` → `ui_modal(id: "level-modal", open: true)` → `_form` (`form#level-form`) ; le bouton d'envoi, dans `modal.footer`, vise `form: "level-form"`. `edit` affiche `#level-code`, avec le même badge si le code est hors génération.
- `_form.html.erb` : `ui_field` Nom (`maxlength` 20), Position (`number`, 0 à 999), Cycle (`select` : Premier cycle, Second cycle). Une erreur `base` s'affiche en tête dans un `role="alert"`.

**Tokens**

- Uniquement les tokens `@theme` et les composants `ui_*` (UDR-0005) ; aucune classe de l'ancienne application.
- Code du niveau : `font-mono text-xs text-mute` dans le tableau, `bg-mist` et `rounded-ln` pour l'encart de la modale.

**Comportement**

- Création : `create.turbo_stream.erb` → toast de succès, `remove "levels_empty"`, `replace "levels"`. Le tableau est rendu de nouveau dans l'ordre des positions ; la modale se ferme sur `turbo:submit-end` réussi.
- Modification : `update.turbo_stream.erb` → toast, `replace "levels"` (une position modifiée change l'ordre).
- Suppression réussie : `destroy.turbo_stream.erb` → toast, `remove "level_<slug>"`.
- Suppression refusée (`:conflict`) : **422**, toast d'erreur titré « Ce niveau est utilisé » avec la raison, et `replace "level_<slug>"`, qui referme la confirmation.
- Saisie invalide, nom ou position déjà pris : la modale est re-rendue en 422 avec l'erreur sous son champ et les valeurs saisies.
- Repli sans Turbo : chaque écriture redirige vers `levels_path` avec un flash (`notice`, ou `alert` pour un refus).

**États obligatoires**

- Vide : « Aucun niveau pour l'instant », avec l'invitation à créer les niveaux de la 6ème à la Tle.
- Chargement : sans objet (page rendue côté serveur, modales chargées dans leur frame).
- Erreur : 422 dans la modale ; toast d'erreur persistant pour un refus de suppression ; 404 pour un niveau inconnu.
- Succès : toast, et le tableau mis à jour sans rechargement de la page.

**Accessibilité**

- Toutes les actions ont une cible ≥ 48 px (`ui_button`, taille `sm` agrandie).
- « Modifier » porte un `aria-label` qui nomme le niveau. La colonne des actions a un en-tête `sr-only`, contenu par le `relative` du conteneur : il n'élargit pas la page sur mobile.
- La confirmation est une `<dialog>` native (focus piégé, Échap) ; le toast de refus porte `role="alert"`.

## 4. Conséquences

- Cette forme (tableau, modale, confirmation dans la page, refus en 422 qui nomme la raison) peut servir de modèle aux écrans Séries (R2) et Matières (R3), sans les contraindre : leurs UDR décident.
- Interdit désormais sur cet écran : la suppression en cascade d'un niveau, une confirmation par `confirm()` du navigateur, et un formulaire qui modifie le slug.
- Preuve : `test/system/teams/levels_test.rb` crée, renomme et supprime un niveau vierge, échoue à supprimer un niveau utilisé, rouvre la modale en 422, le tout sous `assert_no_page_reload`, et vérifie que la page ne défile pas latéralement sur mobile.
