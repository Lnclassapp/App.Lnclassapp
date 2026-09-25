# ADR-0002 : Authentification Native par Contact Téléphonique (`has_secure_password`) et Abandon de Devise

| | |
|---|---|
| **Statut** | Accepté — *en production* |
| **Date** | 2026-06-12 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique
Dans l'écosystème web traditionnel et les standards Rails, la gem **Devise** est la solution d'authentification par défaut. Cependant, Devise est intrinsèquement conçue autour d'un paradigme occidental centré sur l'**adresse email** comme identifiant unique fondamental.

Dans le contexte opérationnel de Lnclass en Côte d'Ivoire :
* Une grande partie des élèves du secondaire (et de leurs parents) ne possède pas d'adresse email active, ou ne la consulte pas régulièrement.
* En revanche, le **numéro de téléphone mobile (contact)** à 10 chiffres (réseaux Orange, MTN, Moov, Wave) est l'identifiant numérique universel par excellence, utilisé pour les paiements Mobile Money et les échanges quotidiens.
* Devise apporte une surcharge considérable de modules (Confirmable, Recoverable via email, Lockable, etc.) complexes à adapter pour un login par téléphone sans email, créant une dette de maintenance importante et un couplage fort avec ActiveRecord.

---

## 2. Moteurs de décision
* **Adéquation Culturelle et Réalité du Terrain :** Faire du contact téléphonique (10 chiffres) l'identifiant unique d'authentification pour 100% des acteurs (Élèves, Enseignants, Parents, Admin).
* **Légèreté et Performance :** Supprimer le poids et la magie noire de Devise au profit des briques d'authentification natives intégrées dans Rails 8 (`ActiveModel::SecurePassword`).
* **Compatibilité Hexagonale :** Pouvoir authentifier un utilisateur via un Use Case pur Ruby (`UseCases::AuthenticateUser`) sans dépendre des helpers de session Devise couplés aux contrôleurs.

---

## 3. Décision
Nous avons pris la décision de **retirer complètement Devise** du projet (Gemfile et schémas) et d'implémenter un système d'authentification natif propulsé par **`bcrypt`** et la méthode **`has_secure_password`** de Rails 8.

1. **Table SQL `users`** : L'attribut unique d'identification est la colonne `contact` (chaîne indexée de 10 caractères), associée à `password_digest`.
2. **Normalisation du Contact :** Tout contact saisi lors de l'inscription ou de la connexion est nettoyé et vérifié pour respecter le format 10 chiffres (suppression des espaces et des indicatifs +225 inutiles en interne).
3. **Session de Sécurité Rails 8 :** La gestion de session HTTP (cookies chiffrés, rotation de session) est prise en charge nativement par des contrôleurs légers (`SessionsController`).

---

## 4. Conséquences

### 🟢 Positives
* **Expérience Utilisateur (UX) Parfaite :** Les élèves s'inscrivent et se connectent instantanément avec leur numéro de téléphone sans la barrière bloquante de l'email.
* **Architecture Propre :** Le Use Case `AuthenticateUser` interroge le `UserRepositoryPort` de manière transparente, respectant la pureté de notre domaine.
* **Code Allégé :** Réduction radicale du nombre de dépendances dans le `Gemfile` et du code de configuration d'authentification.

### 🔴 Coûts consentis
* **Gestion Manuelle des Mots de Passe Oubliés :** La réinitialisation du mot de passe ne peut plus se faire par un simple clic sur un lien email généré par Devise ; elle nécessite l'envoi d'un code de vérification par SMS (via intégration d'une API SMS externe sous `app/infrastructure/external_services/`).

---

## 5. Notes d'implémentation

Extrait du modèle ActiveRecord (`Orm::User`) implémentant la sécurité native :
```ruby
# app/infrastructure/orm/user.rb
module Orm
  class User < ApplicationRecord
    self.table_name = "users"
    
    has_secure_password
    
    validates :contact, presence: true, uniqueness: true, length: { minimum: 10, maximum: 15 }
    validates :role, presence: true
  end
end
```

Implémentation dans le Repository qui vérifie le mot de passe pour le compte du Domaine sans exposer `bcrypt` au métier :
```ruby
# app/infrastructure/repositories/user_repository.rb
module Repositories
  class UserRepository
    include Ports::UserRepositoryPort

    def find_by_contact(contact)
      normalized_contact = contact.to_s.gsub(/\s+/, "")
      record = Orm::User.find_by(contact: normalized_contact)
      map_to_entity(record) if record
    end

    def valid_password?(user_entity, password)
      record = Orm::User.find_by(id: user_entity.id)
      return false unless record
      record.authenticate(password).present?
    end
  end
end
```
