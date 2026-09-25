# Workflow de Développement Assisté par IA (Agentic Workflow)

Ce document définit le processus strict en 4 phases à suivre lors du développement de nouvelles fonctionnalités sur le projet Lnclassapp avec un agent IA. Ce processus garantit le respect de l'Architecture Hexagonale, l'intégrité de l'UI/UX, et empêche les régressions (casse de fonctionnalités existantes).

---

## 📋 Phase 1 : Conception & Décisions (Ne jamais coder immédiatement)

Avant d'écrire la moindre ligne de code, l'agent et le développeur doivent aligner l'architecture et le design.
* **Brainstorming :** Utiliser la commande `/grill-me` pour que l'IA challenge l'idée et identifie les failles.
* **ADR (Architecture Decision Record) :** Documenter les choix techniques (`docs/ADR/`).
  * *Quels Use Cases ? Quels Ports ? Quelle stratégie de base de données ?*
* **UDR (UI/UX Decision Record) :** Documenter l'expérience utilisateur (`docs/UDR/`).
  * *Comment l'interface réagit-elle ? Utilise-t-on un Turbo Stream pour éviter le rechargement ?*
  * **Utilisation de la skill `interface-design`** : Invoquer systématiquement cette skill pour définir ou réutiliser les jetons de design (couleurs, espacements, profondeurs, typographie) dans le fichier système `.agents/skills/interface-design/system.md`.

## 🧪 Phase 2 : TDD (Test-Driven Development) & Garde-fous

Pour sécuriser l'existant, les tests pilotent le code.
* **Écriture des Tests :** L'agent rédige les tests (RSpec/Minitest) pour la couche Domaine (Use Cases) et Infrastructure (Repositories) **avant** l'implémentation.
* **Validation (Rouge) :** L'exécution des tests doit échouer, prouvant qu'ils couvrent la fonctionnalité manquante.

## 🏗️ Phase 3 : Implémentation Hexagonale (Couche par Couche)

L'implémentation se fait obligatoirement de l'intérieur (métier) vers l'extérieur (web).

### A. Couche Domaine (`app/domain/`)
* Création des *Entities*, des *Ports* (contrats) et des *Use Cases*.
* **Contrainte :** Code Ruby pur. Aucun lien avec Rails ou ActiveRecord.
* *Validation : Les tests du Domaine doivent passer.*

### B. Couche Infrastructure (`app/infrastructure/`)
* Création des Migrations SQL (en respectant l'ordre de priorité et les clés étrangères `nullify`).
* Création des modèles ORM et implémentation des *Repositories*.
* *Validation : Les tests d'intégration doivent passer.*

### C. Couche Présentation (`app/controllers/`, `app/views/`)
* **Contrôleurs :** Rôle limité de *Delivery Mechanism*. Ils transforment les `params` HTTP, appellent le *Use Case*, et décident de la redirection ou du rendu. Zéro logique métier. (Régis par l'ADR).
* **Vues & Hotwire (`.html.erb`, `.turbo_stream.erb`) :** Implémentation de l'interface et du dynamisme. 
  * *Régies par l'UDR pour le design et l'ADR pour l'asynchronisme.*
  * **Contrainte UI :** Utiliser la skill `interface-design` pour s'assurer de l'application rigoureuse du `system.md` (garantie "anti-slop" et cohérence absolue d'une session à l'autre).

## 📑 Phase 4 : Documentation (HITL) et Validation Finale

L'agent ne livre pas de code sans avoir audité son propre travail.
1. **En-têtes HITL :** L'agent insère obligatoirement le commentaire d'en-tête (HITL Docstring) en haut de chaque fichier créé ou modifié (référençant l'ADR et l'UDR appropriés).
2. **Scripts de contrôle :** L'agent ou le développeur doit s'assurer que le code compile :
   * `ruby -c` (Vérification syntaxique).
   * `bin/rails runner "puts Module::Class.name"` (Vérification Zeitwerk).
   * `bin/validate_hitl` (Vérification de la conformité de la documentation).
3. **Commit :** Si tout est au vert, la feature est prête.
