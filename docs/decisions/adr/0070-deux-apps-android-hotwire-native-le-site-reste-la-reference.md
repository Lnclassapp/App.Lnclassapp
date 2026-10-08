# ADR-0070 : Deux apps Android en Hotwire Native pour les élèves et les enseignants ; le site reste la référence

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-08)*, amendé le 2026-10-08 (voir en fin de document) |
| **Date** | 2026-09-30 |
| **Chantier** | [`docs/chantiers/app-android`](../../chantiers/app-android/memo.md) |
| **Complète** | [ADR-0009](./0009-stack-frontend-vanilla-css-tailwind-hotwire.md) (rendu serveur Hotwire), [ADR-0051](./0051-navigateurs-supportes-et-budget-de-poids.md) (aucun élève refusé), [ADR-0050](./0050-authentification-et-session.md) (session) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Lnclass n'existe que dans le navigateur. Un élève ou un enseignant qui cherche « Lnclass » sur le Play Store ne trouve rien, n'a pas d'icône sur son téléphone et ne profite d'aucune fonction du téléphone. L'installation depuis le navigateur (PWA) n'est pas branchée : le manifeste est celui du générateur Rails, le service worker est vide, et le chantier `installation-pwa` est au backlog de la V4.

La position sur le mobile a changé trois fois sans jamais entrer dans ce dépôt :

| Date | Document (anciens dépôts) | Position |
|---|---|---|
| 2026-02-26 | `docs/prd_interview_progress.md` (`App.Lnclassapp.Avril-2026`) | PWA seule, pas d'app native au MVP |
| 2026-06-08 | `docs/MOBILE_STRATEGY_TURBO_NATIVE.md` (`App.Lnclassapp.com`, `Bac.Lnclassapp`) | Apps iOS et Android en Turbo Native, Strada, notifications FCM |
| juin 2026 | `docs/01_Product_and_Planning/master_plan/mobile.md` (`App.Lnclassapp-24-sept-2026`) | App « Lnclass » (élèves et parents) et app « Lnclass Teacher » en magasin, établissements en web et PWA |

Aucune ligne de code natif n'a été écrite, et le gabarit PR-FAQ des chantiers cite encore « Strada plutôt que React Native ou Flutter » comme texte d'exemple, sans source. Depuis, Turbo iOS, Turbo Android et Strada ont été remplacés par **Hotwire Native** (2024), et Devise, sur lequel le plan de juin comptait pour la session, n'est plus utilisé (ADR-0002, ADR-0050).

Le public reste celui de l'ADR-0009 : des élèves de 14 ans et plus en Côte d'Ivoire, sur des Android d'entrée de gamme, en 3G ou 4G. Le 2026-09-30, le porteur fixe la stratégie mobile et la passe au grill ([memo du chantier](../../chantiers/app-android/memo.md), 15 questions). Le chantier est ensuite **mis en attente** : cet ADR fixe la décision pour qu'elle ne se perde pas une quatrième fois.

## 2. Moteurs de décision

Par ordre d'importance :

1. **Aucun élève n'est exclu** par son téléphone (ADR-0051) : l'app ne peut rien retirer au site.
2. **Un seul code d'écran** : chaque écran s'écrit une fois, en HTML servi par Rails (ADR-0009), sans API à construire ni à maintenir.
3. Être présent là où le public cherche une application : le Play Store, sur Android.
4. Une équipe réduite : pas de Mac, pas de développeur mobile dédié ; la coque doit rester mince.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — PWA seule (position de février) | Aucun code natif, aucune publication | Pas de présence sur le Play Store ; installation peu comprise du public ; le porteur la place au backlog (V4) |
| B — React Native ou Flutter | Interface pleinement native | Exige une API complète, contraire à l'ADR-0009, et une seconde base de code d'écrans |
| C — Conteneur Trusted Web Activity | Publie la PWA sur le Play Store sans code natif | Suppose la PWA d'abord (au backlog) ; aucune navigation ni fonction native |
| **D — Hotwire Native Android, deux apps** | Réutilise les pages existantes ; coque Kotlin mince ; onglets et fonctions natifs possibles | **Retenue** — voir coûts consentis |
| E — Hotwire Native, une seule app pour les deux rôles | Une publication, une coque | Écartée par le porteur (grill, question 1) : chaque public a sa fiche et son icône |
| F — Android et iOS ensemble | Couvre tous les téléphones | iOS exige un Mac et Xcode ; le public est sur Android ; reporté |

## 4. Décision

