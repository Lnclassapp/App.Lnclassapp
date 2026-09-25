# Memo — Code d'adhésion généré trop long pour sa colonne

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | cadrage |
| **Ouvert le** | 2026-09-18 |
| **Branche** | `fix/classroom-code-adhesion-trop-long` |
| **Gravité** | 🟡 **Moyenne — création de classe cassée sur un chemin** |

---

## Le problème

`app/domain/use_cases/classroom/create_classroom.rb:42` génère `SecureRandom.alphanumeric(6)` — **6 caractères**.
La colonne `classrooms.unique_code` est déclarée `limit: 5` (`db/schema.rb:97`).

Toute création passant par ce chemin explose ou tronque silencieusement à l'insertion.

Pire : `Orm::Classroom.generate_unique_code` produit bien **5** caractères. Deux générateurs coexistent et divergent, ce qui veut dire que le comportement dépend du chemin emprunté.

## Pour qui

**Teacher** et **SchoolStaff** : la création d'une classe, et le code que les élèves utilisent pour la rejoindre.

## Pourquoi maintenant

C'est le bug le moins coûteux à corriger de la liste et il touche un parcours d'entrée (rejoindre une classe). Une troncature silencieuse est pire qu'une erreur : deux classes peuvent finir avec le même code.

## Hors périmètre

Toute évolution du mécanisme d'adhésion (durée de vie du code, révocation, format lisible).

## Ce que le grill a révélé

> À remplir en phase 1. La question à trancher : **5 caractères, est-ce assez ?**

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- Corriger le générateur à 5 caractères, **ou** élargir la colonne : ce n'est pas la même décision. 5 caractères alphanumériques donnent ~916 millions de combinaisons en sensible à la casse, mais l'ORM applique un `downcase` — ce qui ramène à ~60 millions. À confronter au nombre de classes attendu.
- Vérifier la gestion des collisions : que se passe-t-il si le code tiré existe déjà ? Y a-t-il un index unique, une reprise ?
- Unifier les deux générateurs : avoir une seule source de vérité est plus important que la longueur retenue.
- Le test existant écrivait 5 caractères **en majuscules** alors que l'ORM `downcase` — il passait par hasard.

## Questions encore ouvertes

- Combien de classes la plateforme prévoit-elle à 2 ans ? C'est cette réponse qui fixe la longueur, pas l'inverse.
