# ADR-0021 : Migration de la Gestion de l'Identité vers le Domaine Pur
<!-- index
titre: Migration de la gestion de l'identité vers le domaine pur
statut: ⚠️ **Remplacé** par [0026](./0026-contrat-result-entites-et-dto.md)
problematique: Extraire la logique métier des modèles `Orm::User`, `Orm::Student`, `Orm::Teacher` vers `Entities::Identity::*`, via une délégation au vol qui ne casse pas les vues.
-->

| | |
|---|---|
| **Statut** | Remplacé — *voir l'avertissement ci-dessous* |
| **Date** | — |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | [ADR-0026](./0026-contrat-result-entites-et-dto.md) |

---

> ⚠️ **Décision remplacée — la délégation ORM → entités n'est pas reprise.**
> L'[ADR-0026](./0026-contrat-result-entites-et-dto.md) remplace cet ADR en entier le 2026-09-25 : les entités et les DTO n'importent jamais ActiveRecord, et les repositories convertissent les modèles en entités. La délégation « au vol » ne fut jamais fusionnée.

## 1. Contexte et problématique
Dans la version précédente du système, la logique métier concernant l'identité des utilisateurs (génération de l'ID public, vérification du statut de paiement, détermination de la classe principale) était intimement couplée au framework via les modèles ActiveRecord (`Orm::User`, `Orm::Student`, `Orm::Teacher`, etc.). Cette approche brisait l'architecture hexagonale visée, causant des tests lents et un couplage fort.

## 2. Décision
Nous avons décidé d'extraire toute la logique métier des modèles `Orm::*` pour la placer dans des entités pures de la couche domaine :
- `Entities::Identity::User`
- `Entities::Identity::Student`
- `Entities::Identity::Teacher`
- `Entities::Identity::Team`
- `Entities::Identity::SchoolStaff`

Pour assurer la transition sans casser les vues existantes qui dépendent de méthodes comme `current_user.student.primary_classroom`, nous avons mis en place une stratégie de **délégation au vol** : les modèles ORM instancient leur équivalent du Domaine via le Repository et délèguent les appels métier.

## 3. Conséquences
- **Avantages** : L'ORM est redevenu purement anémique (il ne fait que de la persistance). Le domaine Identity est 100% couvert par des tests rapides, n'ayant plus besoin de base de données pour tester la logique. La transition pour l'interface est invisible et ne génère pas de régressions en cascade.
- **Inconvénients** : Maintenir temporairement la délégation dans les ORMs (`delegate :school, to: :domain_entity`) ajoute un léger coût de mapping (conversion record -> entité). À terme, les contrôleurs devront exposer directement l'entité du domaine à la vue.
