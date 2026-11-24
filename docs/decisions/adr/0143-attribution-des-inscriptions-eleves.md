# ADR-0143 : Chaque inscription élève garde sa source et son invitant, dans une table écrite une fois
<!-- index
titre: Attribution des inscriptions élèves (k-factor)
statut: Accepté
problematique: mesurer qui a fait venir chaque élève (QR, camarade, lien, code, à froid) sans exposer l'invitant ni réécrire la voie d'arrivée
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-20 |
| **Chantier** | `docs/chantiers/partage-classe-k-factor` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le playbook de lancement d'une ville (programme `retours-terrain-tiassale`, D4) se juge sur un k-factor élève par classe : combien d'élèves sont venus par le QR de la classe ou par l'invitation d'un camarade, pour chaque inscrit. Rien ne le mesure aujourd'hui.

La voie d'arrivée d'un élève dans une classe (`classroom_students.joined_via` : `standard`, `link`, `code`) ne peut pas porter cette mesure :

- elle est **réécrite** à chaque retour dans une classe (ADR-0085) ; la source d'une inscription doit être un fait figé ;
- sa contrainte et ses lecteurs (entonnoir AARRR, fiches de classe) n'ont que trois valeurs, et « QR » ou « invitation » y seraient des cas de `link` ;
- elle n'a pas de place pour l'invitant.

Le lien d'invitation d'un élève doit désigner l'invitant **sans exposer l'élève** : l'identifiant public d'un élève sert dans des adresses d'enseignant et ne doit pas circuler dans des groupes WhatsApp. Et le QR de la classe ne doit porter **aucun secret de plus** que le lien de classe (point de vigilance D4).

## 2. Moteurs de décision

- Un fait de mesure ne se réécrit pas ; les lecteurs existants de `joined_via` ne changent pas.
- Aucune donnée d'élève exposée à l'invitant ni dans le lien ; aucun droit donné par une attribution.
- Une attribution ne fait jamais échouer une inscription.
- Le moins de surface possible : pas de traceur, pas d'événement de clic (ADR-0049, ADR-0062).

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Ajouter `qr` et `student_invite` à `joined_via`, et une colonne d'invitant sur `classroom_students` | Pas de table | Réécrite au retour dans une classe ; casse le sens « amené par sa classe » de l'entonnoir ; mêle mesure et appartenance |
| B — Une table `signup_attributions`, une ligne par élève, écrite dans la transaction de l'inscription ; un code d'invitation opaque par élève dans `student_invite_codes` | Fait figé, lecteurs existants intacts, l'invitant ne circule que sous un code aléatoire | Deux tables de plus |
| C — L'invitant signé dans l'URL (`MessageVerifier`), sans table de codes | Pas de table de codes | Lien long dans WhatsApp ; le contenu signé est lisible (base64) et porterait l'identifiant interne |
| D — Une colonne `invite_code` sur `users` | Pas de table de codes | Colonne de l'identité pour un besoin de la classe ; remplie pour tous les rôles |

## 4. Décision

> **Nous enregistrons la source de chaque inscription élève dans `signup_attributions`, une ligne par élève, écrite une fois dans la transaction de `RegisterStudent` et jamais réécrite ; l'invitant est désigné par un code d'invitation opaque de 8 caractères (`student_invite_codes`) ; le QR porte le lien de classe avec la seule étiquette `s=qr`.**

### 4.1 Tables

```
signup_attributions
  student_id    bigint  not null, unique, FK users ON DELETE CASCADE
  classroom_id  bigint  not null, FK classrooms
  source        string  not null, CHECK IN ('qr','student_invite','teacher_link','code','cold')
  inviter_id    bigint  null, FK users ON DELETE SET NULL
  created_at    datetime not null default now()
  CHECK (inviter_id IS NULL OR source = 'student_invite')
  CHECK (inviter_id IS NULL OR inviter_id <> student_id)
  index (created_at), index (classroom_id), index (inviter_id) where inviter_id is not null

student_invite_codes
  student_id  bigint  not null, unique, FK users ON DELETE CASCADE
  code        string(8) not null, unique, CHECK code ~ '^[a-hjkmnp-z2-9]{8}$'
  created_at  datetime not null default now()
```

Un `inviter_id` supprimé (compte supprimé) laisse la source `student_invite` : l'invitation a eu lieu.

### 4.2 Résolution de la source (domaine, pur)

