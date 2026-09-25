# ADR-0011 : Architecture et Modélisation de la Validation Collaborative (Crowdsourcing)

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-07-29 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique
Lnclass a besoin d'assurer l'excellence de ses fiches (Essentials) et de ses exercices, en permettant aux enseignants (Teachers) de signaler les erreurs et les non-conformités au programme officiel.
Il a été décidé d'utiliser une approche de crowdsourcing afin que les enseignants certifiés puissent valider la qualité du contenu, avec une double évaluation : "Exactitude" (Accuracy) et "Conformité" (Compliance).

## 2. Décision
1. **Séparation Stricte (Architecture Hexagonale)** :
   La soumission d'une validation est une action critique, c'est pourquoi nous avons isolé cette logique dans le Domaine :
   * **Entité Pure (`Entities::CommunityValidation`)** : Gère la logique des champs conditionnels (ex: si `is_correct == false`, alors `error_description` devient obligatoire). Cela évite de polluer les validations de base de données.
   * **Use Case (`SubmitCommunityValidation`)** : Empêche un enseignant de voter deux fois en interceptant les nouvelles soumissions pour écraser (mettre à jour) le vote existant via le port d'infrastructure.

2. **Relations Polymorphiques (Infrastructure)** :
   * Nous avons utilisé une relation `validatable_type` et `validatable_id` au niveau de la table `community_validations`.
   * Cela permet de rendre le module extensible à l'avenir (ex: si on veut permettre de valider des Questions d'examen ou des Cours entiers) sans avoir à créer de nouvelles tables.

3. **UX & Présentation** :
   * Afin de ne pas casser le flow des utilisateurs, l'interface utilise **Hotwire (Turbo Streams)**. Une fois que le prof soumet sa validation, un message "Merci pour votre contribution" remplace la carte via un `create.turbo_stream.erb`, sans recharger la page.

## 3. Conséquences
- **Positives** : Grande maintenabilité, code découplé. Le module est facilement testable (le domaine peut être testé avec des Mocks sans base de données). Le système s'intègre parfaitement aux `Orm::Essential` et `Orm::Exercise` actuels.
- **Négatives** : Cela rajoute de la complexité (plus de fichiers que dans un simple CRUD "fat model"). Mais c'est le prix assumé pour garantir une architecture propre et éviter les modèles ORM surchargés.
