# ADR-0017 : Remplacement de Nanoid par SecureRandom natif
<!-- index
titre: Remplacement de Nanoid par SecureRandom natif
statut: Accepté — *complété par [0029](./0029-identifiants-exposes-public-id-et-slugs.md)*
problematique: Supprimer la dépendance `nanoid` et le concern `PublicIdGenerator` au profit de `SecureRandom.base58` pour alléger l'application.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-08-21 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |
| **Complété par** | [ADR-0029](./0029-identifiants-exposes-public-id-et-slugs.md) : longueur, tables concernées, absence de préfixe, index et nouvel essai |

---

> ⚠️ **Décision complétée — `public_id` de 14 caractères sans préfixe.**
> L'[ADR-0029](./0029-identifiants-exposes-public-id-et-slugs.md) complète cet ADR le 2026-09-25 : `SecureRandom.base58(14)` sans préfixe de rôle, index unique et un nouvel essai en cas de collision. Le reste de l'ADR demeure en vigueur.

## 1. Contexte et problématique
L'application utilisait la gem `nanoid` et un concern complexe `PublicIdGenerator` pour générer des identifiants publics (`public_id`) de 14 caractères, ainsi que des slugs pour certains modèles. Bien que très performante, cette approche ajoutait une dépendance externe à l'application et de la complexité inutile, alors que Ruby 3+ et Rails 8 fournissent des outils natifs extrêmement robustes pour la génération aléatoire sécurisée.

## 2. Moteurs de décision
1. **Minimisation des Dépendances** : Réduire la taille du `Gemfile` et la surface d'attaque en s'appuyant au maximum sur les standards (Vanilla Rails/Ruby).
2. **Performance et Maintenabilité** : Supprimer l'usine à gaz `PublicIdGenerator` (50 lignes) qui gérait la génération d'identifiants préfixés, des boucles de ré-essais, etc.
3. **Simplicité** : `SecureRandom.base58` (intégré à Ruby depuis la version 3.3/ActiveSupport) produit un alphabet sans caractères ambigus (0/O, 1/I/l), tout comme le faisait la configuration par défaut de `nanoid`.

## 3. Décision
1. **Suppression** totale de la gem `nanoid` (`bundle remove nanoid`).
2. **Suppression** de `app/models/concerns/public_id_generator.rb`.
3. **Refonte de la macro `has_nanoid`** dans `ApplicationRecord` pour utiliser `SecureRandom.base58(14)` au lieu de `Nanoid.generate`.
4. **Simplification du modèle User** pour remplacer le concern lourd par un simple callback `before_create` qui génère le préfixe concaténé au token.

## 4. Notes d'implémentation
La fonction `has_nanoid` a été réécrite ainsi dans `ApplicationRecord` :
```ruby
def self.has_nanoid(field = :public_id)
  before_create do
    self.send("#{field}=", SecureRandom.base58(14)) if self.send(field).blank?
  end
end
```

*(Note : Nous n'avons pas pu utiliser `has_secure_token` car ce dernier impose, par mesure de sécurité contre le brute force, une longueur minimale stricte de 24 caractères, alors que le standard historique de l'application était fixé à 14).*

## 5. Conséquences
- **Positives** : Réduction du code mort, suppression d'une gem, performances maintenues, architecture allégée.
- **Négatives** : Aucune.
