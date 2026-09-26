# UDR-0020 : Débloquer un compte — recherche par numéro exact, code de récupération dans une modale, second facteur réinitialisé en place

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-26 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot B8, critères ID-15 (émission) et F-07 (réinitialisation) |
| **ADR lié** | [ADR-0028](../adr/0028-policies-de-domaine-par-use-case.md) · [ADR-0031](../adr/0031-second-facteur-totp-pour-l-equipe.md) (TOTP) · [ADR-0032](../adr/0032-recuperation-assistee-du-pin.md) (code de récupération) · [ADR-0050](../adr/0050-authentification-et-session.md) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Dans l'ancienne application, un PIN oublié était un compte perdu : aucun écran ne permettait de le récupérer (ID-15). En V1, deux pertes doivent se réparer sans console :

- **le PIN oublié** d'un élève, d'un enseignant ou d'un membre de l'équipe. L'enseignant ou l'équipe émet un code de 8 chiffres, valable 15 minutes, que la personne saisit sur « PIN oublié » (ADR-0032) ;
- **le téléphone perdu** d'un membre de l'équipe, qui n'a plus son second facteur. Un autre membre le réinitialise (ADR-0031).

Deux frictions sont à éviter :

- le code, montré une seule fois, se perd dans un flash qui disparaît, ou reste dans l'historique du navigateur ;
- l'équipe fouille un annuaire pour trouver le bon compte, et agit sur un homonyme.

## 2. Décision

1. **Un écran « Débloquer un compte »** dans l'espace équipe (`/teams/accounts`). Il sert **une recherche par numéro exact**, normalisé comme à la connexion (« 05 11 22 33 44 », « +225 0511223344 »…). Il n'y a pas d'annuaire ni de recherche partielle : un numéro incomplet ne trouve rien (annuaire en V2).
2. **La recherche vit dans un Turbo Frame** `account_lookup`, qui avance l'URL (`?contact=`) : le retour arrière et le lien partagé retrouvent le compte.
3. **Le résultat est une carte** : avatar, nom, badge de rôle ; la classe active pour un élève ; le rôle dans l'équipe et l'état du second facteur (« Activé », « Non activé ») pour un membre de l'équipe.
4. **« Générer un code de récupération » ouvre une modale**. Elle montre le code en grands chiffres, groupés par quatre, l'heure d'expiration, la consigne de le dicter de vive voix et l'avertissement « ne s'affiche qu'une fois ». Le code n'est **jamais** dans un flash, une URL, un journal ou un cache (`Cache-Control: no-store`).
5. **« Réinitialiser le second facteur »**, pour un autre membre de l'équipe seulement, **demande une confirmation** dans une `<dialog>` : l'action déconnecte partout. Le succès remplace la carte en place, où l'état devient « Non activé ».
6. **Sur son propre compte, aucune action** : la carte porte le badge « Votre compte » et renvoie vers un autre membre de l'équipe. Le serveur refuse de toute façon (403).
7. **L'enseignant** émet un code par la même route (`POST /accounts/<public_id>/pin-recovery-codes`), pour un élève d'une classe active qu'il enseigne. Son bouton appartient à l'écran de la classe (lot D4). La modale du code est la même.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `teams/account_lookups/show` : `ui_page_header` (« Débloquer un compte »), puis `form#account-lookup-form[role=search]` en GET, `data-turbo-frame="account_lookup"` et `data-turbo-action="advance"`. Le formulaire contient un champ `input[type=tel][name=contact]` et « Rechercher ». En dessous, `turbo_frame_tag "account_lookup"`. Quand la requête vient du frame, seul le frame est rendu.
- Le frame contient l'un de ces trois états :
  - l'invitation à saisir un numéro : `ui_empty_state(icon: "phone")` ;
  - `#account-lookup-not-found` : `ui_empty_state(icon: "magnifying-glass")`, qui rappelle le numéro saisi ;
  - le partial `_result`.
