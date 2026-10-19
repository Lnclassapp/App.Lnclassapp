# UDR-0096 : Fiche d'un compte — identité, état, rattachement, et un menu « Actions »
<!-- index
titre: Fiche d'un compte pour l'équipe : identité, état et échéance, rattachement, menu « Actions »
statut: Proposé
adr-lie: [0093](../adr/0093-desactivation-d-un-compte-et-anonymisation-des-adultes.md), [0036](../adr/0036-suppression-archivage-et-anonymisation.md), [0077](../adr/0077-inscription-de-la-direction-par-le-code-et-retrait.md)
problematique: Une page par compte, adressée par public_id, qui rassemble ce que l'équipe doit voir au support et tous les gestes sur le compte, sans exposer le PIN ni le second facteur.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | `docs/chantiers/annuaire-equipe` |
| **ADR lié** | ADR-0093 |
| **Remplace** | UDR-0020 §résultat (à l'acceptation) |
| **Remplacé par** | — |

---

## 1. Contexte

La mini-fiche de « Débloquer un compte » n'apparaît qu'après un numéro entier, dans un frame, et ne montre ni l'état, ni l'établissement, ni le numéro. L'ancienne application avait une fiche ouverte à tout connecté, adressée par l'identifiant numérique, qui exposait le contact (ID-22). L'équipe a besoin d'une page stable, liable depuis la liste, où chaque geste est à un clic et où un geste interdit n'apparaît pas.

## 2. Décision

- **Une page pleine**, `/teams/accounts/<public_id>`, pas un frame : elle se partage entre membres de l'équipe et se recharge.
- **Une carte d'identité, une carte de rattachement**, empilées à 390 px, côte à côte (2 colonnes) sur ordinateur.
- **Les gestes dans un menu « Actions »** (`ui_dropdown`) en haut à droite de la carte d'identité, plutôt qu'une rangée de boutons : jusqu'à sept gestes selon le rôle, qui débordaient sur téléphone dans l'UDR-0020. Les gestes destructifs sont en bas du menu, en ton danger.
- **La demande de suppression** garde son bloc et son frame (ADR-0036, amendement 2), sous les cartes.
- **Son propre compte** : la fiche s'affiche sans menu, avec le bandeau existant.

## 3. Règles d'implémentation

**Structure** — `app/views/teams/accounts/show.html.erb` (`Teams::AccountsController#show`, `Queries::Identity::AccountDetailQuery`)

1. `page_title` = nom du compte ; `ui_page_header title: account.display_name`, `back: { label: "Comptes", href: teams_accounts_path }` (le retour garde la recherche si `request.referer` est la liste : `back_or`).
2. `div#account_<public_id>` (cible des Turbo Streams des gestes), grille `grid gap-5 lg:grid-cols-2`.
3. `_identity` — `ui_card id: "account-identity"` :
   - en-tête `flex items-start gap-4` : `ui_avatar size: :lg` (photo si présente) ; nom `font-display text-lg font-extrabold text-ink` ; badges : `ui_role_badge`, sous-rôle pour l'équipe, `ui_badge "Désactivé", tone: :warning, dot: true` si désactivé, `ui_badge "Votre compte", tone: :info` si c'est le sien ;
   - à droite, si au moins un geste est permis : `ui_dropdown label: "Actions", icon: "ellipsis-vertical", id: "account-actions"` (partial `_actions`) ;
   - `dl.mt-5.grid.gap-4.border-t.border-line.pt-4.text-sm.sm:grid-cols-2` : Genre · Numéro (complet, `font-mono`, `ui_copy_button`) · Inscrit le (`l(date, format: :long)`) · État (« Actif », ou « Désactivé le 16 octobre 2026 ») · pour l'équipe : second facteur (badge `success` « Activé » ou `warning` « À configurer », comme l'UDR-0020).
   - **Échéance** (adulte désactivé, Q1) : `p.mt-4.flex.items-start.gap-2.rounded-ln.bg-warning-soft.px-4.py-3.text-sm.text-ink`, icône `clock`, « Sera anonymisé le 15 novembre 2026 s'il n'est pas réactivé. » Élève désactivé : `bg-info-soft`, « Désactivé sans échéance : il garde sa classe et ses résultats. »
