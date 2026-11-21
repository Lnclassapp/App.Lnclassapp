# ADR-XXXX : L'adresse publique d'un établissement mène à l'entrée élève, par son identifiant public existant
<!-- index
titre: Adresse publique d'un établissement (QR de l'accueil élève)
statut: Accepté
problematique: le QR de l'accueil élève doit mener à l'inscription dans un établissement, sans identifiant devinable ni donnée d'élève, ni nouvel oracle d'énumération
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-21 |
| **Chantier** | `docs/chantiers/entree-et-accueil-eleve-allegees` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le porteur remplace le sigle de la carte de classe (accueil élève) par un QR que camarades et enseignants scannent. Il mène à « la page de l'établissement » : l'inscription, établissement déjà choisi, l'élève choisissant ensuite niveau et classe. Le chantier `recherche-etablissement` (ADR-0029, PR #665) ne fournit pas d'adresse par établissement : il fournit une recherche publique qui renvoie, pour chaque établissement actif, son identifiant public (14 caractères base58, `Orm::HasPublicId`), son nom et sa DRENA. L'inscription accepte déjà l'établissement en paramètre GET (repli sans JavaScript, `PICKER_FIELDS`).

L'entrée élève (ADR-0141) est la porte unique de l'élève : numéro et code secret d'abord, puis l'inscription en deux étapes, numéro gardé. Passer le QR directement à `/student-signup` redemanderait numéro et code (trois étapes).

### Menace (écrite d'abord)

| # | Menace | Ce qui la rend possible | Parade retenue |
|---|---|---|---|
| M1 | Énumérer les établissements par l'adresse | Un identifiant séquentiel ou court | L'identifiant public est aléatoire (≈ 82 bits) ; tous les établissements actifs sont déjà listés par la recherche publique : l'adresse n'apprend rien de neuf. Réponse identique pour un identifiant inconnu, inactif ou en brouillon (pas d'oracle d'existence des inactifs). |
| M2 | Lire une donnée d'élève par le QR | Une adresse qui porterait l'élève, sa classe ou un jeton de classe | L'adresse ne porte que l'établissement ; ni l'élève qui le montre, ni sa classe, ni son jeton. |
| M3 | Rattacher quelqu'un d'office | Une adresse qui inscrirait ou rattacherait | L'adresse ne fait que garder un choix ; `RegisterStudent` rejuge l'établissement envoyé ; un connecté est renvoyé à son accueil. |
| M4 | Marteler l'adresse | Adresse publique, sans débit | 60 ouvertures par minute et par adresse IP (une classe derrière un wifi scanne en une minute) ; au-delà, 429 sans rien dire. |
| M5 | Forger l'établissement gardé | La valeur suit l'entrée jusqu'à l'inscription | Valeur gardée en session (cookie chiffré, `StudentEntrySession`), jamais relue depuis la page ; l'inscription la rejuge de toute façon. |
| M6 | Fixer un établissement à un tiers (lien piégé) | Un lien envoyé à une victime | Effet : l'inscription s'ouvre avec un établissement préchoisi, visible et modifiable. Pas d'escalade. Accepté. |

## 2. Moteurs de décision

- Ne créer aucun identifiant ni aucune table : la plus petite adresse stable.
- Ne rien révéler que la recherche publique ne révèle déjà.
- Garder l'entrée élève comme porte unique (ADR-0141), numéro jamais redemandé.
- Un QR lisible à 96 px : une adresse courte.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — `/e/<identifiant public>` → entrée élève, établissement gardé en session | Aucun identifiant nouveau ; courte ; passe par l'entrée | — retenue |
| B — `/student-signup?…school_public_id=…` directement | Rien à coder | Adresse longue (QR dense) ; sans l'entrée, numéro et code redemandés |
| C — un jeton d'établissement dédié, révocable | Révocable | Une colonne, une migration, une rotation : pour une donnée déjà publique |

## 4. Décision

> **Nous exposons `GET /e/:school_public_id` (public, 60 par minute et par adresse IP). Un établissement actif est gardé en session (30 minutes, à côté de l'entrée élève), puis l'inscription s'ouvre, après la confirmation du code, l'établissement préchoisi. Un identifiant inconnu, inactif ou en brouillon donne la même redirection vers `/student`, sans rien garder. Un connecté est renvoyé à son accueil. Le QR de l'accueil élève encode cette adresse, en URL absolue.**

## 5. Conséquences

### 🟢 Positives

- Aucun schéma touché ; aucune donnée nouvelle publiée.
- L'élève scanné entre par la porte habituelle et n'a plus qu'à choisir niveau et classe.

### 🔴 Coûts consentis

- L'adresse vit tant que l'identifiant public de l'établissement vit : elle n'est pas révocable seule (un établissement désactivé la rend inerte).
- Une clé de plus dans la session de l'entrée élève (`student_entry_school`).
- L'attribution d'arrivée (ADR-0143) ne distingue pas encore ce QR : l'inscription par cette adresse compte comme « standard ».

## 6. Notes d'implémentation

```ruby
# config/routes/classroom.rb
get "e/:school_public_id", to: "classroom/school_signup_links#show", as: :school_signup_link

# app/controllers/concerns/student_entry_session.rb — une clé de session à part, posée avant l'entrée :
# l'entrée (numéro, code) n'existe pas encore quand le QR est scanné.
SCHOOL_KEY = :student_entry_school # { "public_id" => "…", "at" => epoch }, 30 minutes, comme l'entrée
def keep_entry_school(public_id) … end
def entry_school_public_id … end # nil si expirée
```

L'inscription en mode entrée (`Classroom::StudentRegistrationsController#new`) préchoisit `entry_school_public_id` quand la requête ne porte pas d'établissement ; `start_session` remet la session à zéro à la connexion.

L'établissement actif se lit par une requête existante (`Queries::School::…`) ou, à défaut, une méthode bornée `active_public_id?(public_id)` ; jamais `Orm::` dans le contrôleur.

## 7. Comment vérifier que la décision est respectée

- `test/controllers/classroom/school_signup_links_controller_test.rb` : actif → `/student` et établissement gardé ; inactif, brouillon, inconnu → même réponse, rien gardé ; connecté → accueil ; 61e appel → 429.
- `test/system/…` (CA-10) : du QR au compte créé dans la classe choisie.
- Test de vue de la carte de classe : l'URL du QR est `school_signup_link_url` et ne contient ni jeton de classe ni identifiant d'élève.
