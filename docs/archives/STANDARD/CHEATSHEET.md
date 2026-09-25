# ⚡️ Guide de Développement (Cheat Sheet) - Lnclass

Ce guide résume la nouvelle organisation pour coder des features rapidement et proprement.

## 🚀 1. Le Workflow "Hexagonal-Commando"
Suivre systématiquement ces 3 phases ([Détails ici](docs/STANDARD/workflow.md)) :

| Phase | Focus | Fichiers |
| :--- | :--- | :--- |
| **1. Conception** | Métier | Schéma mental / Liste des actions |
| **2. Réalisation** | Code | Entity → DTO → Use Case → Repository → Controller → View |
| **3. Polissage** | UX | Turbo Streams, Toasts, I18n, Rubocop |

## 📐 2. Blueprints (Modèles)
Utiliser les modèles pour ne pas repartir de zéro :
- [DTO](docs/STANDARD/blueprints/dto.md) : Transport sécurisé des paramètres (Anti-corruption).
- [Use Case](docs/STANDARD/blueprints/use_case.md) : Logique métier pure.
- [Repository](docs/STANDARD/blueprints/repository.md) : Persistence & ORM.
- [Presenter](docs/STANDARD/blueprints/presenter.md) : Logique de vue.
- [Query](docs/STANDARD/blueprints/query.md) : Lecture de données complexe.

## 🤖 3. Maximiser Gemini (Mode Commando)
Pour aller 10x plus vite, délègue le boilerplate à Gemini CLI.

### Commande Type pour une nouvelle feature :
> "Je veux créer la feature **[NOM]**.
> Les champs nécessaires sont : **[CHAMPS]**.
> Génère-moi :
> 1. Le plan d'action hexagonal.
> 2. Le boilerplate (Entity, DTO, Use Case, Port, Repository).
> 3. La migration et le modèle ORM."

### Commande pour la vue :
> "Génère le contrôleur et les vues pour cette feature en utilisant **Hotwire (Turbo Streams)** et le système de **Toasts** du projet."

---

## ⚠️ Règles d'Or
1. **Zéro ActiveRecord dans le Domaine** (Pas de `.save`, `.find`, `.where`).
2. **Injection de dépendances** : Les repositories sont passés au constructeur du Use Case.
3. **DTOs Obligatoires** : Aucun ActionController::Parameters brut ne doit traverser vers un Use Case.
4. **Idempotence** : Un script d'import doit pouvoir être relancé 10 fois sans créer de doublons.
