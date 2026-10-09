# ADR-0015 : Stratégie de tests métier et isolation des Policies
<!-- index
titre: Stratégie de tests métier et isolation des Policies
statut: Accepté — *complété par [0028](./0028-policies-de-domaine-par-use-case.md)*
problematique: Tester les règles d'autorisation unitairement sur les objets Policy avec des Fakes en mémoire, au lieu de surcharger les tests de Use Cases.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-08 *(jour non documenté)* |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |
| **Complété par** | [ADR-0028](./0028-policies-de-domaine-par-use-case.md) : test de refus obligatoire pour chaque policy |

---

> ⚠️ **Décision complétée — test de refus obligatoire.**
> L'[ADR-0028](./0028-policies-de-domaine-par-use-case.md) complète cet ADR le 2026-09-25 : chaque policy a un test de refus, et un test par use case vérifie qu'un refus n'écrit rien. Le reste de l'ADR demeure en vigueur.

## 1. Contexte et problématique
Dans le cadre de l'architecture hexagonale adoptée, les `Use Cases` orchestrent le flux métier principal, mais délèguent fréquemment des décisions d'autorisation très spécifiques et complexes à des objets de domaine dédiés (ex: `Policies::ClassroomAccessPolicy`). 
Lors de la migration de l'ancienne suite de tests, un débat architectural a eu lieu (séance de "grilling") pour déterminer la meilleure "surface de test" (Test Surface) pour ces règles complexes.

## 2. Décision
* **Tester les Policies de manière isolée** : Les règles d'autorisation et de sécurité complexes doivent être testées de manière strictement unitaire sur les classes de Policy (ou Entités pures) elles-mêmes, et non pas indirectement via les Use Cases.
* **Ne pas surcharger les tests de Use Cases** : Les Use Cases doivent être testés uniquement pour valider l'orchestration du flux (succès vs échec, respect du contrat DTO, appels aux repositories). Ils ne doivent pas devenir le goulot d'étranglement testant les 50 permutations d'une règle d'accès métier.
* **Utilisation systématique de "Fakes" en mémoire** : Pour tester ces objets de Domaine pur, les tests doivent injecter des Fakes ultra-légers (ex: `FakeClassroomRepository`) pour simuler l'infrastructure. Les tests ne doivent pas charger l'ORM ou toucher à la base de données de test.

## 3. Conséquences
* **Positives** : 
  * "Locality" des tests : Le comportement de la Policy est documenté par un test qui ne lit que le code de la Policy.
  * Les tests s'exécutent en quelques millisecondes, favorisant une boucle de feedback immédiate.
* **Négatives** : 
  * Les développeurs doivent écrire et maintenir des petites classes "Fakes" à l'intérieur de leurs fichiers de tests pour simuler les Ports de sortie.
