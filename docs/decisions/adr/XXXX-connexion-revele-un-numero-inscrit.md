# ADR-XXXX : La connexion demande le numéro d'abord et révèle s'il a un compte, pour tous les rôles
<!-- index
titre: Connexion « numéro d'abord » : un numéro inscrit se révèle, tout rôle
statut: Accepté
problematique: /login gardait un message unique ; le parcours « numéro d'abord » doit dire si un numéro a un compte, pour tout rôle, sans affaiblir la protection du code
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-26 |
| **Chantier** | `docs/chantiers/connexion-numero-d-abord` |
| **Remplace** | — (amende ADR-0141 §4.1 « `/login` garde son message unique » et §4.2, et ADR-0050 §4 pour `/login`) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

ADR-0141 a fait révéler, à la seule entrée élève, si un numéro a un compte. `/login` gardait le message unique « Numéro ou code secret incorrect » et un débit de 5 envois par minute et par adresse. Le porteur (2026-11-26, décisions 1 à 3) veut le même principe pour tout le monde : la connexion demande d'abord le numéro ; un compte → le code secret ; pas de compte → la création du compte (élève ou enseignant), numéro repris. Il accepte que la connexion révèle qu'un numéro a un compte, pour tous les rôles (élève, enseignant, direction, équipe), avec les limites de l'ADR-0141 étendues.

Le code secret d'un nouveau compte se tape désormais une seule fois (décision 1) : une faute de frappe se rattrape par « Code secret oublié ? » (UDR-0124).

## 2. Moteurs de décision

1. Un seul geste, quel que soit le rôle : le numéro décide de la suite.
2. Le code d'un compte reste aussi protégé qu'avant : verrouillage progressif par numéro (ADR-0050), codes faux comptés par adresse.
3. Une classe derrière un wifi n'est jamais bloquée.
4. Rien d'autre que « a un compte / n'en a pas » n'est révélé : ni nom, ni rôle, ni classe.
5. Les clients qui envoient numéro et code ensemble (coques Android, gestionnaires de mots de passe) continuent de marcher.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — `/login` inchangé, seule l'entrée élève révèle | Énumération limitée à l'entrée élève | Contraire à la demande ; l'enseignant sans compte reste devant « incorrect » |
| B — Numéro d'abord, révélation pour tout rôle, compteurs de l'entrée élève **partagés** entre `/login` et `/student` | Le parcours voulu ; un seul plafond par adresse | Énumération possible des comptes équipe (coût consenti, §5) |
| C — Comme B, compteurs séparés par page | Plus simple | Double le plafond horaire d'un attaquant |
| D — Révéler seulement pour les rôles élève et enseignant | Cache les comptes équipe | Le refus dirait lui-même « ce numéro est un compte protégé » : c'est une révélation de rôle |

## 4. Décision

> **Nous faisons demander le numéro d'abord à `/login` et à `/student`, nous révélons pour tout rôle si ce numéro a un compte, et nous bornons ce que cela coûte par des compteurs partagés.**

1. **Révélation.** Un numéro seul reçoit soit l'étape du code (numéro affiché, rien d'autre), soit « Ce numéro n'a pas encore de compte ». Sur un numéro inscrit, un code faux reçoit « Code secret incorrect » et « Code secret oublié ? ». Ni nom, ni rôle, ni classe. Le second facteur (équipe, direction) suit le code juste, inchangé.
2. **Débit partagé.** `POST /session` et `POST /student` partagent deux compteurs par adresse (`NumberEntryLimit`) : 120 envois par minute et 600 par heure. Le plafond de 5 envois par minute de `/login` disparaît ; les codes faux restent comptés par adresse à 5 par minute (`WrongPinLimit`, commun aux deux pages : au-delà, même un bon code est refusé), et le verrouillage progressif par numéro reste (`UseCases::Identity::Authenticate`).
3. **Garde du numéro.** Le numéro reconnu ou non vit dans la session Rails (cookie chiffré, HttpOnly, 30 minutes, ADR-0141 §4.3) avec son état (`known`) ; l'étape du code n'envoie que le code. L'inscription élève ou enseignant qui suit l'écran « pas de compte » reprend le numéro de la session. Le code d'un nouveau compte élève y est gardé comme avant ; celui d'un enseignant part avec son formulaire et n'est pas gardé.
4. **Code tapé une fois.** Un numéro inconnu suivi d'un code donne l'entrée confirmée ; il n'y a plus d'écran de confirmation. Un numéro devenu inscrit entre-temps passe par la connexion (jamais de second compte, ADR-0141 §4.4).
5. **Envoi groupé.** Un `POST /session` qui porte numéro **et** code garde le comportement d'ADR-0050 : `Authenticate`, message unique sur un échec.
6. **Inscription enseignant.** Plus de confirmation du code ; aucun code d'établissement (voie « sans code », établissement choisi dans la liste, inchangée).

## 5. Conséquences

### 🟢 Positives

- Un seul parcours pour tous ; l'enseignant sans compte arrive à son inscription au lieu d'un refus.
- Aucun port, aucune table : `EnterByNumber` compose `users#find_by_contact` et `Authenticate`.

### 🔴 Coûts consentis

- **Énumération de tous les rôles** : 600 numéros par heure et par adresse, `/login` et `/student` confondus ; un compte équipe ou direction devient devinable comme numéro inscrit. Sa protection reste le code (verrouillage par numéro, plafond par adresse) **et** le second facteur.
- `/login` accepte 120 envois par minute au lieu de 5 : les codes faux y restent à 5 par minute et par adresse, mais les numéros seuls passent au débit de l'entrée élève.
- **Appareil partagé** : le numéro tapé reste à l'étape du code 30 minutes (l'entrée gardée) ; la personne suivante sur la même tablette voit ce numéro et sait qu'il a un compte, sans nom ni rôle. Freins : « Ce n'est pas mon numéro », 5 codes faux par minute et par adresse, verrouillage du numéro. Même coût qu'ADR-0141 §4.3 pour `/student`.
- Un code mal tapé à la création n'est plus vu avant le compte : il passe par « Code secret oublié ? » (WhatsApp, l'équipe).

## 6. Notes d'implémentation

```ruby
# app/controllers/concerns/number_entry_limit.rb
MINUTE = { to: 120, within: 1.minute, scope: "identity/number_entries" }.freeze
HOURLY = { to: 600, within: 1.hour, scope: "identity/number_entries_hourly" }.freeze
```

```ruby
# app/domain/use_cases/identity/enter_by_number.rb
known = !@users.find_by_contact(contact: dto.contact).nil?
return entered(known ? :known : :new_number, dto) if dto.lookup?
return sign_in(dto) if known
entered(creates ? :confirmed : :new_number, dto)
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/identity/enter_by_number_test.rb` : numéro seul (connu, inconnu), connexion, code faux, numéro devenu inscrit, `creates: false`.
- `test/controllers/identity/sessions_controller_test.rb` : CA-1, CA-2, CA-5, CA-6, CA-7 (compteur partagé avec `/student`), CA-8, et l'absence de nom et de rôle dans la page.
- `test/controllers/identity/student_entries_controller_test.rb` : CA-9, CA-10.