4. `_attachment` — `ui_card id: "account-attachment", title: "Rattachement"` :
   - élève : établissement, classe principale de l'année, date d'entrée ; sans classe : « Aucune classe cette année » ;
   - enseignant : établissement principal puis les autres, nombre de classes actives de l'année ;
   - direction : établissement et date d'arrivée ; retirée : badge `warning` « Retirée le … » ;
   - équipe : « Équipe Lnclass » et le sous-rôle.
5. `_actions` (lu par le seul `_identity`) — `ui_dropdown_item`, dans cet ordre, chacun seulement si sa policy réussit :
   1. « Émettre un code de récupération » (`key`) → `account_pin_recovery_codes_path(public_id)`, `method: :post` (parcours existant, UDR-0020) ;
   2. « Réinitialiser le second facteur » (`arrow-path`, équipe seulement) → `<dialog>` existant de l'UDR-0020, déplacé dans la page ;
   3. « Modifier » (`pencil-square`) → `edit_teams_account_path(public_id)`, `frame: "modal"` (UDR-0097) ;
   4. séparateur ;
   5. « Désactiver » (`no-symbol`, `tone: :danger`) ou « Réactiver » (`arrow-uturn-left`) → `new_teams_account_deactivation_path` / `teams_account_reactivation_path`, `frame: "modal"` ; pour une direction : retrait et restauration de l'ADR-0077 (Q2) ;
   6. « Anonymiser » (`trash`, `tone: :danger`, `admin` seul) → `new_teams_account_deletion_path(public_id)`, `frame: "modal"`.
6. Élève et `admin` : le frame `Teams::DeletionRequestsController::BLOCK_FRAME` existant, `src: teams_deletion_request_path(public_id)`, dans `ui_card` sous la grille.
7. Son propre compte : pas de `_actions` ; le bandeau `bg-info-soft` de l'UDR-0020 (« C'est votre compte… ») avec un lien vers `profile_path`.

**Tokens** — UDR-0005 seulement : `text-ink`, `text-mute`, `border-line`, `bg-info-soft`, `bg-warning-soft`, `rounded-ln`, `rounded-card`. Dates par `l(…, format: :long)` (« 16 octobre 2026 »), jamais de format en dur.

**Comportement**

- `ReadUserPolicy` avec la cible ; un `public_id` inconnu ou un compte anonymisé : 404 (page d'erreur de l'application).
- L'identifiant numérique n'apparaît ni dans l'URL ni dans le HTML.
- Après un geste, les Turbo Streams de l'UDR-0097 remplacent `#account-identity` et `#account-attachment`, et ajoutent un toast.
- Le menu se ferme au choix d'une entrée (`dropdown#dismiss`).

**États obligatoires**

- **Vide** : sans objet (une fiche a toujours un compte) ; rattachement vide décrit en texte.
- **Chargement** : le bloc de demande de suppression montre `ui_loading_state variant: :skeleton, lines: 1` (existant).
- **Erreur** : 404 ; l'échec du frame de demande montre `ui_error_state`.
- **Succès** : la fiche à jour et le toast du geste.

**Accessibilité**

- Le déclencheur du menu a un nom accessible « Actions pour <nom> » ; entrées `role="menuitem"`, navigation au clavier (contrôleur `dropdown` existant) ; cible ≥ 48 px.
- `dl` pour les champs ; l'échéance n'est pas portée par la couleur seule (texte et icône).
- À 390 px : cartes empilées, menu aligné à droite (`align: :end`), aucun défilement horizontal ; menu ouvert sur les captures d'écran.

## 4. Conséquences

- L'UDR-0020 n'a plus de page : ses gestes (code PIN, second facteur) vivent dans ce menu, leur parcours inchangé.
- Toute action future sur un compte s'ajoute au menu `_actions`, jamais en bouton isolé.
- Interdit : afficher le PIN, le secret ou les codes du second facteur ; adresser la fiche par l'identifiant numérique.
