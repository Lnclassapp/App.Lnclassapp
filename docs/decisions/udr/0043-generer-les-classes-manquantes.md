# UDR-0043 : Générer les classes manquantes — bouton secondaire de l'écran Établissements, confirmation qui dit qui est concerné, suivi dans le rapport des imports

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/generer-classes`](../../chantiers/generer-classes/prd.md) |
| **ADR lié** | [ADR-0056](../adr/0056-generation-des-classes-manquantes.md) · [ADR-0030](../adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md) · [ADR-0039](../adr/0039-format-d-import-du-contenu.md) · [UDR-0036](0036-gestion-des-etablissements.md) · [UDR-0037](0037-import-des-etablissements.md) · [UDR-0042](0042-actions-de-ligne-dans-un-menu.md) |
| **Remplacé par** | — |

---

## 1. Contexte

3 851 établissements ont été importés avant le référentiel et n'ont aucune classe (ADR-0056). L'équipe doit pouvoir leur donner leurs classes d'un seul geste, sans craindre d'abîmer les établissements qui en ont déjà, et voir ensuite ce qui a été fait. Le geste porte sur l'ensemble des établissements, pas sur un objet : ce n'est pas une action de ligne (UDR-0042), c'est une action de page, comme « Importer des établissements ».

## 2. Décision

1. **Un bouton secondaire dans l'en-tête de l'écran Établissements**, à gauche de « Importer des établissements » qui reste l'action principale. Pas dans un menu ⋮ : il ne porte sur aucun objet.
2. **Une confirmation en `<dialog>`** (jamais `confirm()`) qui dit, avant tout, **qui est concerné** : les établissements actifs ou en brouillon sans aucune classe de l'année scolaire en cours ; le barème (public/privé, collège = premier cycle) ; la source (niveaux, séries et liaisons actuels) ; et que les autres ne sont jamais modifiés. Une génération qui touche 79 000 classes ne part pas sur un clic distrait.
3. **Le suivi est celui des imports** : on arrive sur le rapport de la génération (`/teams/imports/:public_id`), rechargé toutes les 3 s tant qu'elle tourne, puis dans l'historique de l'écran des imports, filtrable par « Génération des classes ». Pas de nouvel écran ni de WebSocket. Pourquoi une redirection plutôt qu'un Turbo Stream dans la page : la génération dure des dizaines de secondes, le rapport a déjà son écran de suivi.
4. **Les mots du rapport suivent le type** : pour une génération, on parle d'établissements dotés et de classes, pas de fichier ni de doublons.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `app/views/teams/schools/index.html.erb`, bloc de `ui_page_header`, dans cet ordre :
  1. `ui_modal title: t(".generate_title"), id: "generate-classrooms-modal", trigger: t(".generate"), trigger_variant: :secondary, trigger_icon: "sparkles"` ;
     - corps : `form_with url: classroom_generations_path, id: "generate-classrooms-form"`, contenant `p` d'introduction (`.generate_intro`), puis `ul#generate-classrooms-rules` (`list-disc pl-5 space-y-1 text-sm text-mute`) de trois règles : `.generate_rule_scope` (établissements actifs ou en brouillon **sans aucune classe de l'année scolaire %{year}**, en `strong`), `.generate_rule_plan` (barème de l'import : public/privé, collège = premier cycle, à partir des niveaux, séries et liaisons actuels), `.generate_rule_untouched` (les autres ne sont jamais modifiés ; relancer est sans risque) ; puis `p` `.generate_background` (arrière-plan, rapport dans « Imports ») ;
     - pied : « Annuler » (`ui_button variant: :secondary`, `data-action="modal#close"`) puis « Lancer la génération » (`ui_button type: :submit, form: "generate-classrooms-form", icon: "sparkles"`).
  2. « Importer des établissements », inchangé (UDR-0036).
- L'état vide de la liste ne propose pas la génération (il n'y a pas d'établissement).
- Route : `POST /teams/schools/classroom-generations` (`classroom_generations_path`), `Teams::ClassroomGenerationsController#create`.
- Rapport (`teams/imports`) :
  - `_import_row` : sans fichier, le lien vers le rapport porte `teams.imports.import_row.no_file` (« Voir le rapport ») ;
  - `show` : sans fichier, titre = `import_kinds.<kind>` et sous-titre `teams.imports.show.subtitle_without_file` (auteur · date) ;
  - `_status` : chaque libellé (`phases.*`, `processed`, `counters.*`, `failed`) est d'abord cherché sous `teams.imports.status.by_kind.<kind>.*`, sinon celui des imports ;
  - `index` : le filtre liste `ImportKind::REPORT_KINDS` ; le menu « Nouvel import » reste limité à `ImportKind::KINDS`.

