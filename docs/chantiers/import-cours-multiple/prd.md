# PRD — Importer plusieurs fichiers de cours en une fois

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Chaque leçon rédigée donne un fichier de cours complet, et l'écran d'import n'en accepte qu'un à la fois, un import de cours à la fois ([memo](memo.md)). L'équipe pourra choisir jusqu'à 50 fichiers d'un coup : ils forment **un seul import**, avec un seul bilan qui détaille chaque fichier. En même temps, le traitement devient deux fois plus rapide (500 cours en 20 s au plus, contre environ 40 s), et l'écran de suivi se rafraîchit toutes les secondes au lieu de toutes les 3 s.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team (tout rôle interne) | Choisir 1 à 50 fichiers de cours complets et les importer en une fois ; suivre le bilan par fichier | Envoyer plusieurs fichiers pour un autre type d'import ; mettre à jour un cours existant par import |
| Teacher, Student, Parent, SchoolStaff | — | Ouvrir la modale d'import ou poster des fichiers |

Règle d'autorisation : `Policies::Catalog::ManageContentPolicy` (équipe seulement), appliquée par le registre des types d'import, à l'envoi puis à nouveau au lancement du traitement. Rien ne change sur ce point.

## 3. Parcours utilisateur

### Chemin nominal

1. Sur l'écran des cours, ou depuis le menu « Nouvel import » de l'écran des imports, l'équipe ouvre l'import « Cours complets ».
2. Elle choisit 10 fichiers `.json` dans le sélecteur de fichiers de son poste.
3. Sous le champ, la modale affiche « 10 fichiers · 842 Ko » puis la liste des noms.
4. Elle clique « Importer ». La modale passe au suivi, qui se rafraîchit toutes les secondes : « Validation… », puis « Écriture… ».
5. En moins de 3 s pour 10 cours, le suivi affiche « Terminé » : 10 importés, 0 ignoré, 0 en erreur, 10 au total, puis les lignes créées (fiches, exercices, questions, propositions) et **une ligne par fichier** (« limites-et-continuite.json — 1 importé »).
6. Dans l'historique des imports, la ligne de cet import s'appelle « limites-et-continuite.json et 9 autres fichiers ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Un fichier seul | Comme aujourd'hui : un import, un bilan, des chemins d'erreur sans nom de fichier. Le bilan montre en plus la ligne de ce fichier |
| Un fichier illisible (JSON invalide), d'un autre format ou d'une autre version, parmi d'autres fichiers valides | Ce fichier est **refusé** avec son motif, et ses cours ne sont pas comptés. Les autres fichiers sont importés. L'import est « Terminé » |
| Tous les fichiers sont refusés | L'import est « Rejeté », rien n'est écrit, et le bilan liste chaque fichier avec son motif |
| Plus de 500 cours au total dans les fichiers lisibles | L'import est « Rejeté » (`too_many_roots`), rien n'est écrit |
| Le même cours (nom normalisé, niveau, matière, série) dans deux fichiers de l'envoi, absent de la base | Le cours est en erreur dans **les deux** fichiers (`duplicate_in_files`, qui nomme l'autre fichier). Le reste des deux fichiers est importé |
| Le même cours dans deux fichiers, et déjà en base | Il est ignoré dans les deux fichiers, comme doublon de la base |
| Le même cours deux fois dans un même fichier | Le second est ignoré, comme aujourd'hui |
| Un cours invalide dans un fichier | Erreur du cours, avec le nom du fichier et le chemin `courses[i]…` dans ce fichier. Les autres cours sont importés |
| 51 fichiers ou plus, plus de 50 Mo au total, un fichier de plus de 20 Mo, ou un fichier qui ne finit pas par `.json` | Dans la modale : le message s'affiche dès le choix et le bouton « Importer » se désactive. Si la requête arrive quand même, le serveur la refuse en 422, avec l'erreur sous le champ, et ne crée aucun rapport |
| Aucun fichier | Envoi impossible (champ requis), et le serveur refuse une requête sans fichier en 422 |
| Deux fichiers du même nom, pris dans deux dossiers | Deux lignes distinctes dans le bilan, numérotées dans l'ordre d'envoi : « cours.json », « cours.json (2) » |
| Plusieurs fichiers pour un autre type d'import (établissements, DRENA, fiches, exercices) | Le champ n'accepte qu'un fichier, et le serveur refuse une requête qui en porte plusieurs en 422 |
| Un import de cours déjà en cours | Refus « Un import de ce type est déjà en cours. », comme aujourd'hui |
| Un traitement interrompu (redéploiement) | Les cours déjà écrits restent, l'import passe « Échoué » au bout de 10 min, comme aujourd'hui. Renvoyer les mêmes fichiers ignore ces cours et importe le reste |
| Un membre qui n'est pas de l'équipe poste des fichiers | Refus, aucun rapport créé, comme aujourd'hui |

