# Guide d'Utilisation des Skills Lnclass

Ce guide récapitule l'ensemble des **skills d'ingénierie logicielle** configurés pour votre environnement de développement. Il vous aide à collaborer avec votre assistant IA (comme Antigravity) en utilisant des workflows structurés, rigoureux et adaptés à l'architecture hexagonale du projet Lnclass.

---

## 🗺️ 1. Planification & Architecture

Utilisez ces skills lors de la phase de conception d'une fonctionnalité ou de définition de l'architecture.

| Nom du Skill | Rôle principal | Quand l'utiliser |
| :--- | :--- | :--- |
| **`to-prd`** | Générer un document d'exigences produit (PRD). | Avant de coder, pour formaliser le besoin et le comportement attendu. |
| **`to-issues`** | Découper une fonctionnalité en tickets implémentables. | Après avoir validé le PRD, pour créer les tickets dans le backlog local. |
| **`grill-me`** / **`grilling`** | Stress-tester vos plans et choix techniques par le questionnement Socratique. | Pour identifier les failles de sécurité, de performance ou de couplage dans un design avant de l'implémenter. |
| **`domain-modeling`** | Structurer le modèle du domaine métier (Entities, Use Cases, Ports). | Pour maintenir à jour le langage omniprésent (`CONTEXT.md`) et rédiger des fiches de décision d'architecture (ADR). |
| **`improve-codebase-architecture`** | Identifier les défauts de structure (smells) et proposer des refactoring. | Lors de la restructuration d'un module complexe ou de la transition vers de nouveaux patterns. |

> [!TIP]
> **Exemple de prompt pour concevoir une fonctionnalité :**
> *« Utilise `/to-prd` pour rédiger le PRD de la fonctionnalité de notation automatique des exercices, puis passe au skill `/grill-me` pour stress-tester la gestion des cas aux limites. »*

---

## 💻 2. Développement & Conception de Code

Ces skills vous accompagnent pour écrire du code propre, robuste et découplé des frameworks.

| Nom du Skill | Rôle principal | Quand l'utiliser |
| :--- | :--- | :--- |
| **`tdd`** | Exécuter des cycles stricts de Test-Driven Development (Red-Green-Refactor). | Pour implémenter une logique métier complexe avec une couverture de tests maximale. |
| **`implement`** | Écrire du code propre et bien architecturé. | Pour l'implémentation standard respectant les règles hexagonales définies dans `CLAUDE.md`. |
| **`codebase-design`** | Concevoir des modules profonds (deep modules) avec des interfaces simples. | Pour minimiser la complexité cognitive d'une interface ou d'une classe. |
| **`design-an-interface`** | Explorer plusieurs variantes d'APIs pour un même module. | Pour comparer différentes approches de conception d'API ou de signature de méthode (Domain Ports). |
| **`prototype`** | Écrire un prototype jetable pour valider une hypothèse technique. | Pour tester une idée d'implémentation sans polluer la base de code principale. |

> [!IMPORTANT]
> Lors de l'écriture d'un modèle d'infrastructure ou d'une entité de domaine, l'assistant se réfère aux instructions d'architecture hexagonale listées dans [.agents/AGENTS.md](file:///home/kamkara/LnclassHQ/Develop/App.Lnclassapp/.agents/AGENTS.md).

---

## 🔍 3. Revue de Code & Résolution de Bugs

Utilisez ces skills pour garantir la qualité et la stabilité de votre application.

| Nom du Skill | Rôle principal | Quand l'utiliser |
| :--- | :--- | :--- |
| **`code-review`** | Analyser les changements par rapport à une branche/un commit de référence. | Avant de fusionner une branche de fonctionnalité dans `main` ou `Develop`. |
| **`diagnosing-bugs`** | Diagnostiquer méthodiquement des anomalies complexes ou régressions. | Face à un bug récalcitrant, un comportement inattendu ou des ralentissements. |
| **`resolving-merge-conflicts`** | Résoudre proprement les conflits de fusion ou de rebase Git. | En cas de conflit complexe impliquant de multiples modifications concurrentes. |
| **`qa`** | Session interactive de tests d'assurance qualité. | Pour valider une livraison ou recréer interactivement un scénario d'erreur. |

> [!NOTE]
> Le skill `/code-review` utilise deux agents en parallèle pour évaluer les modifications : l'un valide le respect des standards (ex. Architecture Hexagonale Rails 8), l'autre vérifie la conformité avec le cahier des charges (le PRD original).

---

## ⚡ 4. Gestion de Tâches Complexes (Wayfinder & Triage)

Pour mener à bien des chantiers longs ou organiser un backlog de tickets en local.

| Nom du Skill | Rôle principal | Quand l'utiliser |
| :--- | :--- | :--- |
| **`wayfinder`** | Coordonner des chantiers massifs en les découpant en étapes (tickets). | Pour un grand refactoring ou une migration qui nécessite plusieurs sessions de travail. |
| **`triage`** | Trier les tickets locaux dans `.scratch/` et leur attribuer des labels de statut. | Pour organiser votre backlog local de manière automatisée. |
| **`loop-me`** | Exécuter une tâche de manière itérative jusqu'à réussite. | Pour stabiliser un test intermittent (flaky test) ou automatiser des tâches répétitives. |

---

## 📚 5. Documentation & Connaissances

| Nom du Skill | Rôle principal | Quand l'utiliser |
| :--- | :--- | :--- |
| **`grill-with-docs`** | Poser des questions complexes en s'appuyant sur toute la doc interne. | Pour comprendre l'historique d'une décision architecturale ou un concept métier pointu. |
| **`obsidian-vault`** | Gérer et interconnecter vos notes via des wiki-links. | Si vous maintenez un second cerveau de type Obsidian pour le projet. |
| **`teach`** | Enseigner un nouveau concept ou une règle à l'assistant. | Quand vous souhaitez ancrer une nouvelle convention d'équipe de manière durable. |

---

## 🚀 Comment démarrer ?

Pour utiliser l'un de ces skills, il vous suffit de le mentionner directement dans votre conversation avec l'assistant.

**Exemple typique de cycle de travail :**
1. **Conception** : *« Utilise `/to-prd` pour planifier la refonte des profils étudiants. »*
2. **Affinement** : *« Lance `/grill-me` sur ce PRD pour repérer les points faibles. »*
3. **Découpage** : *« Utilise `/to-issues` pour générer les tickets locaux correspondants. »*
4. **Implémentation** : *« Choisis le ticket 01 et applique `/tdd` pour coder la logique métier de l'Entity correspondante. »*
5. **Revue** : *« Lance `/code-review` par rapport à origin/Develop sur mes modifications actuelles. »*
