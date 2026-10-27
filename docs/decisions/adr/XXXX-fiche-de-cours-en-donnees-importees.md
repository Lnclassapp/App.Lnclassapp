# ADR-XXXX : Une fiche de cours est un document de blocs importé, rendu par des composants communs et une liste fermée de figures
<!-- index
titre: Fiche de cours en données importées, figures en liste fermée
statut: Proposé
problematique: Où vit le contenu d'une fiche de cours à l'identique des maquettes, et comment une figure propre à une fiche reste maintenable
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-27 |
| **Chantier** | `docs/chantiers/contenu-en-blocs` (#318) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le 2026-10-27, les maquettes des fiches de cours (Thalès, Lentilles, Texte argumentatif, `docs/design/fiches-cours/`) deviennent le cahier des charges, en haute fidélité. Une fiche y est un cahier de 3 pages : cours en sections, encadrés, lexique en bulle, explications simples, figures interactives, exercices corrigés dans la page, « Je m'entraîne » et rédaction libre.

Aujourd'hui le contenu d'une leçon (`Course`) et de ses fiches essentielles (`Essential`) est un texte Action Text, importé en JSON (`lnclass.essentials` v1) par le moteur commun `RunImport`. Ce format ne sait porter ni un exercice dans la page, ni un mot du lexique, ni une figure.

Deux voies : une vue ERB écrite à la main par fiche, ou un document de données rendu par des composants communs. 213 leçons attendent leur conversion (chantier à part) : le format choisi ici sera celui de cette conversion.

## 2. Moteurs de décision

1. Ajouter une fiche ne doit pas demander de code, sauf pour une figure ou un générateur nouveau.
2. Le design des maquettes se reproduit une seule fois, dans des composants communs.
3. Le fichier importé est envoyé par un membre de l'équipe : il est lu comme un fichier hostile (menace ci-dessous).
4. Le domaine reste en Ruby pur ; la validation des blocs y vit.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Une vue ERB par fiche | Fidélité immédiate, aucune structure à concevoir | Du code par fiche : la conversion des 213 leçons devient impossible, le design se recopie 3 fois puis 213 |
| B — Document de blocs en `jsonb`, composants communs, figures en liste fermée | Le contenu est une donnée, le design n'existe qu'une fois ; une figure reste du code testé | Retenue |
| C — HTML ou SVG libre dans l'import | Souple, aucune liste à tenir | Injection de script par le fichier importé ; contraire à la CSP stricte (ADR-0049) |

## 4. Décision

> **Nous stockons une fiche de cours comme un document de blocs (`jsonb`) dans une table `course_sheets`, une par leçon, importé au format `lnclass.course-sheet` v1 par le moteur `RunImport`. La vue rend chaque type de bloc par un partial commun. Une figure interactive, une figure fixe ou un générateur d'exercices est désigné par un `kind` pris dans une liste fermée ; chaque `kind` est un partial et un contrôleur Stimulus, ses réglages sont dans les données.**

- **Table** `course_sheets` : `course_id` (unique), `theme` (liste fermée : `blue`, `teal`, `burgundy`), `document` (`jsonb`), `format_version`, horodatage. Le cycle de publication est celui de la leçon.
- **Document** : `pages[]` → `sections[]` (titre numéroté) → `blocks[]`, plus `glossary` (`{clé: [titre, définition, exemple]}`).
- **Types de blocs** (liste fermée, validée par `Catalog::SheetDocument`) : `paragraph`, `box` (propriété, à retenir), `simple` (explication simple), `steps`, `table`, `figure` (`kind`), `media` (`kind`), `exercise`, `practice`, `writing`.
- **Texte en ligne** : une chaîne avec un balisage restreint — `[[clé|mot]]` pour le lexique, `$…$` pour KaTeX, `**gras**`, `*italique*`. Aucun HTML : le rendu échappe tout, puis transforme ces seules marques.
- **Exercices** : champs `numeric` (virgule ou point, tolérance ±0,011), `choice` (options), `choice` figé au premier clic ; `hint` et `correction` facultatifs. La correction se fait dans le navigateur : les réponses sont dans la page, sans note ni lacune.
- **`kind` en liste fermée** : `thales_figure`, `lens_simulator`, `lens_construction`, `argument_highlighter` (médias) ; figures fixes des lentilles ; générateurs `thales_ratio` et `bank` (banque d'énoncés écrite dans les données). Un `kind` inconnu fait refuser le fichier.

### Menace écrite d'abord (fichier importé)

| Menace | Parade |
|---|---|
| Script injecté par une chaîne (XSS) | Aucun HTML accepté ; échappement puis balisage restreint ; CSP inchangée |
| Fichier énorme ou profond (mémoire, temps) | 1 Mo au plus ; nombre de pages, sections, blocs et champs bornés par le schéma ; JSON seul |
| Paramètre de figure hors bornes (boucle, figure illisible) | Chaque `kind` déclare ses paramètres et leurs bornes dans le schéma ; refus sinon |
| Lien sortant ou ressource distante | Aucune URL acceptée dans le document |
| Fichier en partie valide | Refus entier, rapport par bloc (page, section, position, raison), comme `RunImport` aujourd'hui |

## 5. Conséquences

- **Positives** : une fiche nouvelle est un fichier JSON ; le design vit une fois ; la conversion des 213 leçons a un format cible.
- **Négatives** : chaque figure ou générateur nouveau demande un lot de code ; le schéma JSON et `Catalog::SheetDocument` doivent rester d'accord (un test les confronte).
- **Neutres** : `Essential` et ses exercices ne changent pas ; une leçon peut avoir ses fiches essentielles et une fiche de cours.
- Complète ADR-0039 (format d'import), ADR-0049 (CSP, polices hébergées par Lnclass).
