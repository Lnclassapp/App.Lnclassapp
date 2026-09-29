# UDR-0053 : Import des DRENA — bouton « Importer des DRENA » à côté de « Nouvelle DRENA », aide du format dans la modale d'import

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-29 |
| **Chantier** | [`docs/chantiers/import-drenas`](../../chantiers/import-drenas/prd.md) — critères DR-10, DR-01 |
| **ADR lié** | [ADR-0066](../adr/0066-import-des-drena-et-slug-prefixe.md) (import des DRENA, slug `drena-`) · [UDR-0035](0035-gestion-des-drena.md) (écran des DRENA) · [UDR-0037](0037-import-des-etablissements.md) (aide d'un type d'import) · [UDR-0006](0006-shell-applicatif-par-role.md) §7 |
| **Remplacé par** | — |

---

## 1. Contexte

À chaque remise en service, l'équipe saisit les 41 DRENA une par une dans la modale « Nouvelle DRENA », avant de pouvoir importer les établissements. Une faute de frappe décale le slug, et toutes les écoles de cette DRENA sont rejetées à l'import (ADR-0066).

L'UDR-0035 a posé l'écran des DRENA avec un seul bouton d'en-tête. Le porteur demande que **la création au formulaire reste**, et qu'un bouton d'import se place **à côté**.

## 2. Décision

