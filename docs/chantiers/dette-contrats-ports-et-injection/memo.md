# Memo — Contrats de ports et injection de dépendances non respectés

| | |
|---|---|
| **Type de cycle** | refactoring |
| **Statut** | cadrage |
| **Ouvert le** | 2026-09-18 |
| **Branche** | `refactor/dette-contrats-ports-et-injection` |
| **Gravité** | 🟡 **Moyenne — dette structurelle, pas de casse visible** |

---

## Le problème

Quatre défauts distincts, une même racine : **le contrat déclaré n'est pas le contrat consommé**. Dans une architecture hexagonale, le port *est* la frontière — quand il ment, l'isolation du domaine devient décorative.

### 1. Port incomplet — `Ports::Catalog::DrenaRepositoryPort`

Le port ne déclare que `save_drena` et `delete_drena`. Or `UseCases::Catalog::ManageResource` a besoin de `find_drena_by_slug` et `find_drena_by_id` pour `execute_update` et `execute_delete`. Le contrat réellement consommé n'est pas celui que le port décrit — un adaptateur conforme au port échouerait en production.

### 2. Dépendance non injectable — `use_cases/classroom/purge_demo_students.rb:28`

`execute` instancie `Repositories::Identity::StudentRepository.new` **en dur**. Le use case ne peut pas être testé sans base de données, ce qui viole le principe d'injection par constructeur appliqué partout ailleurs. Aucun test de domaine n'a pu être écrit pour ce use case.

### 3. Valeur par défaut qui lève — `use_cases/classroom/manage_classroom_assignment.rb:21`

```ruby
classroom_access_policy: Policies::ClassroomAccessPolicy.new
```
lève `ArgumentError: missing keyword :classroom_repo`. La policy n'est donc jamais « par défaut » : elle est obligatoire de fait, et tout appelant qui omet l'argument plante. Une valeur par défaut qui ne peut pas être évaluée est pire qu'une absence de valeur par défaut.

### 4. Échec silencieux — `manage_classroom_assignment.rb:50-51`

Quand `@assignment_repo.save` renvoie `false` après un `valid?` réussi, `errors: assignment.errors.full_messages` est **vide**. L'échec remonte sans aucun message : l'utilisateur voit une opération échouer sans savoir pourquoi, et le développeur n'a rien à déboguer.

## Pour qui

Les **développeurs et les agents** qui écrivent du code par-dessus ces contrats. Un port incomplet se paie au premier adaptateur alternatif ; une dépendance non injectable se paie à chaque test qu'on renonce à écrire.

Le point 4 touche aussi l'utilisateur final : une assignation qui échoue en silence.

## Pourquoi maintenant

Ces quatre points ont été découverts en écrivant les tests, et chacun a **forcé un compromis dans le test** : mock documentant un écart, test non écrit, assertion déplacée. C'est le signe qu'ils gênent déjà le travail quotidien.

## Hors périmètre

- La question du contrat de retour des use cases (`OpenStruct` vs objet `Result` dédié) → `docs/guide/conventions.md` §8, mérite son propre ADR.
- La migration des namespaces dupliqués.

## Ce que le grill a révélé

> À remplir en phase 1. Question de méthode : **traiter les 4 points ensemble, ou séparément ?**

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- Compléter un port oblige à vérifier **tous** ses adaptateurs — c'est le moment de contrôler que les autres ports ne mentent pas de la même façon (un audit systématique port ↔ adaptateur serait plus rentable que quatre corrections isolées).
- Rendre `purge_demo_students` injectable change sa signature : tracer les appelants (contrôleurs, tâches rake, jobs).
- Le point 3 se corrige en retirant la valeur par défaut, ou en la rendant paresseuse — mais retirer une valeur par défaut est un changement de contrat public.
- Le point 4 exige de décider **où** se construit le message d'erreur : dans le repository qui sait pourquoi ça a échoué, ou dans le use case.

## Questions encore ouvertes

- Combien d'autres ports déclarent un contrat différent de celui que leurs use cases consomment ? Un audit automatisé est-il possible (comparer les méthodes appelées sur une dépendance injectée aux méthodes déclarées par le port) ?
