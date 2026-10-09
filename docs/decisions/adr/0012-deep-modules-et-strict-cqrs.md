# ADR-0012 : Approfondissement des Modules (Deep Modules) et CQRS Strict
<!-- index
titre: Approfondissement des modules (Deep Modules) et CQRS strict
statut: ⚠️ **Remplacé** par [0026](./0026-contrat-result-entites-et-dto.md) *(§3.1)* et [0039](./0039-format-d-import-du-contenu.md) *(§3.3)*
problematique: Supprimer les modules superficiels (passe-plats) et la duplication d'imports en utilisant des Query Objects et des ViewObjects pour la lecture.
-->

| | |
|---|---|
| **Statut** | Remplacé — *voir l'avertissement ci-dessous* |
| **Date** | 2026-07 *(jour non documenté)* |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | [ADR-0026](./0026-contrat-result-entites-et-dto.md) *(§3.1)*, [ADR-0039](./0039-format-d-import-du-contenu.md) *(§3.3)* |

---

> ⚠️ **Décision remplacée — les lectures et les imports suivent d'autres ADR.**
> Le §3.1 (`ViewObjects`) est remplacé par l'[ADR-0026](./0026-contrat-result-entites-et-dto.md) : une query renvoie un `Data`. Le §3.3 (import polymorphe) est remplacé par l'[ADR-0039](./0039-format-d-import-du-contenu.md) : imports JSON versionnés, import partiel atomique par élément racine. Le use case CRUD générique du §3.2 est abandonné. Aucune partie de cet ADR ne reste en vigueur depuis le 2026-09-25.

## 1. Contexte et problématique
Suite à une seconde revue d'architecture (Refactoring V2), nous avons identifié plusieurs "modules superficiels" (shallow modules) et des violations d'isolation dans le monolithe hexagonal :
* **Violation CQRS des Feeds** : Des Use Cases (`GetStudentFeed`, etc.) agissaient comme de simples "passe-plats" vers l'infrastructure pour récupérer et assembler des données de lecture. Le contrat d'interface était aussi complexe que l'implémentation.
* **Boilerplate CRUD** : De nombreux Use Cases (`ManageMaterial`, `ManageLevel`) étaient anémiques et ne faisaient qu'appeler le Repository, n'ajoutant aucune valeur métier tout en gonflant le dossier `domain/use_cases`.
* **Duplication d'Imports JSON** : Quatre Use Cases d'import distincts répétaient la même logique (itération, parsing de base, gestion d'erreurs et idempotence), rendant fastidieuse l'ajout de nouveaux types d'imports et limitant les fonctionnalités de l'interface utilisateur.

---

## 2. Moteurs de décision
* **Localité (Locality)** : Garder le code qui change ensemble à proximité (la logique de requêtage d'affichage appartient à l'infrastructure et la présentation, pas au domaine).
* **Levier (Leverage)** : Mutualiser l'effort (une boucle d'import, de multiples stratégies) pour ne pas dupliquer le travail de gestion de masse (fichiers multiples `multiple: true`).
* **Testabilité et Frontières (Seams)** : Renforcer les limites entre la lecture (Queries + ViewObjects) et l'écriture (Use Cases + Repositories).

---

## 3. Décision
Trois axes de restructuration ont été adoptés de concert :

### 3.1. Strict CQRS via ViewObjects
Les requêtes de type tableau de bord ou feed sont désormais totalement externalisées du Domaine.
* Les `Queries` (ex: `StudentFeedQuery`) construisent les données et retournent un objet de transfert fortement typé, les `ViewObjects` (ex: `ViewObjects::StudentFeed`).
* Les contrôleurs appellent directement les Queries.
* *Conséquence* : Suppression des Use Cases "pass-through".

### 3.2. Use Case CRUD Générique
Pour toutes les ressources nécessitant une persistance basique sans logique métier croisée, un orchestrateur unique `UseCases::ManageCatalogResource` a été créé.
* Il centralise les méthodes d'écriture standards (`execute_create`, `execute_update`, `execute_delete`).
* Les contrôleurs d'administration se branchent dessus en injectant l'entité appropriée.
* *Conséquence* : Suppression d'une dizaine de fichiers Use Cases anémiques.

### 3.3. Importation Polymorphe (Pattern Strategy)
Pour gérer l'import massif de données pédagogiques JSON :
* Création de `UseCases::ImportCatalogData`, qui prend en charge l'idempotence, la boucle et le logging.
* Création de classes `Strategies::[Resource]ImportStrategy` implémentant une interface commune (ex: `#import(data)`).
* *Bonus* : Cela a permis de mettre à jour le formulaire Web d'import de cours pour qu'il prenne en charge nativement les sélections multiples (`<input type="file" multiple>`), itérant sur les fichiers avant de passer le JSON au Use Case.

---

## 4. Conséquences

### 🟢 Positives
* **Réduction drastique du Boilerplate** : Moins de fichiers, moins de duplication, plus facile à maintenir.
* **Fonctionnalité Décuplée pour les Administrateurs** : L'import multi-fichiers Web (ex: envoyer 6 fichiers de cours contenant chacun +3 cours en un clic) est rendu trivial et robuste.
* **Typage et Contrats Forts** : L'utilisation de `ViewObjects` prévient les crashs dans les vues dus à des retours de Queries incohérents.

### 🔴 Coûts consentis
* **Paradigme supplémentaire** : L'introduction des `ViewObjects` et des `Strategies` rajoute de nouveaux dossiers dans l'architecture que les futurs développeurs devront appréhender via cette documentation.