> **Nous publions deux applications Android construites avec Hotwire Native : « Lnclass » pour les élèves et « Lnclass Teacher » pour les enseignants.** Elles affichent les pages du site dans une coque native (barre d'onglets, écran de démarrage).
>
> **Le site reste la référence et le repli complet.** Aucune fonction n'est réservée à l'app. Un téléphone trop ancien pour l'app garde tout sur le site, sous les règles de l'ADR-0051.
>
> **La direction d'établissement et l'équipe restent sur la web app responsive.** Leurs apps et leurs notifications feront l'objet d'un chantier de suivi.
>
> **La PWA (`installation-pwa`, V4) et l'app iOS restent au backlog.**

Règles qui en découlent (grill du 2026-09-30) :

| # | Règle |
|---|---|
| R1 | Chaque app n'accepte que son rôle. Un compte d'un autre rôle est refusé **après** un PIN correct, jamais avant, avec un message qui nomme la bonne app (lien vers sa fiche Play Store) ; direction et équipe sont renvoyées vers le site. Ce refus est un **aiguillage**, pas une barrière de sécurité : les autorisations restent celles des policies (ADR-0028), identiques dans l'app et sur le site. |
| R2 | L'inscription se fait dans l'app de son rôle. Les liens s'ouvrent dans l'app installée, sinon dans le navigateur : liens et code de classe → app élèves ; inscription enseignant et code d'établissement → app enseignants ; invitations de direction et d'équipe → navigateur. |
| R3 | Chaque session retient l'app d'où elle a été ouverte (`web`, `android_student`, `android_teacher`), pour les indicateurs d'usage de l'équipe et de la direction. |
| R4 | Les durées de session de l'ADR-0050 ne changent pas dans l'app. |
| R5 | L'app élèves se déclare pour un public de 13 ans et plus ; la politique « Familles » du Play Store ne s'applique pas. |
| R6 | Les deux apps sont publiées depuis un compte Google Play **d'organisation** au nom de la société Lnclass, qui détient leurs clés de signature. |
| R7 | Aucun paiement dans l'app. Si un accès payant revient, la facturation de Google Play est étudiée avant, par ADR. |

Les notifications poussées ne font **pas** partie de cette décision : elles relèvent du chantier `notifications-push`, qui aura son propre ADR (service d'envoi externe, table des appareils, amendement de l'ADR-0045). Le grill en a déjà fixé les règles (questions 5 à 11 du memo).

## 5. Conséquences

### 🟢 Positives

- Lnclass apparaît sur le Play Store avec deux fiches, une par public.
- Une modification d'écran côté site apparaît dans les deux apps **sans nouvelle publication**.
- Aucune API ni second code d'écrans : la règle de l'ADR-0009 tient.
- Aucun élève n'est exclu : la règle de l'ADR-0051 tient, le site garde tout.
- Les indicateurs d'usage mesurent enfin la part de l'app par rapport au site.

### 🔴 Coûts consentis

- **Deux coques à publier et à maintenir** : deux identifiants d'application, deux fiches, deux cycles de validation Google. Une modification de coque (onglets, icône, liens déclarés) exige une nouvelle version sur le Play Store.
- **Une version minimale d'Android plus haute que celle du site.** Hotwire Native Android et la vue web système exigent un Android plus récent que les Android 6 accueillis par l'ADR-0051 (version exacte à mesurer à la reprise). Une partie du public cible ne verra pas l'app sur le Play Store.
- **Une compétence nouvelle** : Kotlin, Android Studio, Gradle, signature d'application, console Google Play. Rien de cela n'est testé par la CI actuelle.
- **Un numéro D-U-N-S** à obtenir pour le compte d'organisation, avec un délai variable : il conditionne la date de publication.
- **L'identification de l'app se falsifie** : elle repose sur un en-tête que n'importe quel client peut imiter. D'où R1 : le refus par rôle n'est qu'un aiguillage.
- **Une nouvelle colonne sur les sessions** (R3), et deux amendements pour afficher l'usage : l'ADR-0062 (pilotage de l'équipe) et l'ADR-0065 (espace direction).
- Pas d'iPhone : un enseignant équipé d'un iPhone reste sur le site.

## 6. Notes d'implémentation

À réaliser à la reprise du chantier, après la phase 2 complète (PRD, UDR des écrans d'app, amendements). Rien n'est livré par cet ADR.

**Point d'accroche existant.** Le contrôleur parent porte déjà la détection des navigateurs (ADR-0051) ; la détection de l'app s'y ajoute au même endroit :

```ruby
# app/controllers/application_controller.rb (état actuel)
class ApplicationController < ActionController::Base
  include Authentication
  include RendersResult
  include SecretResponse

  # ADR-0051 : Tailwind v4 floor, never blocking — an old browser gets the page and a banner.
  SUPPORTED_BROWSERS = { chrome: 111, safari: 16.4, firefox: 128, ie: false }.freeze
  allow_browser versions: SUPPORTED_BROWSERS, block: -> { @outdated_browser = true }
end
```

- **Détection** : turbo-rails expose `hotwire_native_app?` (User-Agent contenant « Hotwire Native ») ; chaque coque ajoute un préfixe propre à son User-Agent pour distinguer l'app élèves de l'app enseignants. Nom exact de l'aide et de l'option de préfixe à vérifier sur les versions installées à la reprise (turbo-rails 2.0.23 dans `Gemfile.lock` au 2026-09-30).
- **Layout** : dans l'app, l'en-tête et la barre basse du shell (UDR-0006) sont masqués, la coque affichant ses onglets natifs.
- **Configuration des chemins** : chaque app lit une configuration servie par le site (modales, onglets), versionnée avec le code Rails.
- **Liens ouverts dans l'app (R2)** : le site publie `/.well-known/assetlinks.json` avec les deux identifiants d'application et les empreintes de leurs certificats. Chaque app déclare ses chemins : l'app élèves `/c/`, `/join` (`config/routes/classroom.rb`) ; l'app enseignants `/teacher-signup`, `/e/` (`config/routes/identity.rb`). `/invitations/` n'est déclaré par aucune app.
- **Session (R3)** : la table `sessions` (ADR-0050) enregistre déjà `user_agent`, brut et tronqué à 255 caractères ; elle reçoit en plus une colonne d'origine fermée (`web`, `android_student`, `android_teacher`, `CHECK` en base, ADR-0027), fixée à la création de la session. Les indicateurs lisent cette colonne, jamais le User-Agent brut.
- **Refus par rôle (R1)** : la règle appartient au contexte `identity`. Le contrôleur de session passe déjà `user_agent` au use case d'authentification (`Identity::SessionsController#form_input`) ; il lui passe en plus l'app détectée. Le use case vérifie le PIN, **puis** compare le rôle du compte à l'app, et refuse **sans ouvrir de session** si l'un ne correspond pas à l'autre. Un PIN faux suit le chemin d'échec actuel, identique pour tous les rôles.

## 7. Comment vérifier que la décision est respectée

À écrire avec le chantier, dans ses lots :

- Test unitaire du use case d'authentification : un enseignant avec un PIN correct, depuis l'app élèves, est refusé et **aucune session n'est créée** ; le même enseignant avec un PIN faux reçoit exactement l'échec d'un élève avec un PIN faux (aucune fuite du rôle).
- Test d'intégration de connexion avec le User-Agent de chaque app : un élève entre dans l'app élèves ; un enseignant y est refusé avec le message qui nomme « Lnclass Teacher ».
- Test d'intégration : une session ouverte depuis chaque app enregistre la bonne origine ; une session du navigateur enregistre `web`.
- Test d'intégration : `/.well-known/assetlinks.json` répond 200, en JSON, avec les deux identifiants d'application.
- Test système : une page vue avec le User-Agent de l'app ne rend ni l'en-tête ni la barre basse du shell ; vue dans le navigateur, elle les rend.
- La règle « aucune fonction réservée à l'app » **ne se vérifie pas automatiquement** : elle se contrôle à la revue de chaque chantier qui touche aux apps, et tiendra mal si personne ne la rappelle.

## Amendement du 2026-10-07 — la PWA passe avant les apps Android

*Chantier [`docs/chantiers/installation-pwa`](../../chantiers/installation-pwa/memo.md), décision du porteur du 2026-10-07. Le texte ci-dessus reste tel qu'écrit ; en cas d'écart, cette section fait foi.*

- La phrase « La PWA (`installation-pwa`, V4) et l'app iOS restent au backlog » ne vaut plus pour la PWA : le site devient installable par l'[ADR-0082](./0082-application-installable-sans-page-de-compte-sur-le-telephone.md). L'app iOS reste au backlog, et les apps Android restent en attente.
- Les exercices hors ligne, voulus par le porteur, ouvrent le chantier `eleve-hors-ligne`. S'il garde des données sur le téléphone, la question se reposera pour les apps Android, qui affichent les mêmes pages.

## Amendement du 2026-10-08 — l'app élèves d'abord, compte personnel, barres natives

*Chantier [`docs/chantiers/app-android`](../../chantiers/app-android/memo.md), reprise du 2026-10-08, décisions du porteur. Le texte ci-dessus reste tel qu'écrit ; en cas d'écart, cette section fait foi.*

- **Ordre** : « Lnclass » (élèves) est construite et publiée d'abord. « Lnclass Teacher » suit, dans une seconde étape du chantier. Jusque-là, R1 ne vise que l'app élèves : un compte enseignant, direction ou équipe y est refusé après un PIN correct. Le message renvoie l'enseignant vers le site, puisque l'app enseignants n'existe pas encore.
- **R6 remplacée** : la société Lnclass n'est pas encore créée. Les apps sont publiées depuis un **compte Google Play personnel**. Conséquences :
  - un test fermé d'au moins 12 testeurs pendant 14 jours d'affilée est imposé avant toute publication ouverte ;
  - pas de numéro D-U-N-S possible avant la création de la société ;
  - à sa création, le compte passe en compte d'organisation (D-U-N-S, site vérifié), sans transfert d'app ;
  - les clés de signature restent gérées par Play App Signing ; une clé de secours est gardée par le porteur, jamais dans le dépôt.
- **Barres natives confirmées** : dans l'app, l'en-tête et la barre basse du site sont masqués (§6, « Layout »). La coque affiche une barre d'onglets Android en bas (Accueil, Cours, Ma classe, comme la barre du site) et une barre native en haut. Sur le site, l'en-tête élève devient celui décidé le 2026-10-08 : avatar à gauche ouvrant un panneau latéral, aide et thème à droite, sans logo. Ce qu'affiche la barre native du haut (titre, avatar, aide) est fixé par l'UDR du chantier.
- **R7 confirmée** : aucun paiement dans l'app.
- **Version minimale** : Android 7 ; les téléphones plus anciens restent sur le site.
