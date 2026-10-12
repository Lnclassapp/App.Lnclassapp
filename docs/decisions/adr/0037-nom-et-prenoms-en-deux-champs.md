# ADR-0037 : Nom et Prénom(s) en deux champs, sans changement de casse
<!-- index
titre: Nom et Prénom(s) en deux champs, sans changement de casse
statut: Accepté
problematique: `last_name` et `first_name`, `squish` seul, aucun `titleize` ; tri par nom ; aucun slug de compte. F-15.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-15**, bloque la V1 (Lot A) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ancien dépôt demande un « nom complet » en un seul champ. Il le découpe au dernier mot (« le dernier mot est le prénom »), ce qui est faux pour la plupart des noms ivoiriens, où l'on écrit le nom puis un ou plusieurs prénoms. Il applique ensuite `titleize` aux noms propres **et** aux titres de contenu : « Svt », « D'almeida », « Kouassi Ange-marie ». Le slug du compte (`friendly_id :fullname`) dépendait de ce découpage.

## 2. Moteurs de décision

1. La liste de classe se lit comme la liste officielle de l'établissement : nom, puis prénoms.
2. Ce que l'utilisateur a tapé est ce qui s'affiche.
3. Aucune règle de découpage à deviner.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Un champ, découpé au dernier mot | Un champ de moins | Faux pour les prénoms composés et multiples |
| B — **Deux champs, Nom et Prénom(s)** | Exact, triable par nom | Un champ de plus au formulaire d'inscription |

## 4. Décision

> **Nous saisissons le nom et les prénoms dans deux champs distincts, nous les normalisons seulement sur les espaces, et nous ne changeons jamais la casse d'un nom propre ni d'un titre de contenu.**

**Colonnes** sur `users` :

| Colonne | Libellé | Contrainte |
|---|---|---|
| `last_name` | « Nom » | `string(50) NOT NULL` |
| `first_name` | « Prénom(s) » | `string(80) NOT NULL` |

**Validation** : `Dtos::Identity::PersonNameInput` et l'entité `Entities::Identity::User`.

- Chaque champ fait au moins 1 caractère après normalisation.
- Il ne contient que des lettres Unicode, des marques diacritiques, des espaces, des traits d'union et des apostrophes (`'` et `’`), selon le motif `/\A[\p{L}\p{M}'’ \-]+\z/`.
- Sinon, `:invalid`.

**Normalisation** : `String#squish` seulement (espaces en tête et en fin retirés, espaces internes réduits à un seul). Aucun `titleize`, `capitalize`, `upcase` ni `downcase` à l'enregistrement.

**Affichage** :

- listes nominatives et exports : `last_name` puis `first_name`, triés par `last_name`, puis `first_name` ;
- salutation : `first_name` seul.

Une mise en majuscules du nom, si l'UDR la demande, est purement visuelle (classe CSS), jamais stockée.

**Titres de contenu** : `courses.name`, `essentials.name`, `exercises.title`, `materials.name` et les noms d'école sont enregistrés tels que saisis, après `squish`. « SVT » reste « SVT ».

**Aucun slug de compte** : les comptes sont adressés par `public_id` (ADR-0029). La règle « le dernier mot du nom complet est le prénom » n'existe plus nulle part.

## 5. Conséquences

### 🟢 Positives

- Les listes de classe sont conformes aux listes officielles, triables par nom.
- « D'Almeida » et « SVT » restent tels qu'on les a tapés.
- Aucune migration : il n'y a pas de données à découper (ADR-0034).

### 🔴 Coûts consentis

- Un champ de plus à l'inscription de l'élève, sur mobile.
- Une faute de casse de l'utilisateur (« kouassi ») est conservée telle quelle. On préfère ce défaut à une correction automatique fausse.
- L'ordre des prénoms n'est pas structuré : « Prénom(s) » est une seule chaîne.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Dtos::Identity::PersonNameInput
# Rôle : valide et normalise nom et prénom(s), sans toucher à la casse
# ADR  : 0037
module Dtos
  module Identity
    class PersonNameInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      NAME_FORMAT = /\A[\p{L}\p{M}'’ \-]+\z/

      attribute :last_name, :string
      attribute :first_name, :string

      validates :last_name, presence: true, length: { maximum: 50 }, format: { with: NAME_FORMAT }
      validates :first_name, presence: true, length: { maximum: 80 }, format: { with: NAME_FORMAT }

      def last_name = super&.squish
      def first_name = super&.squish
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- Test de DTO : « d'almeida » reste « d'almeida » ; «  Kouassi   Ange-Marie  » devient « Kouassi Ange-Marie » ; « Jean3 » est refusé.
- `test/architecture/no_titleize_test.rb` échoue si `titleize` ou `capitalize` apparaît dans `app/`.

## 8. Remplace, complète, amende

- Ne remplace aucun ADR. Il abandonne la règle de découpage de l'ancien [`plan.md`](../../chantiers/refonte-application/plan.md) et le slug de compte `friendly_id :fullname`.

## 9. Points à confirmer par le porteur

- Longueurs maximales : 50 caractères pour le nom, 80 pour les prénoms.
- Chiffres et points refusés dans les noms.
