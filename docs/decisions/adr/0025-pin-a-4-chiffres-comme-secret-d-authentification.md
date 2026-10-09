# ADR-0025 : PIN à 4 chiffres comme secret d'authentification, sous conditions
<!-- index
titre: PIN à 4 chiffres comme secret d'authentification, sous conditions
statut: Accepté — *complété par [0050](./0050-authentification-et-session.md), [0031](./0031-second-facteur-totp-pour-l-equipe.md), [0038](./0038-comptes-de-l-equipe-et-sous-roles.md), [0032](./0032-recuperation-assistee-du-pin.md)*
problematique: Conserver le code à 4 chiffres pour ne pas barrer l'accès des élèves, **à la condition stricte** de six compensations indissociables : limitation de tentatives, verrouillage progressif, validation serveur, aucune dérivation depuis le contact, second facteur sur les rôles privilégiés, parcours de récupération.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-18 |
| **Chantier** | `docs/chantiers/refonte-application` |
| **Remplace** | — |
| **Remplacé par** | — |
| **Complété par** | [ADR-0050](./0050-authentification-et-session.md) (comp. 1 à 4), [ADR-0031](./0031-second-facteur-totp-pour-l-equipe.md) et [ADR-0038](./0038-comptes-de-l-equipe-et-sous-roles.md) (comp. 5), [ADR-0032](./0032-recuperation-assistee-du-pin.md) (comp. 6) |

---

> ⚠️ **Décision complétée — les six compensations ont leur ADR.**
> Le 2026-09-25, les compensations 1 à 4 sont précisées par l'[ADR-0050](./0050-authentification-et-session.md), la compensation 5 par l'[ADR-0031](./0031-second-facteur-totp-pour-l-equipe.md) et l'[ADR-0038](./0038-comptes-de-l-equipe-et-sous-roles.md), la compensation 6 par l'[ADR-0032](./0032-recuperation-assistee-du-pin.md). Le PIN à 4 chiffres et ses six conditions restent en vigueur.

## 1. Contexte et problématique

Depuis l'[ADR-0002](./0002-authentification-native-contact-telephonique-sans-devise.md), **le numéro de téléphone est l'identifiant de connexion** de Lnclass. Il n'y a ni adresse e-mail, ni pseudonyme, ni identifiant alternatif — choix justifié par le contexte ivoirien, où l'adresse e-mail n'est pas un acquis chez les élèves du secondaire.

Le secret associé est un **code PIN à 4 chiffres**. L'application actuelle l'impose par trois attributs HTML — `maxlength="4"`, `pattern="\d{4}"`, `inputmode="numeric"` — et **rien côté serveur**.

La combinaison mesurée dans l'application actuelle est indéfendable en l'état :

| Fait constaté | Conséquence |
|---|---|
| L'identifiant est un numéro de téléphone | public, et fortement structuré : 10 chiffres, préfixes `01`, `05`, `07` |
| Le secret fait 4 chiffres | 10 000 combinaisons |
| Aucune limitation de tentatives — `grep -rn "rate_limit" app/controllers/` ne retourne rien | un compte tombe en quelques minutes, une classe en une nuit |
| Aucune validation serveur | un POST direct accepte n'importe quoi, y compris une chaîne vide |
| Sur le parcours `/c/<code>`, un champ vide donne `password = contact` | le secret devient l'identifiant public |

La question n'est donc pas « 4 chiffres est-il un bon secret ? » — il ne l'est pas. La question est : **qu'est-ce qui rend ce choix acceptable, compte tenu de ce qu'il achète ?**

## 2. Moteurs de décision

Par ordre d'importance :

- **L'accès effectif des élèves.** La cible est un élève du secondaire ivoirien, sur téléphone d'entrée de gamme, souvent en partage de connexion. Un mot de passe complexe saisi sur un clavier de téléphone est une barrière réelle à l'inscription, et une barrière à l'inscription est une barrière à l'apprentissage.
- **Le PIN est un geste connu.** Le code à 4 chiffres est le geste de l'argent mobile, universellement pratiqué en Côte d'Ivoire. Il ne s'apprend pas.
- **Aucune donnée financière n'est en jeu.** Le compte donne accès à des exercices et à des résultats scolaires. La gravité d'une compromission est réelle mais bornée — ce qui ne vaut **pas** pour les rôles privilégiés, voir §4.
- **Les numéros sont des données de mineurs.** Le contenu est peu sensible ; l'annuaire ne l'est pas.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| **A — Mot de passe classique** (8+ caractères, complexité) | Le standard, sans discussion possible | Barrière d'adoption sur la cible principale. Et sans parcours de récupération fiable, un mot de passe complexe oublié coûte plus de comptes perdus qu'il n'en protège |
| **B — Code à usage unique par SMS** | Pas de secret à mémoriser | Coût par message, dépendance à un opérateur, échec en zone de couverture faible. Un élève sans crédit ne se connecte plus |
| **C — PIN à 6 chiffres** | 1 000 000 de combinaisons au lieu de 10 000 | Gain réel, mais le geste n'est plus celui de l'argent mobile. À reconsidérer si les compensations du §4 s'avèrent insuffisantes |
| **D — PIN à 4 chiffres, compensé** ✅ | Le geste déjà connu, la barrière d'adoption la plus basse | Retenue — **à la condition stricte du §4** |

