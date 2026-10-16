# UDR-0095 : Page « Comptes » de l'équipe — une recherche, deux filtres, une liste qui mène à la fiche
<!-- index
titre: Page « Comptes » de l'équipe : recherche, filtres rôle et état, liste paginée
statut: Proposé
adr-lie: [0093](../adr/0093-desactivation-d-un-compte-et-anonymisation-des-adultes.md), [0062](../adr/0062-indicateurs-de-pilotage-lus-en-direct.md)
problematique: Remplacer « Débloquer un compte » (numéro entier, un résultat) et la recherche de Pilotage (élèves et enseignants) par une seule page qui trouve tout compte et mène à sa fiche.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | `docs/chantiers/annuaire-equipe` |
| **ADR lié** | ADR-0093 |
| **Remplace** | UDR-0020 §recherche (à l'acceptation) · UDR-0049 §7 `_search` (si Q4 est acceptée) |
| **Remplacé par** | — |

---

## 1. Contexte

Au téléphone avec un parent, l'équipe doit retrouver un compte en quelques secondes. Aujourd'hui elle a deux recherches : « Débloquer un compte » n'accepte qu'un numéro entier et ne rend qu'un compte ; Pilotage accepte un nom ou 4 chiffres, mais ignore la direction et l'équipe et ne mène nulle part. Un membre de l'équipe qui n'a que le nom d'un enseignant ne peut pas lui émettre de code PIN.

## 2. Décision

- **Une page, une barre** : `/teams/accounts` garde son URL et devient « Comptes ». Le terme est un nom (2 caractères au moins) ou un numéro (4 chiffres au moins, Q3), comme dans Pilotage aujourd'hui : on réutilise `AccountSearchQuery`, étendue aux quatre rôles.
- **Deux filtres en listes** : rôle (Tous, Élève, Enseignant, Direction, Équipe) et état (Actifs, Désactivés, Tous). Défaut : tous les rôles, comptes actifs. Pas de filtre établissement (Q6).
- **Liste plutôt que tableau** : à 390 px, une ligne par compte lisible sans défilement horizontal ; toute la ligne est le lien vers la fiche.
- **Frame et URL qui avance**, comme Pilotage et la liste des établissements : un lien partagé ou un rechargement retrouve la même liste.
- **Pilotage** perd sa carte de recherche au profit d'un lien vers cette page (Q4).

## 3. Règles d'implémentation

**Structure** — `app/views/teams/accounts/index.html.erb`

1. `page_title t(".page_title")` (« Comptes ») ; `ui_page_header title: t(".title")` (« Comptes »), sous-titre « Retrouvez un élève, un enseignant, une direction ou un membre de l'équipe. », `back:` vers `team_home_path`.
2. `_filters` : `form_with url: teams_accounts_path, method: :get, id: "accounts-filters"`, `html: { role: "search", "aria-label": t(".search_label") }`, `data: { controller: "search", turbo_frame: "accounts", turbo_action: "advance" }`, classes `mb-6 grid items-end gap-3 rounded-card border border-line bg-white p-4 shadow-card sm:grid-cols-2 lg:grid-cols-4` (même gabarit que `teams/schools/_filters`).
   - `search_field_tag :q` (`id: "accounts_q"`, `sm:col-span-2`), icône `magnifying-glass`, label « Nom ou numéro », aide `p#accounts_q_hint` « 2 caractères au moins, 4 chiffres pour un numéro. », `aria-describedby`, `autocomplete: "off"`, `data-action: "input->search#queue"`, `data-autofocus-target: "field"`.
   - `select_tag :role` et `select_tag :state`, `data-action: "change->search#submit"`, chevron `chevron-down`.
   - `ui_button` « Rechercher » (`funnel`, `data-search-target: "button"`) et « Effacer » (`variant: :ghost`, `href: teams_accounts_path`, `data-turbo-frame: "_top"`).
   - `<template data-search-target="error">` avec `ui_error_state`.
3. `turbo_frame_tag "accounts"`, classes `block transition-opacity aria-busy:pointer-events-none aria-busy:opacity-50`, `data-turbo-action: "advance"`, qui rend `_results`.
4. `_results` (partial seul renvoyé quand `turbo_frame_request_id == "accounts"`) :
   - `p#accounts_total.mb-2.text-sm.text-mute` `aria-live="polite"` : « 1 compte » / « 37 comptes » ;
   - `ul#accounts.divide-y.divide-line.rounded-card.border.border-line.bg-white` ;
   - `li#account_<public_id>` contenant un seul `link_to teams_account_path(public_id)`, `data-turbo-frame: "_top"`, classes `flex min-h-tap items-center gap-3 px-4 py-3 hover:bg-brand-soft focus-visible:outline-2` :
     `ui_avatar` (`size: :sm`, photo si présente) · bloc `min-w-0 flex-1` : nom `truncate text-sm font-medium text-ink`, `ui_role_badge size: :sm`, `ui_badge "Désactivé", tone: :warning, dot: true` si désactivé ; ligne `text-xs text-mute` : rattachement (élève « Établissement · Classe », enseignant « Établissement · N classes », direction « Établissement », équipe sous-rôle) et numéro masqué en `font-mono` · `ui_icon "chevron-right"` `text-mute`.
   - `ui_pagination page:, pages:` sous la liste.

**Tokens** — UDR-0005 seulement : `text-ink`, `text-mute`, `border-line`, `bg-white`, `bg-brand-soft`, `rounded-card`, `shadow-card`, `min-h-tap`. Badge « Désactivé » : `tone: :warning`. Aucune couleur en dur.

**Comportement**

- Contrôleur `Teams::AccountsController#index` ; `ReadUserPolicy` sans cible ; `AccountSearchQuery#call(term:, role:, state:, page:)`.
- Valeurs de filtre inconnues : ignorées (retour au défaut), jamais d'erreur (règle de Pilotage).
- Le terme est gardé dans le champ après la réponse ; la page entière rend aussi les résultats (sans JavaScript, lien partagé).
- Pilotage (Q4) : `teams/dashboards/_search` et `_search_results` sont supprimés ; à leur place `ui_card` « Chercher un compte » (icône `magnifying-glass`) avec `ui_button` « Ouvrir Comptes » vers `teams_accounts_path`. `Teams::DashboardsController` ne lit plus `q` ni `page`.
- Accueil : `teams/homes/_shortcuts`, le bouton « Débloquer un compte » (`lock-open`) devient « Comptes » (`users`), même `href`.

**États obligatoires**

- **Sans terme** : la liste des comptes actifs n'est **pas** affichée ; `ui_empty_state` « Cherchez un compte », description « Tapez un nom ou un numéro. », icône `magnifying-glass`.
- **Terme trop court** : `p.text-sm.text-mute role="status"` « Tapez au moins 2 caractères, ou 4 chiffres pour un numéro. »
- **Aucun résultat** : `ui_empty_state` « Aucun compte trouvé », description « Essayez un nom plus court ou le numéro complet. »
- **Chargement** : le frame s'estompe (`aria-busy`).
- **Erreur réseau** : le `ui_error_state` du template, avec « Réessayer ».
- **Succès** : total puis liste.

**Accessibilité**

- Chaque ligne est un seul lien, cible ≥ 48 px de haut (`min-h-tap`), focus visible ; nom accessible = nom, rôle, état (le badge est du texte).
- Le total est annoncé (`aria-live="polite"`) ; ordre de tabulation : champ, filtres, boutons, lignes, pagination.
- À 390 px : filtres empilés, une colonne ; aucune barre de défilement horizontale.

## 4. Conséquences

- L'UDR-0020 ne décrit plus la page `/teams/accounts` : sa recherche par numéro entier disparaît ; ses actions passent sur la fiche (UDR-0096).
- L'UDR-0049 perd sa section de recherche (si Q4) ; ses tests de recherche migrent vers ceux de cette page.
- Interdit désormais : une seconde recherche de comptes ailleurs dans l'espace équipe ; un tableau à colonnes pour cette liste.
