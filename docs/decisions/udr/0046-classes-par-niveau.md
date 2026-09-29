# UDR-0046 : Classes par niveau — sur la fiche d'un établissement, compter les classes de chaque niveau, ajouter la suivante, retirer la dernière

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-28, défauts compris)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/classes-par-niveau`](../../chantiers/classes-par-niveau/prd.md) (CN-01 à CN-10) |
| **ADR lié** | [ADR-0059](../adr/0059-ajuster-les-classes-d-un-niveau.md) · [ADR-0041](../adr/0041-vie-d-une-classe-annee-scolaire-et-code.md) · [ADR-0036](../adr/0036-suppression-archivage-et-anonymisation.md) · UDR-0006, UDR-0031, UDR-0036, UDR-0042 |
| **Remplacé par** | — |

> Numéro : la plus haute UDR existante sur `Develop` au 2026-09-28 (0043) **+ 3**, pour éviter les collisions avec les chantiers menés en parallèle.

---

## 1. Contexte

Sur la fiche d'un établissement (UDR-0036), les classes de l'année sont groupées par niveau, en cartes : pour savoir combien un lycée a de Tle D, l'équipe compte des cartes. Pour ajuster le barème, elle ne peut qu'« Ajouter une classe » en modale, nom saisi à la main, et ne peut rien retirer. Au téléphone, où l'équipe reçoit souvent l'appel de l'établissement, la liste des classes d'un lycée public fait 77 cartes.

## 2. Décision

- **Un bloc compact, en tête de la section des classes**, avant les cartes : une ligne par niveau (par couple niveau/série au second cycle), avec son nombre et un compteur « − n + ». Au téléphone, il reste au-dessus des 77 cartes ; au bureau, deux colonnes (trois en très large) le gardent court.
- **« − » et « + » plutôt qu'un champ nombre + « Enregistrer »** : un geste = une classe = une ligne d'audit ; le retrait d'une classe précise se confirme en la nommant, ce qu'un nombre cible ne permettrait pas.
- **« + » sans confirmation** (il se défait par « − ») ; **« − » toujours confirmé** dans une `<dialog>` qui nomme la classe et dit qu'elle sera supprimée définitivement.
- **Mise à jour sans rechargement** : le bloc est remplacé (morphing) dans la réponse Turbo Stream, puis la fiche est re-demandée et fusionnée (`refresh`, comme UDR-0031), ce qui met à jour le titre « Classes (N) » et les cartes.
- **Un refus ne ferme pas la page sur une erreur** : toast d'erreur au motif précis, bloc re-rendu (la confirmation se referme), rien ne change.

## 3. Règles d'implémentation

**Structure**
- `teams/schools/show` : dans `section#school_classrooms`, juste après le titre et l'année, `render "level_classrooms", block: @level_classrooms` — `@level_classrooms` est le `Block` de `Queries::School::LevelClassroomsQuery` (établissement, statut, lignes).
- `teams/schools/_level_classrooms` : `<section id="school_level_classrooms" aria-labelledby="school_level_classrooms_title">`, carte `rounded-card border border-line bg-white shadow-card`.
  1. En-tête `px-4 pt-4 sm:px-5` : `h3#school_level_classrooms_title` « Classes par niveau » (`font-display text-lg font-extrabold`) ; aide `text-sm text-mute` « Ajoutez la classe suivante du niveau, ou retirez la dernière si elle n'a jamais servi. »
  2. Établissement non actif : `p#school_level_classrooms_inactive` `text-sm text-warning`, « Seul un établissement actif reçoit de nouvelles classes. » (le brouillon et le désactivé n'ont pas de « + »).
  3. Aucun niveau (référentiel vide) : `ui_empty_state` « Aucun niveau au référentiel » / « Créez les niveaux et les séries avant d'ajuster les classes. », icône `academic-cap`.
  4. Sinon `ul.grid.gap-x-6.px-4.pb-2.sm:grid-cols-2.2xl:grid-cols-3.sm:px-5` ; une `li#level_classrooms_<clé>` par ligne (`clé` = `<slug niveau>` ou `<slug niveau>-<slug série>`), `flex items-center justify-between gap-3 border-t border-line py-2` (la bordure haute sépare aussi les deux colonnes de leur en-tête) :
     - libellé `span.font-medium.min-w-0.truncate` : « 6ème », « Tle D » ;
     - `div[role=group]` au nom accessible « Tle D : 2 classes » : bouton « − », nombre `span.w-8.text-center.font-display.text-lg.font-extrabold.tabular-nums` (`aria-hidden`, le groupe porte déjà le nombre), bouton « + ».
- « − » (ligne > 0) : `ui_modal title: "Retirer la classe « Tle D 2 » ?", id: "remove-classroom-<clé>", size: :sm, trigger: <icône minus + libellé sr-only « Retirer une classe de Tle D »>, trigger_variant: :secondary`. Corps : `form_with url: school_level_classroom_path(school, dernière classe), method: :delete, id: "remove-classroom-<clé>-form"`, texte « Elle sera supprimée définitivement. Une classe qui a déjà eu un élève, un enseignant ou un cours assigné ne peut pas l'être : archivez-la plutôt. » Pied : « Annuler » (`modal#close`) · « Retirer la classe » (`variant: :danger`, `form=`).
- « − » (ligne à 0) : `ui_button` `secondary`, `disabled: true`, même contenu.
- « + » (établissement actif et couple ouvert) : `form_with url: school_level_classrooms_path(school), method: :post` avec `level` et `series` cachés, `ui_button type: :submit, variant: :secondary`, icône `plus`, libellé sr-only « Ajouter une classe de Tle D ». Sinon, rien (l'espace reste réservé par un `span.w-tap` pour aligner les nombres).

**Tokens**
- Composants `ui_button`, `ui_modal`, `ui_empty_state`, `ui_icon` uniquement ; `border-line`, `text-mute`, `text-warning`, `shadow-card`, `rounded-card`. Aucune valeur arbitraire.

**Comportement**
- `POST /teams/schools/:school_public_id/level-classrooms` (`level`, `series`) → `Teams::LevelClassroomsController#create` ; `DELETE …/level-classrooms/:public_id` → `#destroy`.
- Réponse unique `teams/level_classrooms/update.turbo_stream.erb`. Succès (Turbo Stream) : toast de succès — « Classe « 6ème 5 » ajoutée. Code : KFM37 » (code par `JoinCode.display`) ou « Classe « 6ème 5 » retirée. » ; `replace "school_level_classrooms"` en `method: :morph` ; `refresh(request_id: nil)`.
- Refus (Turbo Stream, 422 ; 404 pour une classe déjà retirée) : toast d'erreur au motif du use case, `replace "school_level_classrooms"` (la `<dialog>` se referme). 403 : toast d'erreur « forbidden » seul.
- Sans Turbo : redirection 303 vers la fiche, `notice` ou `alert` au même texte.
- Aucun contrôleur Stimulus nouveau : `modal` (UDR-0005) pour la confirmation. Le morphing du bloc retire `open` d'une boîte ouverte par `showModal()` : `modal` observe cet attribut et referme alors vraiment la boîte (`close()`), sinon elle resterait dans la couche supérieure et la page serait inerte (bug du 2026-09-28, PR #48). Après un refus, la page doit rester utilisable sans rechargement (test système).

**États obligatoires**
- Vide : référentiel sans niveau (`ui_empty_state`) ; ligne à 0 (« − » désactivé). Chargement : état occupé de Turbo sur le formulaire soumis (bouton désactivé pendant l'envoi). Erreur : toast d'erreur, bloc inchangé. Succès : toast, nombre à jour, fiche fusionnée.

**Accessibilité**
- « − » et « + » font au moins 48 px de haut et de large (`min-h-tap`, `ui_button` `md`) ; au téléphone (390 px), le libellé se tronque, jamais les boutons, et la page ne défile pas horizontalement.
- Chaque bouton a un nom accessible qui dit le niveau (« Retirer une classe de 6ème »). Le groupe annonce le nombre (« 6ème : 4 classes ») ; le toast (`role=status`) annonce le résultat.
- Le déclencheur « − » porte `aria-haspopup="dialog"` et `aria-controls` ; la `<dialog>` est nommée par son titre ; Échap et « Annuler » la ferment.

## 4. Conséquences

- La section des classes de la fiche commence par ce bloc ; les cartes par niveau (UDR-0036) restent la liste détaillée.
- « Ajouter une classe » (UDR-0031) reste le geste pour un nom libre ou un plafond différent.
- Tout nouveau compteur de classes de la fiche doit se lire dans le même périmètre (année en cours, archivées comprises) pour rester égal à la somme des lignes.
