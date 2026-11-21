# ADR-XXXX : L'entrée élève révèle si un numéro est inscrit
<!-- index
titre: Entrée élève unique : un numéro inscrit se révèle
statut: Accepté
problematique: une seule entrée numéro + code pour l'élève doit dire si le numéro a un compte, ce que la connexion cachait
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-20 |
| **Chantier** | `docs/chantiers/entree-eleve-unifiee` |
| **Remplace** | — (amende ADR-0050 §4 pour la seule entrée élève : message distinct sur un numéro inscrit) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

À Tiassalé (2026-11-20), des élèves sans compte touchent « Se connecter » et restent devant « Numéro ou code secret incorrect » ; d'autres, inscrits, refont une inscription. Le porteur a décidé (D2, [memo du programme](../../chantiers/retours-terrain-tiassale/memo.md)) qu'un clic sur « Je suis élève » montre numéro et code secret, et que la suite dépend du numéro : inscrit, on connecte ; inconnu, on continue la création du compte.

La connexion (`/login`, ADR-0050) donne le même message à un numéro inconnu et à un code faux, pour ne pas dire quels numéros ont un compte. L'entrée unique ne peut pas tenir cette règle : elle doit choisir entre connecter et inscrire. L'inscription élève la cassait déjà (« Ce numéro est déjà utilisé »), à 5 envois par minute.

Deux autres contraintes : une classe s'inscrit ensemble derrière une seule adresse (wifi de l'école, chantier `inscription-classe-meme-wifi`, ADR-0085 §4.7), et le code choisi à l'entrée doit traverser une inscription en plusieurs écrans, dont le repli sans JavaScript qui recharge la page en GET.

## 2. Moteurs de décision

- L'élève ne choisit plus entre « se connecter » et « créer un compte » (décision du porteur).
- Jamais un second compte sur un numéro inscrit.
- Le code d'un compte reste aussi protégé qu'à `/login` (verrouillage progressif par numéro, ADR-0050).
- Une classe de 40 à 60 élèves sur un même wifi n'est jamais bloquée.
- Le code secret n'apparaît ni dans une adresse, ni dans une page, ni dans un journal.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder le message unique, proposer « Créer un compte » sous l'erreur | Ne révèle rien | C'est le parcours qui a échoué à Tiassalé : l'élève sans compte lit « incorrect » et s'arrête |
| B — Entrée unique, révélation assumée, débit large par adresse et plafond horaire | Le parcours voulu ; le code reste protégé par le verrouillage par numéro | Un tiers peut tester des numéros (coût consenti, §5) |
| C — Entrée unique, débit de `/login` (5 par minute) | Enumération plus lente | Bloque une classe sur un wifi à la 6e tentative |
| Garde du code : champ caché dans la page | Simple | Le code dans le HTML ; perdu au rechargement GET sans JavaScript |
| Garde du code : condensat bcrypt en session, port d'inscription élargi | Pas de code en clair | Change le port `RegistrationRepositoryPort` pour un seul appelant |

## 4. Décision

> **Nous révélons, à l'entrée élève seulement, si un numéro est inscrit, et nous bornons ce que cela coûte.**

1. **Révélation.** Sur un numéro inscrit, un code faux reçoit « Code secret incorrect » (erreur du champ code) et le lien « Code secret oublié ? ». Un numéro inconnu reçoit « Ce numéro n'a pas encore de compte », le numéro affiché, et la confirmation du code. Rien d'autre n'est révélé : ni nom, ni rôle, ni classe. `/login` garde son message unique.
2. **Débit.** `POST /student` : 120 envois par minute et 600 par heure, par adresse (un nouvel élève envoie deux fois : numéro et code, puis confirmation). L'inscription qui suit l'entrée, sans code de classe, a son compteur (60 par minute et par adresse) à la place des 10 et 5 par minute de la voie directe ; avec un code de classe, la devinette de codes garde ses limites. Le code d'un compte reste gardé par le verrouillage par numéro d'ADR-0050 : l'entrée passe par `UseCases::Identity::Authenticate`, qui compte chaque échec.
3. **Garde du code.** Numéro, code, état (confirmé ou non) et jeton du lien de classe vivent dans la session Rails (cookie chiffré et authentifié, HttpOnly), 30 minutes au plus ; `start_session` la remet à zéro à la connexion ou à la création du compte. Le formulaire d'inscription n'envoie plus ni numéro ni code : le contrôleur les reprend de la session.
4. **Jamais de second compte.** Un numéro inscrit passe toujours par la connexion, même s'il porte une confirmation ; un numéro pris entre l'entrée et la fin de l'inscription est refusé par l'index unique (`RegistrationRepository`, `:conflict`).
5. **Tout rôle.** Un compte enseignant, direction ou équipe qui passe par l'entrée est connecté comme à `/login`, coque Android comprise (ADR-0086 §4.5).

## 5. Conséquences

### 🟢 Positives

- Un seul geste pour l'élève, inscrit ou non ; le lien de classe `/c/<jeton>` passe aussi par l'entrée et garde sa classe.
- Aucun nouveau port, aucune table : `EnterAsStudent` compose `Authenticate` et `users#find_by_contact`.

### 🔴 Coûts consentis

- **Énumération** : depuis une adresse, 600 numéros par heure peuvent être testés (14 400 par jour) ; un attaquant à plusieurs adresses va plus vite. Un numéro ivoirien inscrit devient une information devinable. Le porteur l'assume (D2) ; aucune donnée du compte n'est révélée.
- **Code en clair dans le cookie de session**, chiffré (AES-256-GCM), pendant 30 minutes au plus. Un téléphone partagé garde l'entrée tant que la session vit ; le cookie ne se lit pas sans la clé du serveur.
- Une école entière derrière une adresse qui dépasse 600 entrées dans l'heure lit « Trop de tentatives » : le plafond horaire se relève si la mesure le montre.

## 6. Notes d'implémentation

```ruby
# app/domain/use_cases/identity/enter_as_student.rb
return sign_in(dto) if @users.find_by_contact(contact: dto.contact)
return entered(:new_number, dto) unless dto.confirming?
```

```ruby
# app/controllers/identity/student_entries_controller.rb
RATE_LIMIT = { to: 120, within: 1.minute, scope: "identity/student_entries" }.freeze
HOURLY_RATE_LIMIT = { to: 600, within: 1.hour, scope: "identity/student_entries_hourly" }.freeze
REGISTRATION_RATE_LIMIT = { to: 60, within: 1.minute, scope: "identity/student_entry_registrations" }.freeze
```

```ruby
# app/controllers/concerns/student_entry_session.rb
TTL = 30.minutes
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/identity/enter_as_student_test.rb` : connexion, code faux compté, numéro inconnu, confirmation, numéro inscrit qui l'emporte.
- `test/controllers/identity/student_entries_controller_test.rb` : CA-4 (message et lien), CA-7 (aucun second compte), CA-10 (débits : 120 passent, le 121e reçoit 429 ; 12 inscriptions en une minute), CA-11 (30 minutes), et l'absence du code dans les pages (`assert_no_match "1357"`).