**Tokens**
- Aucun nouveau : `ui_button` `secondary` et `primary`, `ui_modal` taille `md`, `text-mute`, `text-ink` pour le `strong`. Icône `sparkles`.

**Comportement**
- Le formulaire vit hors de tout Turbo Frame : Turbo Drive suit la réponse.
- Succès : `303` vers `teams_import_path(public_id)`, flash `notice` « Génération des classes lancée. » (toast).
- Déjà en cours (`:conflict`) : `303` vers `schools_path`, flash `alert` « Une génération des classes est déjà en cours. Suivez-la dans « Imports ». » (toast d'erreur).
- Refus (`:forbidden`) : page 403 (`render_result`).
- La modale se ferme sur `turbo:submit-end` (`modal#submitEnd`).

**États obligatoires**
- Vide : sans objet (le bouton est toujours proposé à l'équipe ; zéro candidat donne un rapport terminé à zéro).
- Chargement : bouton de confirmation `aria-busy` pendant la soumission (Turbo) ; puis le suivi du rapport (`progress`, « N établissements traités »).
- Erreur : toast d'erreur « déjà en cours » ; rapport `failed` avec son message propre au type.
- Succès : toast, puis rapport terminé : établissements dotés, sans classe à générer, en erreur, examinés ; « Classes générées : N » ; niveaux et séries sautés s'il y en a.

**Accessibilité**
- Le déclencheur porte `aria-haspopup="dialog"` et `aria-controls="generate-classrooms-modal"` (composant `ui_modal`) ; la `<dialog>` est nommée par son titre.
- Échap et « Annuler » ferment sans rien lancer ; le focus revient au déclencheur (navigateur).
- Cibles ≥ 48 px (`ui_button`) ; le périmètre est dit en texte, jamais par la seule couleur.

## 4. Conséquences

- Toute future action de masse sur une liste (tous les objets, pas un seul) suit ce patron : bouton secondaire d'en-tête, confirmation qui dit le périmètre, job suivi par un rapport.
- L'écran des imports affiche des rapports qui ne sont pas des imports : chaque nouveau type sans fichier fournit ses libellés sous `teams.imports.status.by_kind.<kind>`.
- UDR-0036 : l'en-tête de l'écran Établissements gagne cette seconde action ; « Importer des établissements » reste l'action principale.

## Amendement du 2026-09-28 — menu « Classes »

*Chantier [`docs/chantiers/bareme-classes`](../../chantiers/bareme-classes/prd.md), demande du porteur du 2026-09-28, [UDR-0045](0045-bareme-des-classes.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Le bouton secondaire devient une entrée de menu.** L'en-tête de `teams/schools/index` porte, dans cet ordre : « Importer des établissements » (principale, inchangée), puis le menu **« Classes »** : `ui_dropdown(label: "Actions sur les classes", id: "schools-classrooms-menu", fixed: true, trigger: icône rectangle-group + « Classes »)` — déclencheur libellé avec chevron, pas un ⋮ : ces actions portent sur l'ensemble des établissements, pas sur un objet (UDR-0042 réserve le ⋮ aux objets).
- Entrées : « Générer les classes manquantes » (`ui_dropdown_item dialog: "generate-classrooms-modal"`, icône `sparkles`), puis « Barème des classes » (`href: classroom_plan_path`, icône `calculator`).
- La confirmation `dialog#generate-classrooms-modal` est rendue **sans `trigger:`**, sœur du menu ; son contenu, son pied, sa route et le suivi dans le rapport ne changent pas. L'entrée de menu l'ouvre (`dropdown#openDialog`), le focus revient au déclencheur à la fermeture.
- La règle de la phrase du barème (`generate_rule_plan`) renvoie au « barème des classes » (ADR-0058), plus au « barème de l'import ».
- Pas de libellé « Génération en cours » dans ce menu : ce comportement n'existe pas sur cette branche (chantier parallèle `finitions-generation-menu`) ; s'il arrive, il se place sur l'entrée « Générer les classes manquantes ».
- Preuve : `test/controllers/teams/classroom_generations_controller_test.rb` (menu à droite de l'import, entrées, confirmation) ; `test/system/school/generate_classrooms_test.rb` (bureau et 390 px : ouvrir le menu, confirmer la génération, ouvrir le barème).
