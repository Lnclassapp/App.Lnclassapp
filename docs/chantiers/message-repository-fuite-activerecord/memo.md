# Memo — Fuite d'objets ActiveRecord dans `Entities::Message`

| | |
|---|---|
| **Type de cycle** | refactoring |
| **Statut** | cadrage |
| **Ouvert le** | 2026-09-18 |
| **Branche** | `refactor/message-repository-fuite-activerecord` |
| **Gravité** | 🟠 **Haute — violation de la Règle d'Or « Zéro Couplage »** |

---

## Le problème

`app/infrastructure/repositories/communication/message_repository.rb:74-76` place des objets ActiveRecord **directement dans une entité du domaine** :

- `record.content` → un `ActionText::RichText`
- `record.image_cover` → un `ActiveStorage::Attached`
- `record.message_audio` → un `ActiveStorage::Attached`

`Entities::Message` tient donc des objets qui savent parler à la base. C'est exactement ce que l'architecture hexagonale interdit : le domaine devient dépendant du framework, et toute manipulation de l'entité peut déclencher une requête SQL imprévue.

Un repository doit **mapper explicitement** record → entité et ne retourner que des types du domaine. Ici, il passe l'objet ORM tel quel.

## Pour qui

Personne ne le voit aujourd'hui côté utilisateur. C'est un problème de **maintenabilité et de testabilité** : une entité qui tient un `ActionText::RichText` ne peut pas être testée sans base de données, ce qui contamine toute la couche domaine du contexte `communication`.

## Pourquoi maintenant

Deux raisons :

1. La branche `feature/ticket-5-messaging` est **en cours** — le contexte `communication` est jeune et peu ramifié. Le corriger maintenant coûte une fraction de ce qu'il coûtera quand la messagerie sera partout.
2. Le garde-fou de pureté du domaine est en cours de mise en place. Autant que le premier code qu'il protège soit propre.

## Hors périmètre

- Toute évolution fonctionnelle de la messagerie.
- La question générale du contrat de retour des use cases (`OpenStruct` vs objet `Result`) → `docs/guide/conventions.md` §8.

## Ce que le grill a révélé

> À remplir en phase 1. La vraie question : **quel type du domaine représente un contenu riche et une pièce jointe ?**

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- Le contenu riche doit-il descendre dans le domaine en texte brut (`to_plain_text`), en HTML, ou via un objet de valeur dédié ? La réponse dépend de ce que le domaine en fait réellement — s'il ne fait que le transporter vers la vue, un type simple suffit.
- Les pièces jointes (image de couverture, audio) : le domaine a-t-il besoin de l'objet, ou seulement d'une URL et de métadonnées ?
- Le test existant `test/infrastructure/repositories/communication/message_repository_test.rb` **assume** la fuite en appelant `.to_plain_text`. Il devra être adapté — c'est le signal que le contrat change.
- ⚠️ Vérifier si le garde-fou de pureté détecte ce cas : l'objet est **injecté à l'exécution**, pas référencé dans `app/domain/`. Un scan statique de `app/domain/` peut très bien ne rien voir.

## Questions encore ouvertes

- Y a-t-il d'autres repositories qui fuient de la même façon ? Un audit des `map_to_entity` s'impose avant de conclure.
- Défaut mineur rattaché au même fichier : `message_repository.rb:21-27`, `find_by_slug` utilise `rescue StandardError` + `return` **depuis un bloc `ensure`**, ce qui avale toute exception et rend le flux opaque. À traiter au passage.