## 4. Critères d'acceptation

Chacun devient un test. Les identifiants `IM-NN` sont cités par les tests et par `plan.md`.

```gherkin
# IM-01 — import nominal de plusieurs fichiers
Étant donné un référentiel avec la Tle D, les Mathématiques, la Physique-Chimie et les SVT
Quand l'équipe importe en un envoi les 4 fichiers de docs/contenus/lecons-traitees/tle-d
Alors un seul rapport est créé, « Terminé », avec 4 importés, 0 ignoré, 0 en erreur, 4 au total
Et les détails comptent 12 fiches, 36 exercices, 203 questions et 786 propositions
Et le rapport liste les 4 fichiers dans l'ordre d'envoi, chacun avec « 1 importé »

# IM-02 — un seul fichier : rien ne change
Quand l'équipe importe un seul fichier dont le cours courses[1] a une matière inconnue
Alors l'erreur est notée au chemin « courses[1].material_name », sans nom de fichier
Et le rapport liste ce fichier avec ses compteurs

# IM-03 — un fichier refusé n'empêche pas les autres
Quand l'équipe importe « a.json » (valide), « b.json » (JSON illisible) et « c.json » (format lnclass.essentials)
Alors le rapport est « Terminé » et le cours de « a.json » est importé
Et « b.json » est refusé avec le motif json_invalid, « c.json » avec format_mismatch (reçu lnclass.essentials)
Et le total ne compte que les cours de « a.json »

# IM-04 — tous les fichiers refusés
Quand l'équipe importe deux fichiers illisibles
Alors le rapport est « Rejeté », aucun cours n'est créé, et chaque fichier porte son motif

# IM-05 — doublons entre fichiers
Étant donné le cours « Les alcools » (Tle D, Physique-Chimie) déjà en base
Quand l'équipe importe « x.json » avec « Limites et continuité » et « Les alcools »,
  et « y.json » avec « Limites et continuité » et « Cinématique du point »
Alors « Limites et continuité » est en erreur duplicate_in_files dans les deux fichiers, chaque erreur nomme l'autre fichier
Et « Les alcools » est ignoré, « Cinématique du point » est importé
Et un fichier qui contient deux fois le même cours en importe un et ignore l'autre

# IM-06 — plafond de cours sur l'ensemble des fichiers
Quand l'équipe importe deux fichiers de 250 et 251 cours
Alors le rapport est « Rejeté » avec too_many_roots (max 500, reçu 501), et aucun cours n'est créé

# IM-07 — limites de l'envoi, vérifiées par le serveur
Quand l'équipe poste 51 fichiers, ou 50 Mo et 1 octet au total, ou un fichier de 20 Mo et 1 octet, ou un fichier « notes.txt »
Alors la réponse est 422, l'erreur s'affiche sous le champ, et aucun rapport n'est créé

# IM-08 — les erreurs d'un envoi multiple nomment leur fichier
Quand l'équipe importe « a.json » (valide) et « b.json » dont courses[0].essentials[1] n'a pas de nom
Alors l'erreur du bilan affiche « b.json » et le chemin « courses[0].essentials[1].name »
Et deux fichiers nommés « cours.json » apparaissent comme « cours.json » et « cours.json (2) »

# IM-09 — un seul fichier pour les autres types
Quand l'équipe poste deux fichiers pour l'import des établissements, des DRENA, des fiches ou des exercices
Alors la réponse est 422 et aucun rapport n'est créé
Et la modale de ces types ne permet de choisir qu'un fichier

# IM-10 — autorisation
Étant donné un enseignant, puis un membre de la direction d'un établissement
Quand il poste deux fichiers de cours complets
Alors la requête est refusée et aucun rapport n'est créé

# IM-11 — la modale annonce la sélection
Étant donné l'équipe dans la modale d'import des cours complets
Quand elle choisit 3 fichiers
Alors elle lit « 3 fichiers · <taille totale> » et les 3 noms
Quand elle choisit 51 fichiers
Alors un message annonce la limite de 50 fichiers et le bouton « Importer » est désactivé

# IM-12 — suivi et historique
Quand un import de 3 fichiers est lancé depuis la modale
Alors le suivi affiche le bilan « Terminé » sans rechargement de page, avec une ligne par fichier
Et le suivi de tout import se rafraîchit toutes les secondes tant qu'il tourne
Et l'historique nomme l'import « <premier fichier> et 2 autres fichiers »

# IM-13 — l'écriture accélérée écrit exactement la même chose
Étant donné les 4 fichiers de Tle D importés avant et après l'optimisation, sur deux bases neuves
Alors les cours, fiches, exercices, questions, propositions et contenus riches sont identiques, champ par champ (hors identifiants, public_id et horodatages)
Et un cours qui échoue à l'écriture n'est jamais écrit à moitié

# IM-14 — durée
Quand le banc versionné importe 500 cours complets sur une base de développement
Alors le traitement (du lancement du travail au rapport « Terminé ») dure 20 s au plus
Et le bilan d'un import de 10 cours s'affiche à l'écran moins de 3 s après le clic sur « Importer », Solid Queue démarré
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Le registre des types d'import gagne, par type, un nombre de fichiers et une taille totale maximaux : 50 fichiers et 50 Mo pour les cours complets, 1 fichier et 20 Mo ailleurs. La forme d'un envoi accepte une liste de fichiers. Le port du stockage des fichiers attache et relit une **liste** de fichiers nommés. Le port des rapports enregistre le bilan par fichier. Le moteur d'import traite une liste de documents : refus par fichier, plafond global, doublons entre fichiers, compteurs par fichier. Une erreur d'import peut porter le nom de son fichier. Les adaptateurs des types (cours, écoles, DRENA, fiches, exercices) **ne changent pas** |
| Infrastructure | Une migration ajoute au rapport la liste des fichiers et leur bilan (`jsonb`). Le rapport passe d'une pièce jointe à plusieurs (`has_many_attached :sources`), avec la reprise des pièces jointes existantes. Le stockage des fichiers, les deux queries du suivi et de l'historique suivent. Optimisations de l'écrivain des cours : contenus riches écrits sans conversion Action Text, questions et propositions écrites par copie en masse, et nettoyage du HTML en une seule analyse. Le banc de mesure est versionné sous `script/bench/` |
| Delivery | Le contrôleur des imports lit `import[files][]` au lieu de `import[io]`. Aucune route nouvelle |
| UI | La modale d'import : champ multiple pour les cours complets, résumé de la sélection (nouveau contrôleur Stimulus). Le suivi : une section « Fichiers », et les erreurs qui nomment leur fichier. L'historique et l'en-tête du rapport : le nom « … et N autres fichiers ». Le rafraîchissement du suivi passe de 3 s à 1 s |

## 6. Décisions rattachées

- **ADR-0068** — Un import de cours complets reçoit jusqu'à 50 fichiers, qui forment un seul rapport. L'écriture des arbres de contenu est accélérée sans changer ce qu'elle écrit. Il amende l'ADR-0039 (un fichier par import, rejet en bloc, rafraîchissement toutes les 3 s) et l'ADR-0047 (une pièce jointe par rapport).
- **UDR-0055** — Import de plusieurs fichiers : résumé de la sélection dans la modale, bilan par fichier dans le suivi, nom de l'import dans l'historique, suivi rafraîchi chaque seconde. Elle complète l'UDR-0038 (import de cours) et l'UDR-0006 §7.
- Vérification préalable à l'implémentation : Thruster n'impose aucune taille de requête par défaut (`MAX_REQUEST_BODY` vaut 0). La limite du proxy d'entrée de l'hébergeur n'est pas documentée : le challenger de la phase 5 envoie 50 Mo sur l'environnement de recette. Si l'envoi échoue, la limite totale est abaissée ici, par modification explicite de ce PRD.

## 7. Mesures

Banc : `script/bench/import_course_tree.rb`, sur la base de développement, avec des fichiers générés à partir des 4 leçons de Tle D (noms suffixés). Chaque mesure est la médiane de 3 passages.

| Métrique | Avant (2026-09-29) | Cible | Après |
|---|---|---|---|
| Traitement de 200 cours | 16,5 s | — | |
| Traitement de 500 cours | ≈ 40 s (extrapolé à 80 ms par cours) | ≤ 20 s | |
| Écriture de 200 cours | 12,8 s | ≤ 5 s | |
| Délai entre l'envoi et le bilan affiché, 10 cours | jusqu'à 4,5 s (1 s de prise en charge + 3 s de rafraîchissement + traitement) | < 3 s | |
| Allers-retours dans la modale pour 10 fichiers | 10 | 1 | |
