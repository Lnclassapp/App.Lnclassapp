# UDR-0055 : Import de plusieurs fichiers — résumé de la sélection dans la modale, bilan par fichier dans le suivi, nom de l'import dans l'historique, suivi rafraîchi chaque seconde

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-30 |
| **Chantier** | [`docs/chantiers/import-cours-multiple`](../../chantiers/import-cours-multiple/memo.md) |
| **ADR lié** | [ADR-0068](../adr/0068-import-de-plusieurs-fichiers-de-cours-et-ecriture-acceleree.md) · [ADR-0039](../adr/0039-format-d-import-du-contenu.md) |
| **Complète** | [UDR-0038](0038-import-de-cours.md) (import de cours) · [UDR-0006](0006-shell-applicatif-par-role.md) §7 (CRUD Hotwire) · [UDR-0054](0054-finitions-d-interface.md) (titre d'onglet) |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe met en ligne les leçons rédigées, à raison d'un fichier par leçon. Aujourd'hui, la modale d'import n'accepte qu'un fichier : pour 10 leçons, il faut 10 ouvertures, 10 choix et 10 attentes. Le suivi, rechargé toutes les 3 s, fait attendre jusqu'à 4 s un bilan qui tient en une seconde de traitement. Enfin, rien ne dit **quel fichier** a apporté quoi : un cours ignoré comme doublon n'est pas nommé.

## 2. Décision

1. **Un seul champ, en sélection multiple**, seulement pour les cours complets. On ne crée pas de zone de dépôt ni de liste éditable : le sélecteur natif du poste reste le plus fiable, sur téléphone comme sur ordinateur. Pour corriger une sélection, on choisit de nouveau.
2. **Un résumé sous le champ**, dès le choix : le nombre de fichiers, leur taille totale, puis les noms. Un dépassement de limite s'affiche tout de suite et désactive l'envoi, pour ne pas faire attendre la fin d'un envoi de 50 Mo avant de le refuser. Le serveur refait tous les contrôles.
3. **Le bilan gagne une section « Fichiers »**, une ligne par fichier et dans l'ordre d'envoi, sous les « Détails » et avant les erreurs. On y voit d'un coup d'œil quel fichier renvoyer.
4. **Une erreur nomme son fichier** quand l'import en compte plusieurs, dans une étiquette au-dessus du chemin. Le chemin reste celui du fichier (`courses[0].essentials[1].name`), pour qu'on le retrouve dans son éditeur.
5. **L'historique et l'en-tête du rapport** nomment l'import par son premier fichier : « limites.json et 9 autres fichiers ».
6. **Le suivi se recharge toutes les secondes** tant que l'import tourne, pour tous les types de rapport. Il n'y a toujours ni WebSocket ni diffusion.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Modale de téléversement — `app/views/teams/imports/new.html.erb`

**Structure**
- `definition.multiple_files?` décide du mode. En mode simple (établissements, DRENA, fiches, exercices), le rendu est **identique** à aujourd'hui, à deux détails près : le champ s'appelle `import[files][]`, et il n'a pas l'attribut `multiple`.
- En mode multiple (cours complets) :
  - `form.file_field :files, multiple: true, accept: ".json,application/json", required: true`, id `import_files`, mêmes classes que le champ actuel, `aria-describedby="import_io_hint import_files_summary"` (plus `import_io_error` en cas d'erreur).
  - Le texte d'aide `p#import_io_hint` dit `teams.imports.new.limits_multiple` : « Jusqu'à %{files} fichiers .json, %{total} Mo au total, %{megabytes} Mo au plus par fichier, %{roots} cours au plus en tout. »
  - Sous l'aide, `div#import_files_summary` (`aria-live="polite"`, `space-y-2 text-sm`) est vide au rendu. Il contient :
    - `p#import_files_count` (`font-medium text-ink`) : « %{count} fichier(s) · %{size} », où la taille est formatée côté navigateur en Ko (arrondi à l'unité) sous 1 Mo, et en Mo (une décimale) au-dessus, avec la virgule décimale ;
    - `ul#import_files_list` (`max-h-40 overflow-y-auto rounded-ln border border-line bg-white divide-y divide-line`) : un `li` par fichier (`flex items-baseline justify-between gap-3 px-3 py-1.5`), avec le nom en `span.truncate.text-ink` et la taille en `span.shrink-0.tabular-nums.text-mute` ;
    - `p#import_files_error` (`role="alert"`, `flex items-center gap-1.5 font-medium text-error`, icône `exclamation-circle` mini), présent seulement en cas de dépassement.

**Comportement — contrôleur Stimulus `teams--import-files`** (`app/javascript/controllers/teams/import_files_controller.js`)
- Posé sur le `form` en mode multiple : `data-controller="teams--import-files"`, `data-teams--import-files-max-files-value`, `-max-total-bytes-value` et `-max-file-bytes-value`, lus dans le registre (`definition.max_files`, `definition.max_total_bytes`, `ImportKind::MAX_BYTES`). Les libellés sont passés en `data-teams--import-files-*-text-value`, depuis les clés `teams.imports.new.files_summary.*`. **Aucun texte en dur dans le JavaScript.**
- Cibles : `input` (le champ), `summary`, `count`, `list`, `error`, `submit` (le bouton « Importer » du pied de modale, qui porte `form="import-upload-form"`).
- `change->teams--import-files#refresh` sur le champ. Le contrôleur vide puis remplit la liste en construisant des nœuds DOM (`textContent`, **jamais** `innerHTML` : le nom d'un fichier n'est pas du HTML sûr).
- Dépassements, dans cet ordre, **un seul message** à la fois : plus de `max_files` fichiers (`too_many_files`), un fichier qui ne finit pas par `.json` (`not_json`, qui le nomme), un fichier au-delà de `max_file_bytes` (`file_too_large`, qui le nomme), un total au-delà de `max_total_bytes` (`total_too_large`). Si l'un d'eux s'applique, `submit.disabled = true` et `aria-invalid="true"` sur le champ. Sinon, le bouton est réactivé et `aria-invalid` retiré.
- Aucun fichier choisi : le résumé est vidé, et le bouton reste actif (le `required` du navigateur joue).
- Sans JavaScript : pas de résumé, et les contrôles du serveur s'appliquent (422, erreur sous le champ).

**États obligatoires**
- Vide : aucun résumé. **Chargement** : sans objet, le résumé est immédiat. **Erreur** : `p#import_files_error`, bouton désactivé ; erreur du serveur, rendue en 422 sous le champ comme aujourd'hui (`import_io_error`). **Succès** : le compteur et la liste.

### 3.2 Suivi — `app/views/teams/imports/_status.html.erb`

- Quand l'import est `completed` **ou** `rejected` et que `import.files` n'est pas vide, une section `section#import_files` (`aria-labelledby="import_files_title"`) est rendue après « Détails » et avant les erreurs. Elle contient :
  - `h3#import_files_title` (`mb-2 text-sm font-medium`) : `teams.imports.status.files_title`, soit « Fichiers (%{count}) » ;
  - `ul` (`divide-y divide-line rounded-ln border border-line`) ; un `li` par fichier (`flex flex-col gap-1 px-4 py-2 sm:flex-row sm:items-baseline sm:justify-between sm:gap-4`), avec :
    - le nom en `span.min-w-0.truncate.font-medium.text-ink`, et son `title` porte le nom complet ;
    - pour un fichier lu : « %{imported} importé(s) · %{skipped} ignoré(s) · %{errors} en erreur » (`text-sm text-mute tabular-nums`). Un compteur à zéro est affiché ;
    - pour un fichier refusé : `ui_badge t(".file_rejected"), tone: :error`, suivi du motif traduit par `import_error_message` sur l'erreur de ce fichier (`text-sm text-error`).
- La liste est plafonnée par le registre (50 lignes). Elle ne défile pas à part : c'est la page ou la modale qui défile.

### 3.3 Erreurs — `app/views/teams/imports/_import_errors.html.erb`

- Si `error.file` est présent, un `span.font-medium.text-ink.text-xs` avec le nom du fichier est rendu **avant** le `code` du chemin, dans le même bloc `shrink-0` (`flex flex-col`). Sans fichier, le rendu est inchangé.
- Nouveau motif `duplicate_in_files` : `teams.imports.errors.duplicate_in_files`, soit « Ce cours est aussi dans %{other} : aucun des deux n'est importé. »

### 3.4 Historique et en-tête du rapport

- `_import_row.html.erb` et le `subtitle` de `show.html.erb` utilisent `import_files_label(import)`, défini dans `Teams::ImportsHelper` :
  - aucun fichier → `teams.imports.import_row.no_file` (inchangé) ;
  - 1 fichier → son nom ;
  - N fichiers → `teams.imports.files_label`, soit « %{first} et %{count} autre(s) fichier(s) », avec `count = N - 1`.
- Les queries du suivi et de l'historique lisent le premier nom et le nombre de fichiers **sans N+1**, par une sous-requête ou un agrégat sur les pièces jointes. Le nombre de requêtes de la page des imports reste celui d'aujourd'hui.

### 3.5 Rafraîchissement du suivi

- `app/javascript/controllers/teams/import_status_controller.js` : `INTERVAL = 1000`. Rien d'autre ne change : le frame `import_status` s'arrête à la fin et à la déconnexion.

**Tokens**
- Uniquement `bg-white`, `bg-mist`, `border-line`, `divide-line`, `text-ink`, `text-mute`, `text-error`, `rounded-ln`, les tons `ui_badge` existants, et l'échelle d'espacement de Tailwind. Aucune valeur arbitraire.

**Accessibilité**
- Le résumé est annoncé (`aria-live="polite"`), et le message de dépassement porte `role="alert"`.
- Le champ reste la cible de 48 px de hauteur utile (`file:min-h-tap`). Le bouton désactivé garde `disabled`, pas une simple classe.
- Les noms de fichier longs sont tronqués visuellement (`truncate`), mais lisibles en entier (`title`).
- Les compteurs ne reposent pas sur la couleur : chaque compteur a son libellé.

## 4. Conséquences

- Un autre type d'import qui voudrait plusieurs fichiers n'aura qu'à changer son `max_files` dans le registre : la modale et le suivi suivent. Le registre refuse cependant un type avec cible (ADR-0068).
- Les libellés de la modale, du suivi et de l'historique au pluriel passent par `count:` (i18n), jamais par une concaténation.
- Le partial d'aide `kinds/_course_tree` (UDR-0038) ajoute une phrase : on peut choisir jusqu'à 50 fichiers, qui forment un seul import.