## 4. Décision

> **Nous conservons le code PIN à 4 chiffres comme secret d'authentification, et nous tenons les six compensations ci-dessous pour indissociables de cette décision.**

Un PIN à 4 chiffres **sans** ces compensations n'est pas une variante dégradée de cette décision : c'est une décision différente, que cet ADR ne couvre pas.

| # | Compensation | Pourquoi elle est nécessaire |
|---|---|---|
| 1 | **`rate_limit` sur l'authentification** (natif Rails 8) | Sans elle, 10 000 combinaisons tombent mécaniquement. C'est la compensation qui porte tout le reste |
| 2 | **Verrouillage progressif** après échecs répétés, et journalisation de chaque échec | Transforme une attaque de quelques minutes en attaque de plusieurs jours, et la rend visible |
| 3 | **Validation serveur** du format — exactement 4 chiffres | Aujourd'hui la contrainte n'existe que dans le navigateur |
| 4 | **Aucune dérivation depuis l'identifiant.** Un champ vide est une erreur de validation | Corrige `password = contact`, qui rendait le secret public |
| 5 | **Second facteur pour les rôles privilégiés** (`team`) | Un PIN à 4 chiffres ne protège pas un compte capable de supprimer tous les utilisateurs. La gravité bornée du §2 ne vaut que pour l'élève |
| 6 | **Parcours de récupération** | L'application actuelle n'en a aucun : un PIN oublié y est un compte perdu définitivement. Un secret court est oublié plus souvent, pas moins |

## 5. Conséquences

### 🟢 Positives

- **La barrière d'inscription reste basse** pour la cible qui compte : l'élève, sur son téléphone, sans e-mail.
- **Le geste est déjà su.** Aucune pédagogie à faire, aucun abandon au moment de choisir un mot de passe.
- **La journalisation des échecs (compensation 2) crée le premier journal d'audit du projet** — l'application actuelle n'en a aucun, ni sur les connexions, ni sur les changements de mot de passe, ni sur les suppressions de compte.

### 🔴 Coûts consentis

- **Le secret reste faible dans l'absolu.** 10 000 combinaisons, avec un identifiant public et structuré. La sécurité du compte repose entièrement sur les compensations, pas sur le secret lui-même. **Si l'une d'elles saute, la décision devient indéfendable** — et c'est la raison d'être de cet ADR : rendre ce lien impossible à oublier.
- **Le partage de PIN entre élèves sera courant.** Un code à 4 chiffres se dit à voix haute. Toute fonctionnalité où l'identité de l'élève engage une note ou un classement doit en tenir compte.
- **La compensation 5 crée deux parcours d'authentification** — élève/enseignant d'un côté, `team` de l'autre. Complexité assumée : le compte `team` est celui qui peut détruire la plateforme.
- **Cette décision est réversible et devra être réexaminée.** Si les journaux de la compensation 2 montrent des tentatives systématiques, l'option C (PIN à 6 chiffres) est le repli désigné.

## 6. Notes d'implémentation

### Limitation de tentatives — Rails 8 natif

```ruby
# app/controllers/identity/sessions_controller.rb
class Identity::SessionsController < ApplicationController
  # ADR-0025 : un PIN de 10 000 combinaisons n'est tenable que limité.
  rate_limit to: 5, within: 1.minute,
             only: :create,
             with: -> { redirect_to login_path, alert: t(".too_many_attempts") }
end
```

### Validation serveur du format

La validation appartient au domaine, pas au formulaire :

```ruby
# app/domain/dtos/identity/credentials_input.rb
validates :pin, format: { with: /\A\d{4}\z/, message: :must_be_four_digits }
```

Et **jamais** de dérivation depuis l'identifiant : un `pin` vide est une erreur, pas un défaut silencieux.

### Formulaires

`password_field`, jamais `text_field`. Quatre des cinq formulaires d'inscription de l'application actuelle affichent le PIN en clair à l'écran — inacceptable sur un poste partagé ou en salle de classe.

## 7. Comment vérifier que la décision est respectée

| Ce qu'on vérifie | Comment | Où ça bloque |
|---|---|---|
| La limitation de tentatives existe et mord | test d'intégration : la 6ᵉ tentative en une minute est refusée | CI |
| Le format est validé côté serveur | test de DTO : `"abc"`, `""`, `"12345"` sont invalides | CI |
| Le PIN n'est jamais dérivé du contact | test système : champ vide ⇒ erreur de validation, aucun compte créé | CI |
| Le PIN n'est jamais affiché en clair | test système : le champ est de type `password` sur tous les formulaires | CI |
| Le second facteur couvre les rôles privilégiés | test : une connexion `team` sans second facteur est refusée | CI |
| Le parcours de récupération fonctionne | test système bout en bout | CI |

Les six compensations ont chacune leur test. **C'est la seule façon de garantir qu'aucune ne disparaîtra silencieusement** — et la disparition silencieuse d'un garde-fou est exactement ce qui s'est produit dans l'application précédente, où `core.hooksPath` n'avait jamais été positionné et où aucun hook ne s'était donc jamais exécuté.
