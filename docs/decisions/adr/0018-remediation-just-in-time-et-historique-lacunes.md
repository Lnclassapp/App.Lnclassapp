# ADR-0018 : Feature Remédiation, Génération Just-In-Time et Historique des Lacunes
<!-- index
titre: Remédiation, génération just-in-time et historique des lacunes
statut: ⚠️ **Remplacé partiellement** par [0043](./0043-remediation-declenchee-par-la-cloture.md) *(§3)*, [0027](./0027-contextes-bornes-et-arborescence.md) *(noms)*, [0029](./0029-identifiants-exposes-public-id-et-slugs.md) *(clé)*
problematique: Tracer les lacunes (`KnowledgeGap`) d'un élève et générer la session de rattrapage au moment exact du clic, sans polluer la base de sessions orphelines.
-->

| | |
|---|---|
| **Statut** | Remplacé partiellement — *voir l'avertissement ci-dessous* |
| **Date** | 2026-08-27 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | [ADR-0043](./0043-remediation-declenchee-par-la-cloture.md) *(§3)*, [ADR-0027](./0027-contextes-bornes-et-arborescence.md) *(noms du §3.2)*, [ADR-0029](./0029-identifiants-exposes-public-id-et-slugs.md) *(clé nanoid)* |

---

> ⚠️ **Décision partiellement remplacée — la remédiation est déclenchée par la clôture.**
> Le §3 est remplacé par l'[ADR-0043](./0043-remediation-declenchee-par-la-cloture.md) le 2026-09-25 : lacunes ouvertes et résolues par le seul use case de clôture. Les noms du §3.2 suivent l'[ADR-0027](./0027-contextes-bornes-et-arborescence.md), la clé des lacunes passe en `bigint` (l'[ADR-0029](./0029-identifiants-exposes-public-id-et-slugs.md)). Le principe *just-in-time* et l'historique des lacunes restent en vigueur.

## 1. Contexte et problématique
L'application nécessite un système de "Remédiation" pour accompagner les élèves lorsqu'ils échouent à un exercice ou une évaluation. L'objectif est double : fournir un exercice de rattrapage ciblé à l'élève, et permettre au professeur de suivre un tableau de bord précis des difficultés de sa classe. 
Une session de co-conception (Grill) a été menée pour définir la structure exacte de cette fonctionnalité tout en respectant les standards de l'architecture Hexagonale (ADR-0001) et de la simplification (ADR-0017).

## 2. Moteurs de décision
1. **Traçabilité des lacunes (Knowledge Graph)** : Conserver un historique de ce que l'élève n'a pas compris pour alimenter de futurs produits.
2. **Performance (Éviter le gaspillage DB)** : Ne pas générer des milliers de sessions de rattrapage (records) si l'élève décide simplement de relancer l'exercice normal de lui-même ou s'il ignore la remédiation.
3. **UX Intégrée et Contextuelle** : Ne pas créer de dashboards élèves isolés, mais intégrer les alertes et les actions directement sur la carte de l'exercice (`card`).
4. **Pureté du Domaine** : Garder la logique métier agnostique de la base de données.

## 3. Décision

### 3.1. Modélisation du Domaine (Domain Layer)
- Création de l'entité `Entities::KnowledgeGap` pour représenter l'échec sur une notion (`essential_id`).
- Réutilisation de l'entité existante `Entities::ExerciseSession` pour faire passer la remédiation. La session de remédiation ciblera les `KnowledgeGaps` non résolus.
- Le cycle de vie est défini par 3 Use Cases :
  - `UseCases::DetectKnowledgeGaps` : Exécuté lors de l'échec d'une session, génère un ou plusieurs `KnowledgeGaps` (status: `pending`).
  - `UseCases::GenerateRemediationSession` : Génère dynamiquement la session de remédiation au moment exact où l'élève clique sur le bouton.
  - `UseCases::ResolveKnowledgeGaps` : Marque les lacunes comme `self_corrected` (si réussite via l'exercice classique) ou `remediated` (si réussite via la session de remédiation).

### 3.2. Interface de Persistance (Ports & Infrastructure)
- **Port** : `Ports::KnowledgeGapRepository` pour la manipulation des données.
- **ORM** : Création d'une table `knowledge_gaps` et du modèle `Orm::KnowledgeGap`.
- La clé primaire de `Orm::KnowledgeGap` utilisera la méthode native `has_nanoid(:id)` définie dans `ApplicationRecord` (SecureRandom.base58), conformément à l'ADR-0017.

### 3.3. Architecture UX/UI (Presentation Layer)
- **Côté Élève** : L'icône de remédiation (🎯) apparaît directement sur la carte de l'exercice s'il y a un gap `pending`. Au clic, appel de `GenerateRemediationSession` (Génération Just-In-Time).
- **Côté Professeur** : L'icône de remédiation sur la carte affiche des compteurs globaux (ex: 🔴 5 en difficulté, 🟢 2 résolus). Au clic, ouverture d'un panel détaillant 3 états :
  - **En difficulté** : Élèves avec gaps `pending`.
  - **Auto-améliorés** : Élèves ayant un gap `self_corrected`.
  - **Remédiation réussie** : Élèves ayant un gap `remediated`.

## 4. Plan d'exécution pour les agents
Les agents chargés de l'implémentation de cette feature doivent exécuter ce plan par phases strictes :
1. **Worker Database** : Générer et appliquer la migration `knowledge_gaps`, créer `Orm::KnowledgeGap`.
2. **Worker Domain** : Implémenter l'entité `Entities::KnowledgeGap`, le port `KnowledgeGapRepository` et son implémentation `Infrastructure::Repositories::KnowledgeGapRepository`.
3. **Worker Use Cases** : Coder les 3 Use Cases décrits ci-dessus, sans aucune dépendance à ActiveRecord.
4. **Worker Frontend** : Intégrer les UI (Student & Teacher) sur le partial de la `card` d'exercice (Stimulus/Hotwire).

## 5. Conséquences
- **Positives** : La base de données reste propre (pas de sessions orphelines), l'UX est fluide car contextuelle, et le domaine est prêt pour de la recommandation avancée.
- **Négatives** : L'interface professeur (modal/drawer) demandera un composant UI un peu plus riche (via Hotwire/Turbo Frames) pour charger le reporting au clic sans alourdir la page initiale.
