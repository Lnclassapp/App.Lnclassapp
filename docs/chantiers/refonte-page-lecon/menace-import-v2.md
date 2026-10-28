# Menace — import `lnclass.course-tree` v2 (Lot D)

> Écrite avant la validation du code de l'import v2 (règle CLAUDE.md « Menace écrite d'abord »). Le Lot D lit un fichier
> JSON envoyé par un membre de l'équipe contenu ; ce qu'il écrit est ensuite affiché aux élèves (le **sujet**, ADR-0113 §4.4,
> rendu par UDR-0138 : `simple_format` puis KaTeX).

## Qui envoie, et ce qu'il gagne

- **Qui** : un compte équipe au rôle contenu (`Policies::Catalog::ManageContentPolicy`, tenue par le registre `ImportKind`).
  Un élève, un enseignant ou un anonyme n'atteint pas l'import.
- **Scénarios retenus** : un compte contenu compromis, ou un fichier préparé ailleurs (par un outil, une IA, un tiers)
  qu'un membre de l'équipe importe de bonne foi. Le fichier est donc traité comme hostile.
- **Ce qu'il viserait** : exécuter du script chez les élèves, publier sans relecture, saturer la base ou les pages,
  écraser une leçon existante, faire planter l'import sans trace.

## Ce qu'un fichier piégé peut tenter, ce qui l'arrête, le test qui le prouve

| # | Attaque | Ce qui l'arrête | Preuve |
|---|---|---|---|
| M1 | **Taille** : fichier énorme | 20 Mo par fichier (`ImportKind::MAX_BYTES`), 50 fichiers et 50 Mo par envoi (`course_tree`), refusés avant lecture | `test/domain/dtos/catalog/import_upload_input_test.rb` (`too_large`, `total_too_large`) |
| M2 | **JSON illisible ou trop profond** (imbrication > 100) | `JSON.parse` lève `ParserError` (dont `NestingError`), le fichier est rejeté « illisible », sans écriture | `test/domain/use_cases/catalog/run_import_test.rb` (fichier illisible) ; **à ajouter** : un fichier imbriqué à 101 niveaux est rejeté illisible |
| M3 | **Clés inconnues, mauvais types** | Schéma v2 `additionalProperties: false` à chaque niveau, `version` = 2 exacte, `format` exact | `import_course_tree_test` : « a version 3 envelope is rejected in bloc, with zero writes » ; « a version 1 file is still checked by its own schema » |
| M4 | **Nombre de leçons** | 500 leçons au plus par envoi (`max_roots`), refus en bloc au-delà | garde du moteur `RunImport`, testée sur les autres imports ; **à ajouter** : 501 leçons refusées en bloc |
| M5 | **Nombre d'exercices** | Règle ADR-0113 : exactement 1 par notion et 4 sur la leçon, sinon la leçon entière est refusée | CA-27 (4 tests : notion sans exercice, deux sur une notion, autre chose que 4, clé absente) |
| M6 | **Nombre de notions, de questions, de réponses** | Aucun plafond propre ; seulement le plafond de taille (M1). Un fichier de 20 Mo peut porter des dizaines de milliers de questions | **Écart** : voir « À trancher » (Q1) ; le test de performance `PERF=1` (200 leçons v2) passe en 16 s |
| M7 | **Sujet très long** (`statement`) | Aucun plafond : colonne `text`, schéma sans `maxLength`. Un sujet de plusieurs Mo serait stocké puis envoyé à chaque élève | **Écart** : voir « À trancher » (Q2) |
| M8 | **Sujet vide** | Refus : « the subject is required, notion exercise or lesson-wide exercise » | `import_course_tree_test` |
| M9 | **Script dans le sujet ou une question** (`<script>`, `onerror=`, `javascript:`) | Le sujet est du texte brut : `simple_format` assainit et échappe ; les questions passent par les validations existantes du v1 ; titres et noms bornés (`TITLE_MAX`, `NAME_MAX`) | **À ajouter** (Lot D) : un sujet `<script>…</script><img src=x onerror=…>` est stocké tel quel et la page du sujet (Lot C) le rend échappé — test de rendu dans le Lot C, qui affiche le sujet |
| M10 | **Formule piégée** (`$\href{javascript:…}$`, `\htmlId`, macros en boucle) | KaTeX auto-render avec `trust: false` par défaut (`math_controller.js`) : `\href`, `\url`, `\html…` sont refusés ; `maxExpand` (1000) borne les macros ; `throwOnError: false` affiche l'erreur en texte | **À ajouter** (Lot C, rendu) : `\href{javascript:alert(1)}{x}` ne produit aucun lien |
| M11 | **Publier sans relecture** (`status: "published"`) | La clé `status` est ignorée : tout entre en brouillon, au nom de l'auteur de l'import | « a full course is written in draft, whatever its status, by the importing author » |
| M12 | **Réimport** : écraser une leçon existante | L'import ne met jamais à jour : un nom déjà pris reçoit un slug suffixé, une nouvelle leçon en brouillon est créée | « a slug taken in base or in the file gets a suffix » ; **à ajouter** : réimporter Thalès laisse la première leçon et ses exercices intacts |
| M13 | **Fichier v1** (ancien format) | Toléré : leçon et notions entrent, exercices ignorés et comptés au rapport (« Exercices ignorés (format v1) : N ») ; validé par son propre schéma v1 | CA-28 ; « a version 1 file without exercise gives no warning » ; « a version 1 file and a version 2 file in one envoi » |
| M14 | **Exercice rattaché à une autre leçon** (notion d'une autre leçon) | Les exercices sont construits depuis l'arbre du fichier, jamais par identifiant fourni ; `EssentialOutsideCourse` (`exercise_repository.rb:101`) doit être traduit en erreur `:invalid` (reprise de la revue du Lot 0) | **À ajouter** dans le Lot D avec ce correctif |
| M15 | **Échec silencieux** (import à moitié écrit) | Écriture en transaction ; une leçon refusée n'écrit rien ; au-delà de 1 000 erreurs, seul le compteur avance (`MAX_ERRORS`) | « … rejected in bloc, with zero writes » ; CA-27 |
| M16 | **Image de question** | Le fichier n'annonce qu'une description (150 caractères), jamais une image ni une adresse : pas de téléchargement, pas de SSRF | schéma (`question_image`) |

## À trancher par le porteur

- **Q1 — plafonds de nombre (M6).** Proposition : au plus 50 notions par leçon, 30 questions par exercice et 10 réponses
  par question, dans le schéma v2 (`maxItems`) et donc refusés avant toute écriture. Sans cela, seule la taille du fichier
  borne la charge.
- **Q2 — longueur du sujet (M7).** Proposition : 5 000 caractères au plus (`maxLength` du schéma v2 et constante
  `Exercise::STATEMENT_MAX` vérifiée par `ContentNode`). Le plus long des 8 sujets Thalès fait moins de 500 caractères.

## Ce qui reste hors du Lot D

- Le rendu du sujet (M9, M10) est celui du Lot C : ses tests d'échappement et de KaTeX y vivent.
- `script/contenus/valider.rb` et les consignes de rédaction de `docs/contenus/` ne connaissent que le v1 : chantier contenu.
