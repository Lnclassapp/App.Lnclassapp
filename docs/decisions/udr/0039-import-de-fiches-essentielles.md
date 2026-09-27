# UDR-0039 : Import de fiches essentielles — le slug du cours rappelé dans la modale, l'arbre sous la fiche étage par étage, les fiches à la suite de celles du cours

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot I2 ; critères CA-15, TR-28 |
| **ADR lié** | [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (tout naît en brouillon) · [ADR-0039](../adr/0039-format-d-import-du-contenu.md) (format, cible, import partiel) · [UDR-0006](0006-shell-applicatif-par-role.md) §7 (CRUD Hotwire) · [UDR-0038](0038-import-de-cours.md) (aide de l'arbre étage par étage) · UDR-0007 (vocabulaire) |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe complète un cours existant : elle y ajoute des fiches essentielles, souvent avec leurs exercices.

Dans l'ancienne application, un champ de fichier sur la page du cours (`components/_import_form.html.erb`) envoyait une liste de fiches :

- l'import tournait dans la requête HTTP, sans contrôle de rôle ;
- une fiche invalide était sautée **sans bruit** : aucun rapport, seulement « Habilités importées avec succès. » ;
- l'exemple ne parlait que du nom, du sous-titre et du contenu : aucun exercice ne pouvait suivre la fiche.

Le nouveau format `lnclass.essentials` désigne le cours **dans le fichier**, par son slug (ADR-0039) : un fichier ne peut plus entrer dans un autre cours que celui qu'il nomme. Encore faut-il que l'équipe connaisse ce slug.

## 2. Décision

1. **Le slug du cours est rappelé dans la modale.** Le bouton « Importer des fiches essentielles » de la page du cours ouvre la modale d'import avec `course=<slug>` ; l'aide l'affiche, prêt à recopier, et l'exemple l'utilise déjà. Ouverte depuis l'écran des imports, sans cours, l'aide dit où lire le slug : la fin de l'adresse de la page du cours.
2. **Le slug vient du fichier, jamais de l'adresse.** Le paramètre `course` ne sert qu'à l'aide : c'est la clé `course` de l'enveloppe qui désigne la cible. Un slug inconnu fait rejeter tout le fichier, rien n'est écrit.
3. **L'arbre sous la fiche est celui de l'import des cours** (UDR-0038) : quatre étages (Fiche essentielle, Exercice, Question, Proposition), chacun dans un `<details>`, le premier ouvert. Les exercices sont facultatifs : un fichier de l'ancienne application, sans exercices, reste valide une fois enveloppé.
4. **Les fiches arrivent à la suite de celles du cours**, en brouillon, dans l'ordre du fichier, sans trou de position : une fiche ignorée, en erreur ou refusée à l'écriture ne consomme pas de place.
5. **Le rapport compte les lignes créées** sous les fiches : exercices, questions, propositions. Le nombre de fiches est déjà le compteur « Importés ».
6. **Aucun contrôleur ni écran propre** : la modale, le suivi sans rechargement et le rapport sont ceux de l'écran des imports (socle, UDR-0006 §7). Ce lot ne fournit que le partial du type.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Partial `app/views/teams/imports/kinds/_essentials.html.erb`, rendu par `teams/imports/new` dans le formulaire d'import, sous le champ de fichier.
- `section#import-help-essentials` (`rounded-ln bg-mist p-4 text-sm space-y-4`, `aria-labelledby` sur son titre `h3`) contient, dans l'ordre :
  - le titre « Format du fichier » et une phrase : format `lnclass.essentials`, version 1, la clé `course` désigne le cours par son slug, une fiche et ses exercices par élément de `essentials`, entière ou pas du tout ;
  - `div#import-help-course` (blanc, `border-line`, icône `book-open`) : avec le paramètre `course`, « Cours cible : » suivi du slug en `<code>` et d'un rappel à le recopier ; le slug est reporté dans un champ caché `course`, pour qu'une modale re-rendue en 422 le rappelle encore. Sans paramètre : où lire le slug (`/courses/<slug>`) et le rejet en bloc d'un slug inconnu ;
  - `div#import-help-keys` : quatre `details` blancs (`border-line`), un par étage (Fiche essentielle `essentials[]`, Exercice `exercises[]`, Question `questions[]`, Proposition `answers[]`), le premier ouvert. Chacun contient une `dl` : pour chaque clé canonique, ses alias en `<code>` séparés par « · », puis sa règle. Les alias de l'exercice sont lus dans `UseCases::Catalog::ImportCourseTree::EXERCISE_ALIASES`, jamais recopiés ;
  - « Exemple minimal » : `pre#import-help-example`, une fiche, un exercice, une question Vrai/Faux, avec le slug reçu (ou `genetique-et-evolution`), dans un `<pre><code>` blanc (`border-line`, `font-mono text-xs`, `overflow-x-auto`) ;
  - le rappel du brouillon, de la place à la suite des fiches du cours et des doublons, précédé de l'icône `information-circle`.
- Rapport : les libellés `teams.imports.status.details.exercises_created`, `questions_created`, `answers_created` (ceux de l'UDR-0038) s'affichent dans le bloc « Détails » du suivi du socle.

**Tokens**
- `bg-mist` pour le fond de l'aide, `bg-white` et `border-line` pour le cours cible, les étages et l'exemple, `text-mute` pour les explications, `text-brand` pour les icônes. Aucune valeur arbitraire, aucune classe de l'ancienne application.

**Comportement**
- Ouverture : `new_teams_import_path(kind: "essentials", course: slug)` dans le frame `modal`, depuis le menu de la page du cours (Lot B1) ; `new_teams_import_path(kind: "essentials")` depuis l'écran des imports.
- Téléversement, suivi et rapport : ceux du socle (`create.turbo_stream.erb`, frame `import_status` rechargé toutes les 3 s), sans rechargement de page.
- Doublon : une fiche du même cours au nom égal sans accents, casse ni espaces, en base ou plus haut dans le fichier. Une fiche du même nom dans un autre cours n'est pas un doublon.
- Erreurs d'une fiche notées à la clé canonique et au chemin exact : `essentials[3].name`, `essentials[4].exercises[0].exercise_type`, `essentials[1].exercises[1].questions[2].answers`.

**États obligatoires**
- Avec ou sans cours reçu en paramètre (voir Structure).
- Import terminé : les trois lignes créées dans « Détails ».
- Rejet en bloc (slug inconnu, clé `course` absente), erreur par élément : ceux du socle.

**Accessibilité**
- Chaque `summary` a une cible d'au moins 48 px (`min-h-tap`) ; `details` s'ouvre au clavier.
- Les icônes sont décoratives : le texte porte seul le message.
- Seul l'exemple défile, jamais la modale en largeur.

## 4. Conséquences

- La page du cours (Lot B1) passe `course: slug` au lien « Importer des fiches essentielles » : un autre point d'entrée qui l'omettrait perdrait le rappel du slug, pas la cible.
- Un alias ajouté à `EXERCISE_ALIASES` apparaît de lui-même dans l'aide des deux imports.
- L'adaptateur reprend la construction des exercices, questions et propositions de l'import des cours : un module commun aux trois imports de contenu (I1 à I3) éviterait cette copie, à décider par le porteur.
