# Processus de Développement des Features Lnclass (Workflow)

Ce document définit le processus standard de bout en bout pour le développement de toute nouvelle fonctionnalité sur Lnclass. Il garantit que chaque fonctionnalité est bien pensée, spécifiée, planifiée, exécutée selon les standards architecturaux, et documentée de manière pérenne.

## Étape 1 : Le MEMO et la clarification (Grill)
**Objectif** : Partir d'une idée brute et l'affiner pour éliminer les zones d'ombre.
1. **Créer le MEMO** : Rédiger un fichier `docs/memo/[nom_de_la_feature]_memo.md` contenant l'idée de base, les objectifs visés et les premières contraintes.
2. **Stress-Test (Grill)** : Déclencher le skill IA `/grill-me` pour une session interactive de questions-réponses. L'IA interrogera le Product Owner sur les spécifications, les *edge-cases*, les règles métiers et les considérations techniques.
3. **Mettre à jour** : Les réponses obtenues lors du "grill" viennent enrichir et valider la compréhension de la fonctionnalité.

## Étape 2 : Le PRD (Product Requirements Document)
**Objectif** : Figer les spécifications fonctionnelles et techniques dans un document formel.
1. À partir du MEMO affiné, rédiger le **PRD complet** dans `docs/prd/[nom_de_la_feature]_prd.md`.
2. Le PRD doit systématiquement inclure :
   - Le contexte et la problématique.
   - Les acteurs et leurs permissions.
   - Le parcours utilisateur / UX.
   - La modélisation technique préliminaire (Domain, Infrastructure, vues).

## Étape 3 : Le Plan d'Implémentation
**Objectif** : Découper le travail en tâches actionnables pour les développeurs humains et les agents IA.
1. Créer le fichier d'orchestration dans `docs/prompts/[nom_de_la_feature]_plan.md`.
2. **Loter les tâches** : Découper le développement en étapes logiques, par exemple :
   - Lot 1 : Migrations et Modèles BDD.
   - Lot 2 : Couche Domaine (Entités, Ports, Use Cases).
   - Lot 3 : Couche Infrastructure (ORM, Repositories).
   - Lot 4 : Interface Utilisateur (Controllers, Views, Hotwire).
3. **Assigner les agents** : Assigner clairement chaque lot à un agent IA ou un sous-agent spécifique (ex: `@backend_agent` pour le Domaine, `@frontend_agent` pour Hotwire).

## Étape 4 : Le Développement (Standards Lnclass)
**Objectif** : Produire le code selon les standards stricts et l'architecture hexagonale de Lnclass.
1. **Domaine** (`app/domain/`) : Entities agnostiques, DTOs (pour sécuriser les entrées), Ports (interfaces), Use Cases isolés.
2. **Infrastructure** (`app/infrastructure/`) : ORM (ActiveRecord explicitement nommé), Repositories implémentant les Ports.
3. **Présentation** (`app/controllers/`, `app/views/`, `app/javascript/`) : Logique d'affichage, Turbo Streams, Contrôleurs Stimulus (plus de Redux).
4. **Validation HITL Obligatoire** : 
   - Toujours inclure l'**en-tête HITL (Human-In-The-Loop)** officiel au début de chaque fichier modifié ou créé, listant la couche architecturale et le rôle (cf. `docs/STANDARD/hitl_docstrings.md`).
5. **Vérification de compilation** : Toujours exécuter `bin/rails runner "puts MonEspace::MaClasse.name"` pour s'assurer du chargement Zeitwerk.

## Étape 5 : L'ADR (Architecture Decision Record)
**Objectif** : Documenter la pérennité des choix techniques et des compromis réalisés.
1. Une fois le développement terminé, créer ou mettre à jour un **ADR** dans le dossier `docs/adr/` (ex: `ADR-0010_ma_decision.md`).
2. Y documenter : le contexte, la décision technique adoptée lors du développement de la feature, et les conséquences/impacts sur le projet.

---
> **Astuce d'orchestration avec l'IA** :
> Avant de coder, demandez toujours à l'IA : *"Voici le PRD. Génère le plan d'action dans `docs/prompts/` et structure les lots pour qu'on puisse les distribuer aux sous-agents."*
