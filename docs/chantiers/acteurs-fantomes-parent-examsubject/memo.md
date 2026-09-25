# Memo — `Parent` et `ExamSubject` : déclarés partout, persistés nulle part

| | |
|---|---|
| **Type de cycle** | bugfix (défensif) |
| **Statut** | décision — cadrage terminé, prêt à planifier |
| **Ouvert le** | 2026-09-18 |
| **Branche** | `fix/acteurs-fantomes-parent-examsubject` |
| **Gravité** | 🟡 **Moyenne — un état invalide peut être écrit en base** |

> ✅ **Décision produit rendue le 2026-09-18.** Le profil Parent et les sujets d'examen sont **reportés, pas abandonnés** : `ExamSubject` sera traité pendant la période de préparation aux examens. Le chantier se limite donc à empêcher l'usage de ces deux concepts tant qu'ils ne sont pas persistés. Voir « Ce que le grill a révélé ».

---

## Le problème

Deux concepts sont présents dans le vocabulaire, les entités et les validations du projet, mais **n'ont aucune persistance**.

### `Parent`

- Présent dans l'`enum` de rôles de `Orm::User` (préfixe `prnt_`).
- Documenté comme acteur du domaine dans l'ancien `CONTEXT.md` : *« Tuteur légal suivant la progression d'un élève »*.
- **Absent** : pas de table `parents`, pas de `Orm::Parent`, pas d'entité. `User#profile` renvoie `nil` pour ce rôle.

Autrement dit : on peut créer un utilisateur « parent » qui n'a accès à rien et dont le profil est nul.

### `ExamSubject`

- `app/domain/entities/exam_subject.rb` existe.
- `Entities::ClassroomAssignment` accepte `resource_type: "ExamSubject"` via une validation `inclusion`.
- **Absent** : pas de table `exam_subjects`, pas de `Orm::ExamSubject`.

Conséquence mesurée : une assignation avec `resource_type: "ExamSubject"` passe la validation du domaine, puis produit `"Orm::ExamSubject"` côté SQL et **casse à la lecture polymorphe**. Le domaine autorise un état que l'infrastructure ne peut pas servir.

## Pour qui

- **Parent** : un rôle entier de la plateforme, annoncé dans le glossaire métier, sans aucune fonctionnalité derrière.
- **Team / Teacher** : les sujets d'examen (BAC, BEPC) sont un pilier pédagogique annoncé, et ils ne sont pas assignables en pratique.

## Pourquoi maintenant

Ce n'est pas un bug à corriger, c'est une **dette de cohérence** : le vocabulaire du projet promet des choses que le code ne tient pas. Un agent IA qui lit le glossaire ou les entités conclut légitimement que ces concepts existent, et écrit du code par-dessus. C'est un piège à régressions futures.

Trancher coûte peu maintenant, beaucoup plus tard.

## Hors périmètre

L'implémentation complète d'un espace Parent — si c'est la décision retenue, ce sera son propre chantier de fonctionnalité.

## Ce que le grill a révélé

Les deux questions produit ont été tranchées par le propriétaire le **2026-09-18**.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le rôle Parent est-il au programme, et à quel horizon ? | **Pas encore implémenté.** Le profil parent reste au programme, sans date. | On ne retire rien. Le rôle demeure déclaré, mais on empêche qu'un compte soit créé avec lui tant que le profil n'existe pas. |
| Les sujets d'examen doivent-ils être assignables à une classe ? | **Laissé de côté pour l'instant.** Son heure viendra pendant la période de préparation aux examens. | On ne construit pas `Orm::ExamSubject` maintenant. On empêche qu'un `resource_type: "ExamSubject"` soit accepté tant que la persistance n'existe pas. |

**Le chantier change donc de nature** : ce n'est plus « implémenter ou supprimer », c'est **poser des garde-fous sur deux concepts en attente**. Le type de cycle devient un `bugfix` défensif, et son périmètre se réduit.

Ce qu'il faut empêcher, et pourquoi :

- Aujourd'hui, `Entities::ClassroomAssignment` **accepte** `resource_type: "ExamSubject"` par validation `inclusion`. La donnée passe le domaine, puis casse à la lecture polymorphe côté SQL. Un état invalide peut donc être écrit en base et ne se révéler qu'à la relecture — c'est le pire moment pour le découvrir.
- Un utilisateur créé avec le rôle `prnt_` se retrouve avec un profil `nil` et aucun accès. Mieux vaut refuser la création que livrer un compte inerte.

Les deux concepts **restent dans le glossaire et dans les entités**, marqués « en attente d'implémentation » — pour qu'un agent qui les croise sache qu'ils sont prévus et non oubliés.

## Cas limites identifiés

- **Si Parent est au programme** : le laisser dans l'`enum` est acceptable à condition de documenter qu'il est inactif, et d'empêcher la création d'un compte avec ce rôle en attendant.
- **Si Parent est abandonné** : le retirer de l'`enum`, du glossaire et des entités — sinon il ressurgira dans six mois.
- **Pour `ExamSubject`** : soit l'entité liste un type mort et la validation doit le retirer, soit le modèle ORM manque et il faut le créer. Le statu quo est le seul choix intenable, parce qu'il laisse passer une donnée invalide.
- Vérifier s'il existe des utilisateurs avec le rôle `prnt_` en base avant toute décision.

## Questions encore ouvertes

- L'ADR-0002 (authentification par contact téléphonique) prévoyait-il le rôle Parent ?
- `.Business/` contient de la documentation produit — le rôle Parent y figure-t-il comme engagement commercial ?
