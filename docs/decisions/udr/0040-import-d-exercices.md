# UDR-0040 : Import d'exercices — fiche essentielle cible rappelée dans la modale d'import, aide de l'exercice à la proposition, rapport qui compte questions et propositions
<!-- index
titre: Import d'exercices
statut: Accepté
adr-lie: [0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md), [0039](../adr/0039-format-d-import-du-contenu.md)
problematique: Fiche essentielle cible rappelée dans la modale d'import, aide de l'exercice à la proposition, rapport qui compte questions et propositions
-->

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-26 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot I3 ; critères AS-06 (remplacée), TR-28 |
| **ADR lié** | [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (tout naît en brouillon) · [ADR-0039](../adr/0039-format-d-import-du-contenu.md) (format, import partiel) · [UDR-0006](0006-shell-applicatif-par-role.md) §7 (CRUD Hotwire) · [UDR-0038](0038-import-de-cours.md) (aide de l'arbre étage par étage) · UDR-0007 (vocabulaire) |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe remplit une fiche essentielle déjà en place avec des séries d'exercices préparées hors de Lnclass : dix, cent, parfois des milliers de questions.

Dans l'ancienne application, cet import n'existait pas : la route `import_content_engine` d'une fiche essentielle appelait un service jamais écrit, et aucun lien n'y menait (AS-06, écartée). Les exercices ne pouvaient entrer qu'un à un, ou au sein d'un cours complet.

## 2. Décision

1. **L'aide du format vit dans la modale d'import**, sous le champ de fichier, comme pour les établissements (UDR-0037) et les cours (UDR-0038). Trois étages seulement, l'exercice, la question et la proposition, chacun dans un `<details>` : seul l'exercice est ouvert.
2. **La fiche essentielle cible est rappelée en tête de l'aide.** Ouverte depuis une fiche essentielle, la modale reçoit son slug (`essential`) et l'affiche, avec la consigne de le placer dans l'enveloppe ; l'exemple minimal le reprend, prêt à copier. Ouverte sans cible, l'aide dit où citer le slug, et qu'un slug inconnu fait rejeter tout le fichier.
3. **Le brouillon et les erreurs sont dits en clair** : tout arrive en brouillon, à la suite des exercices de la fiche essentielle ; un exercice déjà présent dans cette fiche essentielle est ignoré et compté, jamais modifié ; un exercice dont une question est mal formée est listé avec le chemin de la question et n'entre pas en base, sans empêcher les autres.
4. **Le rapport compte les questions et les propositions créées.** Le nombre d'exercices est déjà le compteur « Importés ».
5. **Aucun contrôleur ni écran propre** : la modale, le suivi sans rechargement et le rapport sont ceux de l'écran des imports (socle, UDR-0006 §7). Ce lot ne fournit que le partial du type.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Partial `app/views/teams/imports/kinds/_exercises.html.erb`, rendu par `teams/imports/new` dans le formulaire d'import, sous le champ de fichier.
- `section#import-help-exercises` (`rounded-ln bg-mist p-4 text-sm space-y-4`, `aria-labelledby` sur son titre `h3`) contient, dans l'ordre :
  - le titre « Format du fichier » et une phrase : format `lnclass.exercises`, version 1, fiche essentielle cible citée par son slug dans `essential`, un exercice entier ou pas du tout ;
  - `div#import-help-essential` blanc (`border-line`), précédé de l'icône `document-text` : avec le paramètre `essential`, « Fiche essentielle cible : » et le slug (passé par `parameterize`, comme l'adaptateur le lit) en `<code>` ; sans lui, la consigne de citer le slug ;
  - `div#import-help-keys` : trois `details` blancs (Exercice `exercises[]`, Question `questions[]`, Proposition `answers[]`), le premier ouvert. Chacun contient une `dl` : pour chaque clé canonique, ses alias en `<code>` séparés par « · », puis sa règle. Les alias de l'exercice sont lus dans `UseCases::Assessment::ImportExercises::ALIASES`, jamais recopiés ;
  - « Exemple minimal » : `pre#import-help-example`, un exercice et une question Vrai/Faux, avec le slug reçu ou un slug d'exemple ;
  - le rappel du brouillon et des erreurs, précédé de l'icône `information-circle`.
- Rapport : les libellés `teams.imports.status.details.questions_created` et `answers_created` (posés par l'import de cours, UDR-0038) s'affichent dans le bloc « Détails » du suivi du socle.

**Tokens**
- `bg-mist` pour le fond de l'aide, `bg-white` et `border-line` pour la cible, les étages et l'exemple, `text-mute` pour les explications, `text-brand` pour les icônes. Aucune valeur arbitraire, aucune classe de l'ancienne application.

**Comportement**
- Ouverture : `new_teams_import_path(kind: "exercises", essential: <slug>)` dans le frame `modal`. Le bouton « Importer des exercices » de la fiche essentielle appartient à l'écran de la fiche essentielle ; ce lot le prouve par `open_in_modal`, le Lot E par le vrai bouton.
- Téléversement, suivi et rapport : ceux du socle (`create.turbo_stream.erb`, frame `import_status` rechargé toutes les 3 s), sans rechargement de page.
- Erreurs notées à la **clé canonique** et au chemin exact, quel que soit l'alias du fichier : `exercises[3].title`, `exercises[4].questions[1].answers`.
- Positions : à la suite des exercices de la fiche essentielle, lues au moment d'écrire ; aucun trou pour un exercice écarté.

**États obligatoires**
- Sans paramètre `essential` : la consigne de citer le slug, et l'exemple avec un slug d'exemple.
- Import terminé : questions et propositions créées dans « Détails » ; aucune ligne si aucun exercice n'a été écrit.
- Fiche essentielle inconnue ou absente de l'enveloppe : « Rejeté », rien n'est écrit (socle).

**Accessibilité**
- Chaque `summary` a une cible d'au moins 48 px (`min-h-tap`) ; `details` s'ouvre au clavier.
- Les icônes sont décoratives : le texte porte seul le message.
- Seul l'exemple défile en largeur, jamais la modale.

## 4. Conséquences

- La clé de doublon d'un exercice est `(fiche essentielle, titre normalisé)` : casse et accents ignorés, espaces réduits mais comptés, comme le port `ExerciseRepositoryPort#existing_keys` et l'ADR-0039 §4 le disent. Aligner sur la règle des cours (espaces ignorés, `NaturalKey.compact`) demanderait de changer ce port : à trancher par le porteur.
- Le lien « Importer des exercices » depuis la fiche essentielle reste à poser par le lot de cet écran.
