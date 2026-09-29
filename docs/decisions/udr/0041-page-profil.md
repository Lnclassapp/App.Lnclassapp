# UDR-0041 : Page profil — mes informations, puis nom, numéro et PIN modifiables en modale

| | |
|---|---|
| **Statut** | Accepté |
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