- `teams/account_lookups/_result` : `ui_card#account-lookup-result`. En-tête : `ui_avatar(size: :lg)`, le nom, puis `ui_role_badge`. Ensuite une `<dl>` de deux colonnes sur bureau. Enfin, les actions :
  - `form#pin-recovery-code-form` (POST), bouton principal avec l'icône `key` ;
  - pour un membre de l'équipe, `ui_modal(id: "reset-second-factor-modal", size: :sm, trigger:)`. Son pied porte « Annuler » et `form#second-factor-reset-form`, bouton `variant: :danger`.
- `identity/pin_recovery_codes/_code` : `ui_modal(id: "pin-recovery-code-modal", open: true)`. Il affiche :
  - « Pour <nom> » ;
  - un encadré `bg-mist` avec « Code à dicter », `#pin-recovery-code` et `#pin-recovery-code-expiry` (« Valable jusqu'à 14 h 22. ») ;
  - la consigne orale ;
  - l'avertissement `bg-warning-soft`.
  Pied : « Fermer ».

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement.
- Code : `font-mono text-4xl font-extrabold tracking-widest tabular-nums`, sélectionnable d'un geste (`select-all`).
- État du second facteur : `ui_badge(tone: :success)` pour « Activé », `tone: :warning` pour « Non activé ».
- Mention « Votre compte » : `ui_badge(tone: :info)`, et l'encadré d'explication en `bg-info-soft`.

**Comportement**
- Recherche : GET dans le frame, URL avancée ; aucun rechargement de page.
- Code : `create.turbo_stream.erb` ajoute le toast « Code de récupération généré. » et fait `turbo_stream.update "modal"` avec `_code`. Repli HTML : la page `show`, en 201, qui ouvre la même modale sur le shell. Émettre un nouveau code révoque le précédent. Débit : 10 codes par minute et par émetteur (et non par adresse, car une salle des professeurs partage souvent la même adresse IP), 429 en toast.
- Réinitialisation : `create.turbo_stream.erb` ajoute le toast « Second facteur réinitialisé pour <nom>. » et fait `turbo_stream.replace "account-lookup-result"`. Repli HTML : 303 vers `/teams/accounts?contact=<numéro>` avec le même message.
- Refus : 403 (toast « Accès interdit. » en Turbo Stream). Compte inconnu : 404.

**États obligatoires**
- Vide : « Saisissez un numéro ».
- Aucun résultat : « Aucun compte pour ce numéro ».
- Succès : la carte ; la modale du code ; la carte remplacée après la réinitialisation.
- Erreur : toast d'erreur (403, 429).

**Accessibilité**
- Le formulaire est un `role="search"` étiqueté ; l'aide du champ lui est reliée par `aria-describedby`.
- La carte est `aria-live="polite"` : le résultat remplacé est annoncé.
- Le code est relié à son libellé par `aria-labelledby`.
- La confirmation est une `<dialog>` native : piège du focus et Échap.
- Cibles tactiles ≥ 48 px. Sur mobile, les modales sont des feuilles basses et les boutons s'empilent (UDR-0005).

## 4. Conséquences

- Aucun annuaire des comptes en V1 : la recherche ne renvoie qu'un compte, par son numéro exact. La liste des comptes (ID-21) attend la V2.
- Le point d'entrée « Débloquer un compte » de l'accueil équipe ou de la navigation appartient au lot de cet écran. Il pointe vers `teams_account_lookup_path`.
- Le bouton « Générer un code de récupération » de l'enseignant appartient à la page de la classe (lot D4) : un `form_with` en POST vers `account_pin_recovery_codes_path(<public_id de l'élève>)`, sans `data-turbo-frame`. Le stream ouvre la modale du code.
- Le code n'a pas de bouton « Copier », qui demanderait un contrôleur Stimulus ; il est fait pour être dicté.