`Entities::Classroom::SignupSource.resolve(via:, qr:, inviter_id:)` :

| Désignation de la classe (`ClassroomDesignation`) | Invitant résolu | `s=qr` | Source |
|---|---|---|---|
| lien | oui | — | `student_invite` (+ invitant) |
| lien | non | oui | `qr` |
| lien | non | non | `teacher_link` |
| code | — | — | `code` |
| classe choisie | — | — | `cold` |

Un code d'invitation n'est résolu que sur la voie du lien : un lien mort qui retombe sur la cascade est « à froid ».

### 4.3 Code d'invitation

- 8 caractères de l'alphabet sans ambiguïté des codes de classe (`a-h j k m n p-z 2-9`, 31 signes : ≈ 8,5 × 10¹¹ codes), tirés par `SecureRandom` ; une collision à l'insertion retente (3 fois au plus).
- Créé au premier envoi de « Invite tes camarades » (POST), puis réutilisé. Jamais créé par une page lue (GET).
- `inviter_for(code:)` ne renvoie qu'un élève non anonymisé ; sinon `nil`. Un code ne donne accès à rien : il n'est lu que par l'inscription.

### 4.4 Étiquette du QR

Le QR encode `join_classroom_url(jeton, s: "qr")`. `s` n'est pas un secret : n'importe qui peut l'ajouter. La mesure est **déclarative** et sert au pilotage, jamais à un droit.

### 4.5 Ce que voit qui

L'élève invitant ne voit rien (ni nombre, ni nom). L'enseignant et la direction ne voient rien de l'attribution. L'équipe lit des **agrégats** par classe et par établissement (`Queries::Classroom::SignupKFactorQuery`), jamais un nom d'élève.

## 5. Conséquences

### 🟢 Positives

- Le k-factor élève se lit par classe et par établissement, dès la première inscription du jour J.
- `joined_via` et ses lecteurs ne changent pas.
- Le lien d'invitation ne transporte aucun identifiant d'élève.

### 🔴 Coûts consentis

- Deux tables de plus, et une écriture de plus dans la transaction d'inscription.
- La source est **déclarative** : `?s=qr` et un code d'invitation partagé hors de la classe peuvent gonfler le k. Sans récompense ni vue pour l'élève, l'incitation à tricher est nulle ; aucune anti-fraude n'est construite.
- Les inscriptions antérieures au déploiement n'ont pas de source : la mesure commence au déploiement (la page le dit).
- Un élève qui change de classe garde l'attribution de la classe de son inscription.
- Le QR imprimé meurt quand l'enseignant change le lien de sa classe (la confirmation le dit).

## 6. Notes d'implémentation

```ruby
# app/domain/entities/classroom/signup_source.rb
module Entities
  module Classroom
    module SignupSource
      QR = "qr"
      STUDENT_INVITE = "student_invite"
      TEACHER_LINK = "teacher_link"
      CODE = "code"
      COLD = "cold"
      ALL = [ QR, STUDENT_INVITE, TEACHER_LINK, CODE, COLD ].freeze
      QR_TAG = "qr" # valeur du paramètre s

      def self.resolve(via:, qr:, inviter_id:)
        case via
        when "link" then inviter_id ? STUDENT_INVITE : (qr ? QR : TEACHER_LINK)
        when "code" then CODE
        else COLD
        end
      end
    end
  end
end
```

```ruby
# app/domain/ports/classroom/signup_attribution_repository_port.rb
#   record(student_id:, classroom_id:, source:, inviter_id:, at:) → Shared::Result (success même si une ligne existait : elle reste)
# app/domain/ports/classroom/invite_code_repository_port.rb
#   code_for(student_id:) → Shared::Result(String)   (crée au besoin)
#   inviter_for(code:)    → Integer | nil            (élève non anonymisé seulement)
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/classroom/signup_source_test.rb` : le tableau §4.2, ligne par ligne.
- `test/infrastructure/repositories/classroom/signup_attribution_repository_test.rb` : une seconde écriture ne réécrit pas ; la contrainte refuse un invitant hors `student_invite`.
- `test/infrastructure/repositories/classroom/invite_code_repository_test.rb` : code stable, format, élève anonymisé → `nil`.
- `test/domain/use_cases/classroom/register_student_test.rb` : chaque source, et un code inconnu qui n'échoue jamais.
- `grep -rn "signup_attributions\|student_invite_codes" app/views app/controllers` ne trouve rien : seules les queries et repositories lisent ces tables.
