# UDR-0037 : Import des établissements — aide du format dans la modale d'import, slugs des DRENA à portée de main, rapport qui compte les classes générées

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot S3 ; critères SC-03, SC-08, SC-09 |
| **ADR lié** | [ADR-0030](../adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md) (classes générées) · [ADR-0039](../adr/0039-format-d-import-du-contenu.md) (format, import partiel) · [UDR-0006](0006-shell-applicatif-par-role.md) §7 (CRUD Hotwire) · [UDR-0035](0035-gestion-des-drena.md) (slug des DRENA) · [UDR-0036](0036-gestion-des-etablissements.md) (aucune création à l'écran) · UDR-0007 |
| **Remplacé par** | — |

---

## 1. Contexte

Un établissement n'entre dans Lnclass **que par l'import JSON** (décision du porteur du 2026-09-25). Ses classes naissent avec lui : lycée public 77, lycée privé ou mixte 38, collège public 28. L'équipe charge ainsi toutes les écoles du pays, DRENA par DRENA, souvent avec les fichiers de l'ancienne application.

Dans l'ancienne application, l'import d'écoles tenait en un champ de fichier sur la page d'une DRENA :

- aucun mot sur le format : les clés acceptées (`name` ou `nom`, `schooltype`…) ne se lisaient que dans le code ;
- aucun rapport : une école refusée disparaissait sans bruit, et l'équipe ne savait ni combien de classes avaient été créées, ni pourquoi un niveau manquait ;
- la DRENA était implicite (la page ouverte) : impossible de répartir un fichier sur plusieurs DRENA.

## 2. Décision

1. **L'aide du format vit dans la modale d'import**, sous le champ de fichier, là où l'équipe prépare son fichier. Elle ne remplace pas une documentation : elle dit juste ce qu'il faut pour réussir du premier coup. Sont listés : les clés acceptées avec leurs alias, un exemple minimal, et le rappel de la génération des classes.
2. **Les slugs des DRENA sont dans la modale**, repliés dans un `<details>`. Le fichier cite la DRENA par son slug : l'équipe le copie sans quitter l'import. S'il n'existe aucune DRENA, l'aide renvoie vers l'écran des DRENA, puisque les DRENA ne s'importent jamais.
3. **Le rapport compte les classes générées**, et signale les niveaux et séries sautés **seulement s'il y en a**. Un rapport sans saut reste court ; un saut (une 1ère sans série liée, par exemple) se voit avec son nombre.
4. **Aucun contrôleur ni écran propre** : la modale, le suivi sans rechargement et le rapport sont ceux de l'écran des imports (socle, UDR-0006 §7). Ce lot ne fournit que le partial du type.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Partial `app/views/teams/imports/kinds/_schools.html.erb`, rendu par `teams/imports/new` dans le formulaire d'import, sous le champ de fichier.
- `section#import-help-schools` (`rounded-ln bg-mist p-4 text-sm space-y-4`, `aria-labelledby` sur son titre `h3`) contient, dans l'ordre :
  - le titre « Format du fichier » et une phrase : format `lnclass.schools`, version 1, DRENA citée par son slug dans l'enveloppe ou sur une école ;
  - une `dl` des clés : pour chaque clé canonique (`name`, `sigle`, `status`, `type`, `cycle`, `drena`), ses alias en `<code>` séparés par « · », puis sa règle (obligatoire ou non, valeurs permises, défaut). Les alias sont lus dans `UseCases::School::ImportSchools::ALIASES`, jamais recopiés ;
  - « Exemple minimal » : l'exemple de l'ADR-0039 dans un `<pre><code>` blanc (`border-line`, `font-mono text-xs`, `overflow-x-auto`), une clé par ligne ;
  - le rappel des classes, précédé de l'icône `information-circle` : barème par type et cycle, « Aucun établissement existant n'est modifié : un doublon est ignoré et compté » ;
  - `details` « Slugs des DRENA (N) » : `ul#import-help-drenas` en deux colonnes dès `sm`, hauteur bornée (`max-h-48`, défilement vertical), chaque ligne `<code>slug</code>` puis le nom. Sans DRENA, un `p#import-help-drenas` et le lien « Ouvrir les DRENA » (`data-turbo-frame="_top"`).
- Rapport : les libellés `teams.imports.status.details.classrooms_created`, `skipped_levels`, `skipped_series` s'affichent dans le bloc « Détails » du suivi du socle.

**Tokens**
- `bg-mist` pour le fond de l'aide, `bg-white` et `border-line` pour l'exemple et la liste des DRENA, `text-mute` pour les explications, `text-brand` pour l'icône, `text-brand-strong` pour le lien. Aucune valeur arbitraire, aucune classe de l'ancienne application.

**Comportement**
- Ouverture : `new_teams_import_path(kind: "schools")` dans le frame `modal` (bouton « Importer des établissements » de l'écran des établissements, ou menu « Nouvel import »).
- Téléversement, suivi et rapport : ceux du socle (`create.turbo_stream.erb`, frame `import_status` rechargé toutes les 3 s), sans rechargement de page.
- Erreurs d'un élément notées à la **clé canonique**, quel que soit l'alias du fichier : `schools[3].type`, `schools[6].name`, `schools[249].drena`.

**États obligatoires**
- Sans DRENA : phrase et lien vers l'écran des DRENA.
- Import terminé sans saut : seules les classes générées dans « Détails ».
- Import avec saut : « Niveaux sautés » ou « Séries sautées » et leur nombre.
- Rejet en bloc, erreur par élément : ceux du socle.

**Accessibilité**
- Le `summary` des DRENA a une cible d'au moins 48 px (`min-h-tap`) ; `details` s'ouvre au clavier.
- L'icône d'information est décorative (`aria-hidden`) : le texte porte seul le message.
- Seul l'exemple défile en largeur, jamais la modale.

## 4. Conséquences

- Les lots d'import I1, I2 et I3 peuvent reprendre la même aide : titre, clés et alias, exemple minimal, rappel de ce que l'import écrit, et liste de ce que le fichier doit citer.
- Un alias ajouté à `ALIASES` apparaît de lui-même dans l'aide.
- L'écran des établissements (UDR-0036) garde « Importer des établissements » comme seule entrée : aucune création unitaire ne revient.
