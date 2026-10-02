# UDR-0041 : Page profil — mes informations, puis nom, numéro et PIN modifiables en modale

| | |
|---|---|
| **Statut** | Accepté — *amendée le 2026-10-02 (proposé) par le chantier `interface-epuree`* |
| **Date** | 2026-09-27 |
| **Chantier** | [`docs/chantiers/profil-utilisateur`](../../chantiers/profil-utilisateur/prd.md) — critères PR-01 à PR-07 |
| **ADR lié** | [ADR-0055](../adr/0055-profil-modification-de-soi-et-revocation-des-sessions.md) · [ADR-0025](../adr/0025-pin-a-4-chiffres-comme-secret-d-authentification.md) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) |
| **Remplacé par** | — |

---

## 1. Contexte

« Mon profil » est grisé dans le menu du compte des quatre rôles. Un élève ou un enseignant qui a fait une faute dans son nom à l'inscription la garde ; un PIN ne se change qu'en le perdant. Le public utilise surtout un téléphone d'entrée de gamme, parfois partagé.

## 2. Décision

Une page unique, dans le shell du rôle, avec une carte « Mes informations » en lecture et trois actions. Chaque modification se fait dans une modale (règle CRUD Hotwire de l'UDR-0006) ; aucune écriture ne recharge la page, sauf le changement de numéro ou de PIN, qui renouvelle la session et recharge donc la page d'arrivée (ADR-0049).

## 3. Règles d'implémentation

- **Route et shell** : `GET /profile` (`profile_path`), `layout "shell"` du rôle, `content_for :nav_key` inutile (page du menu du compte). L'entrée « Mon profil » du menu du compte devient un lien actif (`aria-current="page"` sur la page).
- **En-tête** : `ui_page_header` titre « Mon profil », sous-titre « Ce que Lnclass sait de vous, et ce que vous pouvez changer. ».
- **Carte `#profile_information`** (`ui_card`, `aria-labelledby`) : `ui_avatar` (initiales), puis une liste `dl` :
  - « Nom » : prénom et nom ; bouton « Modifier » (`secondary`, `sm`, icône `pencil-square`, `data-turbo-frame="modal"`) ;
  - « Numéro » : groupé par deux chiffres ; bouton « Changer mon numéro » (même style, icône `phone`) ;
  - selon le rôle : « Classe » (élève, classe principale ; « Aucune classe » sinon), « Établissement » et « Matière » (enseignant), « Rôle » et « Second facteur : actif » (équipe) ;
  - « Inscrit le » : date longue en français.
- **Carte `#profile_security`** : texte « Votre PIN protège votre compte. Changez-le si vous pensez qu'une autre personne le connaît. », bouton « Changer mon PIN » (`primary`, icône `key`, `data-turbo-frame="modal"`).
- **Modales** (`ui_modal` dans `turbo_frame_tag "modal"`, taille `sm`) :
  - « Modifier mon nom » : `ui_field` nom (50 max), prénom (80 max), autocomplétion `family-name`, `given-name` ; bouton « Enregistrer ».
  - « Changer mon numéro » : PIN actuel (`inputmode="numeric"`, `autocomplete="current-password"`, 4 chiffres), nouveau numéro (`inputmode="tel"`, `autocomplete="tel"`), confirmation ; bouton « Changer mon numéro ».
  - « Changer mon PIN » : PIN actuel, nouveau PIN (`autocomplete="new-password"`), confirmation ; bouton « Changer mon PIN ».
- **États** :
  - Vide : sans objet (un compte a toujours un nom et un numéro) ; champ facultatif absent → « — ».
  - Chargement : bouton de soumission en `loading` pendant l'envoi (`aria-busy`).
  - Erreur : 422 dans la modale ; erreurs sous les champs (`id="<champ>_error"`, `aria-describedby`) ; alerte `role="alert"` pour « PIN incorrect. » et « Ce numéro ne peut pas être utilisé. » ; les champs PIN sont toujours vidés, les autres conservés.
  - Succès :
    - nom : `update.turbo_stream.erb` remplace `#profile_information`, ferme la modale, toast « Votre nom est enregistré. » ;
    - numéro et PIN : redirection (303) vers `profile_path` avec toast « Votre numéro est changé. » ou « Votre PIN est changé. » ; la session renouvelée recharge la page (ADR-0049). Repli HTML identique pour le nom.
- **Accessibilité** : cibles ≥ 48 px (`min-h-tap`), focus visible, libellés visibles sur chaque champ, `aria-live` des toasts existant. Aucune valeur de couleur en dur : tokens et composants `ui_*` seulement.
- **Vocabulaire** : « PIN », « numéro », « Mon profil » ; jamais « mot de passe » ni « identifiant ».

## 4. Conséquences

- L'entrée « Mon profil » du menu du compte n'est plus jamais inactive ; le test des accueils de chaque rôle (`role_homes_test.rb`) l'attend active.
- Aucune autre page ne modifie le compte de l'utilisateur ; l'équipe garde le déblocage (UDR-0020) pour les comptes des autres.

## Amendement du 2026-09-28 — profil de la direction

*Chantier [`docs/chantiers/espace-direction-simple`](../../chantiers/espace-direction-simple/prd.md). Statut : `Proposé`. Contrat : [UDR-0052](0052-espace-direction-simple.md) §3.*

- Pour `school_admin`, le badge « En attente » disparaît ; la carte « Mes informations » affiche une ligne « Établissement » avec son nom, comme pour l'enseignant.

## Amendement du 2026-10-02 — épuration (UDR-0057) · Statut : Proposé

*Chantier [`docs/chantiers/interface-epuree`](../../chantiers/interface-epuree/memo.md) — grill Q3, Q4 ; [plan](../../chantiers/interface-epuree/plan.md), Lot F. Règle : [UDR-0057](0057-ecrans-eleve-epures.md). Photo : [UDR-0047](0047-photo-de-profil.md). Cet amendement ne vise que le profil **tel que l'élève le voit** (`profile.role == :student`, `current_actor.student?`). Une fois accepté, il fait foi pour l'élève en cas d'écart avec le texte ci-dessus.*

### Aujourd'hui, pour l'élève

`GET /profile`, dans le shell élève. De haut en bas :

- le retour « Accueil » ;
- le `h1` « Mon profil » et le sous-titre « Ce que Lnclass sait de vous, et ce que vous pouvez changer. » ;
- la carte « Mes informations » :
  - un bloc d'identité : l'avatar (56 px), le nom en grand, le badge de rôle « Élève » ;
  - « Photo » : « Votre photo remplace vos initiales. » ou « Aucune photo : vos initiales s'affichent. », puis « Changer ma photo » ou « Ajouter une photo » ;
  - « Nom » : le nom, puis « Modifier » ;
  - « Numéro » : le numéro groupé, puis « Changer mon numéro » ;
  - « Classe » : la classe principale, ou « Aucune classe » ;
  - « Inscrit le » : la date longue ;
- la carte « Mon PIN » : le texte « Votre PIN protège votre compte. Changez-le si vous pensez qu'une autre personne le connaît. », puis « Changer mon PIN » (`primary`).

Ce qui charge l'écran :

- **Le nom est dit deux fois** dans la même carte : sous l'avatar et dans la ligne « Nom » (R6).
- **La présence d'une photo est dite trois fois** : par l'avatar, par la phrase de la ligne « Photo » et par le libellé du bouton (R6). La phrase est une explication permanente (R4).
- **Le badge « Élève » redit le rôle** que l'en-tête du shell affiche déjà, à partir de 640 px (R6).
- **Deux textes d'aide restent affichés en permanence** : le sous-titre de la page et le texte de la carte « Mon PIN » (R4).

### Ce qui change, pour l'élève

| Élément | Aujourd'hui | Après | Règle | Où va l'information |
|---|---|---|---|---|
| Sous-titre « Ce que Lnclass sait de vous, et ce que vous pouvez changer. » | sous le `h1` | retiré | R4 | Le titre « Mon profil » et les boutons « Modifier » et « Changer … » le disent. |
| Bloc d'identité en tête de la carte « Mes informations » | avatar 56 px, nom en grand, badge « Élève » | retiré | R6 | L'avatar passe dans la ligne « Photo ». Le nom reste dans la ligne « Nom ». Le rôle reste dans l'en-tête du shell. |
| Valeur de la ligne « Photo » | phrase « Votre photo remplace vos initiales. » ou « Aucune photo : vos initiales s'affichent. » | l'avatar lui-même (`ui_avatar`, `lg`) ; la phrase passe en `sr-only` | R4, R6 | L'avatar montre la photo ou les initiales. Le bouton dit « Ajouter » ou « Changer ». Les lecteurs d'écran gardent la phrase. |
| Texte de la carte « Mon PIN » | paragraphe permanent sous le titre | `ui_info_tip` à côté du titre « Mon PIN » | R4 | Infobulle « Aide : Mon PIN », même texte. |
| Lignes « Nom », « Numéro », « Classe », « Inscrit le » et leurs boutons | — | inchangées | — | — |
| Retour « Accueil », `h1` « Mon profil », bouton « Changer mon PIN » (`primary`), modales | — | inchangés | — | — |

Aucune information ne quitte l'application. Aucun libellé n'est créé ni supprimé : les clés existantes servent telles quelles.

### Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement. Toute branche porte sur l'élève seul ; les autres rôles gardent le rendu actuel, octet pour octet.

**`app/views/identity/profiles/show.html.erb`**

- `ui_page_header` reçoit `subtitle: (t(".subtitle") unless current_actor.student?)`. Le titre et le retour ne changent pas.
- Carte `#profile_security`, pour l'élève :
  - un `div.flex.flex-wrap.items-center.gap-x-1` contient le `h2#profile_security_title` (classes inchangées), puis `ui_info_tip t(".security_body"), label: t(".security_title")` ;
  - le paragraphe `t(".security_body")` n'est pas rendu ;
  - le bouton « Changer mon PIN » ne change pas (`primary`, icône `key`, `data-turbo-frame="modal"`).
- Les autres rôles gardent le `h2`, le paragraphe et le bouton actuels.
- La carte « Ambassadeur » (enseignant) ne change pas.

**`app/views/identity/profiles/_information.html.erb`**

- La branche se lit sur `profile.role == :student`, jamais sur `current_actor` : la vue `profile_names/update` re-rend ce partial par Turbo Stream.
- Le `h2#profile_information_title` « Mes informations » reste.
- Pour l'élève, le bloc d'identité (avatar, nom, badge de rôle) n'est pas rendu. La `dl` garde ses classes (`mt-5 divide-y divide-line border-t border-line text-sm`).
- Ligne « Photo », pour l'élève :
  - `dt` « Photo », inchangé ;
  - `dd.mt-1.5` contient :
    - un `span[aria-hidden="true"]` qui enveloppe `ui_avatar profile.display_name, src: account_photo_src(profile.public_id, profile.photo_version), size: :lg` ;
    - un `span.sr-only` : `t(".photo_present")` ou `t(".photo_absent")`, selon `profile.photo_version` ;
  - le bouton « Ajouter une photo » ou « Changer ma photo » ne change pas (`secondary`, `sm`, icône `camera`, `data-turbo-frame="modal"`).
- Lignes « Nom », « Numéro », « Classe », « Inscrit le » : inchangées.
- Les clés `photo_present` et `photo_absent` vivent dans `config/locales/identity/profile_photos.fr.yml`. Elles ne changent pas.

**Tokens** : aucun token nouveau. Aucun `#hex`, aucun `style=`, aucune valeur entre crochets, aucun `dark:`.

**États** : inchangés (§3 ci-dessus). Après « Modifier mon nom », le Turbo Stream remplace `#profile_information` par le partial épuré. Après un changement de photo, la ligne « Photo » montre la nouvelle photo dans l'avatar.

**Accessibilité**

- Un seul `h1` : « Mon profil ».
- L'avatar de la ligne « Photo » est masqué aux lecteurs d'écran. La phrase `sr-only` dit s'il y a une photo. Le nom n'est donc lu qu'une fois, dans la ligne « Nom ».
- L'infobulle annonce « Aide : Mon PIN ». Sa cible fait 48 px (`size-tap`).
- Cibles ≥ 48 px, focus visible, libellés visibles : inchangés.

### Contrôle de la règle (UDR-0057), après

| # | Profil de l'élève |
|---|---|
| R1 | Une action `primary` : « Changer mon PIN ». « Ajouter une photo » ou « Changer ma photo », « Modifier » et « Changer mon numéro » sont `secondary`. |
| R2 | À 390 × 844 : le retour, l'en-tête et la grille de deux cartes. 3 blocs. |
| R3 | Aucune liste d'éléments. La `dl` est la fiche des 5 attributs du compte : « Voir plus » ne s'y applique pas. |
| R4 | Aucun texte d'aide permanent. Le texte du PIN est dans une infobulle. |
| R5 | Plus aucun badge coloré pour l'élève. L'avatar garde sa teinte d'identité, la même que dans le shell (UDR-0047) : ce n'est pas un accent. |
| R6 | Le nom est dit une fois. La présence d'une photo est montrée par l'avatar et nommée par le bouton, sans phrase en plus. Le rôle n'est dit que par le shell. |

### Inchangé pour les autres rôles

- **Enseignant** : le sous-titre, le bloc d'identité (avatar, nom, badge « Enseignant »), la phrase de la ligne « Photo », les lignes « Établissement » et « Matière », la carte « Ambassadeur », le paragraphe de la carte « Mon PIN ».
- **Direction** : le même rendu, avec la ligne « Établissement » (amendement du 2026-09-28).
- **Équipe** : le même rendu, avec le badge « Second facteur : actif », la ligne « Rôle » et son sous-rôle.
- Leur tour viendra avec le chantier des autres rôles, sous la même règle (UDR-0057 §4).

### Conséquences

- Les tests qui lisent le profil de l'élève suivent :
  - `test/system/identity/profile_test.rb` (dans la liste du Lot F) ;
  - `test/controllers/identity/profiles_controller_test.rb` attend aujourd'hui un `p` « Votre PIN protège votre compte » dans `#profile_security` ;
  - `test/integration/identity/profile_photo_display_test.rb` attend aujourd'hui le texte exact de la phrase dans un `dd`.
  
  Ces deux derniers fichiers ne sont pas dans la liste du Lot F : le lot le signale à l'orchestrateur avant d'y écrire.
- Un test vérifie que l'enseignant, la direction et l'équipe gardent le sous-titre, le bloc d'identité et le paragraphe du PIN.