1. L'en-tête de l'écran des DRENA porte deux boutons côte à côte : « Importer des DRENA » (secondaire) puis « Nouvelle DRENA » (principal, inchangé).
2. « Importer des DRENA » ouvre la modale d'import du socle, avec le type DRENA déjà choisi. Il n'y a ni écran ni parcours nouveau : téléversement, suivi et rapport sont ceux des autres imports.
3. La modale montre une aide propre aux DRENA : le format, la seule clé `name`, un exemple, et la règle du slug `drena-`. Elle suit le même gabarit que l'aide des établissements (UDR-0037).
4. Les textes qui expliquent le slug (sous-titre, aides des modales « Nouvelle DRENA » et « Modifier », exemple de l'aide des établissements) citent le slug préfixé.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `app/views/teams/drenas/index.html.erb`, bloc de `ui_page_header`, dans cet ordre :
  1. `ui_button t(".import"), href: new_teams_import_path(kind: "drenas"), variant: :secondary, icon: "arrow-up-tray", data: { turbo_frame: "modal" }` — libellé « Importer des DRENA » ;
  2. le bouton « Nouvelle DRENA » existant, inchangé (`icon: "plus"`, variant par défaut).
  Les deux sont dans `div#drenas-header-actions.flex.flex-wrap.items-center.gap-3.sm:shrink-0.sm:flex-nowrap`, dans le bloc de `ui_page_header` : dès `sm`, ils restent sur une seule ligne et le sous-titre cède la place ; sur téléphone, ils passent à la ligne s'ils ne tiennent pas. C'est le motif de `#schools-header-actions`. *(Amendé le 2026-09-29 : le challenger a vu les boutons empilés à 1 280 px.)*
- L'état vide de l'écran (`div#drenas_empty`) garde son titre, mais sa description devient « Créez la première DRENA, ou importez-les toutes depuis un fichier JSON. ». Aucun bouton n'est ajouté dans l'état vide : ceux de l'en-tête suffisent.
- Nouveau partial `app/views/teams/imports/kinds/_drenas.html.erb`, rendu automatiquement par `teams/imports/new` sous le champ de fichier (même mécanisme que `_schools`) :
  - `section#import-help-drenas` (`rounded-ln bg-mist p-4 text-sm space-y-4`), avec `aria-labelledby="import-help-drenas-title"` sur son `h3#import-help-drenas-title` « Format du fichier » (`font-medium text-ink`) ;
  - un `p.text-mute` : « Format `lnclass.drenas`, version 1. Chaque DRENA ne porte que son nom. » (clé `intro_html`, les noms techniques en `<code>`) ;
  - une `dl` d'une seule entrée : `dt` = `<code class="font-mono text-xs text-ink">name</code>`, `dd.text-mute` = « Obligatoire, 80 caractères au plus. Le nom est enregistré tel quel, espaces normalisés. » ;
  - « Exemple minimal » (`h4.font-medium.text-ink`), puis un `<pre><code>` blanc (`overflow-x-auto rounded-ln border border-line bg-white p-3 font-mono text-xs text-ink`) contenant exactement :
    ```
    {
      "format": "lnclass.drenas",
      "version": 1,
      "drenas": [
        { "name": "Abidjan 1" },
        { "name": "Bouaké 1" }
      ]
    }
    ```
  - la règle du slug, précédée de `ui_icon "information-circle", variant: :mini, size: :sm, class: "mt-0.5 shrink-0 text-brand"` dans un `div.flex.items-start.gap-2.text-ink` : « Le slug est tiré du nom, préfixé par drena- : « Bouaké 1 » devient drena-bouake-1. C'est lui que citent les fichiers d'établissements. Une DRENA dont le slug existe déjà est ignorée et comptée : aucune DRENA existante n'est modifiée. » Les slugs sont en `<code>`.
- `app/views/teams/imports/kinds/_schools.html.erb` : dans l'exemple, `"drena": "abidjan-1"` devient `"drena": "drena-abidjan-1"` et `"drena": "abidjan-2"` devient `"drena": "drena-abidjan-2"`. Rien d'autre ne change.

**Libellés (fr)**
- `import_kinds.drenas` : « DRENA ». La modale s'intitule donc « Importer : DRENA », et le suivi « Import : DRENA ».
- `teams.drenas.index.import` : « Importer des DRENA ».
- `teams.drenas.index.subtitle` : « Les directions régionales de l'éducation nationale. Les établissements s'importent dans une DRENA, par son slug drena-… ».
- `teams.drenas.form.name_hint_new` : « Le slug est tiré du nom et préfixé par drena- à la création, puis ne change plus : c'est lui que citent les fichiers d'import. »
- `teams.imports.error_codes.taken` : « Ce nom est déjà pris par une autre DRENA. »
- `teams.imports.index.subtitle` : « DRENA, établissements, cours, fiches essentielles et exercices importés depuis un fichier JSON. »
- Le filtre par type de l'écran des imports liste « DRENA » parmi les types, sans code de vue nouveau : il lit le registre.

**Tokens**
- Uniquement les composants `ui_*` et les tokens `@theme` déjà utilisés par l'UDR-0037 : `bg-mist`, `bg-white`, `border-line`, `text-mute`, `text-ink`, `text-brand`. Aucune valeur arbitraire (`[…]`), aucun `#hex`.

**Comportement**
- Clic sur « Importer des DRENA » : `GET /teams/imports/new?kind=drenas`, servi dans le frame `modal`, sans rechargement.
- Téléversement réussi : `teams/imports/create.turbo_stream.erb` du socle (toast « Import lancé. », modale remplacée par le suivi, frame `import_status` rechargé toutes les 3 s). Le `prepend "imports"` n'a pas de cible sur l'écran des DRENA et reste sans effet.
- Le tableau des DRENA **n'est pas** mis à jour en direct pendant l'import. À la fin, le suivi affiche le bilan, et l'équipe recharge ou rouvre l'écran pour voir les nouvelles lignes. Aucun Turbo Stream ni broadcast n'est ajouté.
- Échec du téléversement (fichier absent, trop gros, pas du JSON) : re-rendu en 422 dans la modale, comme les autres types.
- Erreurs par ligne : chemins `drenas[i].name` dans le rapport du socle.
- *(Amendé le 2026-09-29, pour tous les types d'import.)* Une erreur de schéma du rapport (`code: "schema"`) s'affiche par `Teams::ImportsHelper#import_error_message`, selon son mot-clé json_schemer, avec les clés `teams.imports.schema_keywords.<mot-clé>` : `schema` → « Clé inconnue : ce format ne la prévoit pas. », `required` → « Clé obligatoire manquante. », `string` → « Valeur attendue : un texte. », `array` → « Valeur attendue : une liste. », `object` → « Valeur attendue : un objet. », etc. Un mot-clé sans phrase, ou une erreur sans mot-clé, affiche « Valeur non conforme au format attendu. ». Le mot-clé brut ne paraît jamais à l'écran.

**États obligatoires**
- Vide (aucune DRENA) : l'état vide de l'écran, avec la description ci-dessus. Les deux boutons de l'en-tête restent visibles.
- Chargement : le suivi du socle, avec les statuts « En file d'attente », « Vérification », « Import en cours ».
- Erreur : rejet en bloc ou erreurs par ligne, affichés par le rapport du socle. L'erreur de téléversement s'affiche sous le champ, avec `aria-invalid`.
- Succès : toast « Import lancé. », puis le rapport « Terminé » avec ses compteurs.

**Accessibilité**
- Chaque bouton de l'en-tête a un libellé visible explicite (« Importer des DRENA », « Nouvelle DRENA »). L'icône est décorative.
- Cibles tactiles ≥ 48 px (`ui_button`).
- La `section` d'aide est nommée par son titre (`aria-labelledby`), et l'icône d'information est `aria-hidden` : le texte porte seul le message.
- Seul l'exemple défile en largeur, jamais la modale.
- Ordre de tabulation dans l'en-tête : « Importer des DRENA », puis « Nouvelle DRENA ».

## 4. Conséquences

- L'écran des DRENA a deux entrées : un nom à la main, ou toutes d'un coup par fichier. Le formulaire n'est ni retiré ni modifié, en dehors de ses textes d'aide.
- Toute nouvelle aide de type d'import suit le gabarit `import-help-<type>` (UDR-0037, puis 0053).
- Il est désormais interdit de citer un slug de DRENA sans le préfixe `drena-` dans un exemple, une aide ou une doc.
