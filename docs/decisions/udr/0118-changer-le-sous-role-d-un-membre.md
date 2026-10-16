# UDR-0118 : « Changer le rôle » d'un membre de l'équipe, en modale depuis la fiche du compte, et des aides de sous-rôle qui disent vrai
<!-- index
titre: Changer le sous-rôle d'un membre depuis la fiche du compte
statut: Proposé
adr-lie: [0100](../adr/0100-matrice-des-sous-roles-de-l-equipe-par-capacite.md)
problematique: Aucun écran ne change un sous-rôle ; un admin le fait dans une modale ouverte depuis « Débloquer un compte », jamais sur lui-même ; les aides des trois sous-rôles (invitation et modale) décrivent la matrice de l'ADR-0100. Amende UDR-0020
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/sous-roles-equipe`](../../chantiers/sous-roles-equipe/memo.md) |
| **ADR lié** | [ADR-0100](../adr/0100-matrice-des-sous-roles-de-l-equipe-par-capacite.md) §4.3 |
| **Amende** | [UDR-0020](0020-debloquer-un-compte.md) (fiche du compte : une action de plus) |
| **Remplacé par** | — |

---

## 1. Contexte

Un membre invité avec le mauvais sous-rôle le garde : il faut passer par la console. Avec l'ADR-0100, un mauvais sous-rôle coûte un accès réel (ou en donne un de trop). L'admin a besoin de le corriger en quelques secondes, depuis l'écran où il retrouve déjà un membre par son numéro pour réinitialiser son second facteur. Par ailleurs, l'aide du sous-rôle « Contenu » dans l'invitation (« Cours, fiches essentielles, exercices et référentiel ») oublie le blog et les illustrations, celle du « Terrain » oublie la direction et le Pilotage nominatif.

## 2. Décision

- **Modale depuis la fiche du compte**, comme « Réinitialiser le second facteur » : pas de page « Membres de l'équipe » (`annuaire-equipe`, hors périmètre).
- **Trois cases radio avec leur aide**, le sous-rôle actuel coché : le même composant que l'invitation, partagé, pour que l'aide soit écrite une seule fois.
- **Pas de confirmation en deux temps** : le geste est réversible par un autre admin, et journalisé.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**

- Route : `get "members/:user_public_id/team-role/edit"` et `patch "members/:user_public_id/team-role"` dans `namespace :teams` → `Teams::MemberTeamRolesController#edit` / `#update` ; noms `edit_teams_member_team_role` et `teams_member_team_role`.
- Partial partagé `app/views/teams/shared/_team_role_fields.html.erb` (`locals: (form:, selected:, error:)`) : le `fieldset` de radios de `teams/invitations/new.html.erb` (lignes « Rôle dans l'équipe ») en est extrait ; l'invitation et la modale le rendent.
- Fiche du compte (`teams/account_lookups/_result.html.erb`) : quand `account.role == :team`, `!account.own_account` et `can_manage_team`, un bouton secondaire « Changer le rôle » (`icon: "arrow-path-rounded-square"`, `id: "change-team-role-button"`, `data: { turbo_frame: "modal" }`) vers `edit_teams_member_team_role_path(account.public_id)`, placé avant « Réinitialiser le second facteur ».
- `edit.html.erb` : `ui_modal` taille `:sm`, titre « Changer le rôle de %{name} », intro « Le nouveau rôle vaut dès sa prochaine page. », `form_with model: @form, url: teams_member_team_role_path, method: :patch`, le partial de radios, pied « Annuler » (secondaire, `modal#close`) et « Enregistrer » (primaire, `id: "team-role-submit"`).

**Libellés et aides (`config/locales/teams/invitations.fr.yml` → clés partagées `teams.team_roles.*`)**

| Sous-rôle | Libellé | Aide |
|---|---|---|
| `admin` | Administration | « Tout l'espace équipe, dont inviter un membre, changer un rôle, débloquer un second facteur et les jobs. » |
| `content` | Contenu | « Cours, fiches, exercices, référentiel, blog et illustrations d'annonce. Pas de données personnelles. » |
| `field` | Terrain | « DRENA, établissements, classes, direction, enseignants en attente, déblocage des comptes. » |

Le profil (`identity/profiles/_information`) et la fiche du compte gardent leurs libellés courts, lus à la même source.

**Comportement**

- Succès (Turbo Stream) : la modale se ferme, toast succès « Rôle de %{name} changé : %{team_role}. », la fiche (`account_lookup` frame) est remplacée par sa version à jour. Repli HTML : redirection 303 vers `teams_account_lookup_path(contact: …)` avec `notice`.
- `:invalid` : 422, la modale reste ouverte, erreur sous le fieldset « Choisissez le rôle de la personne. » (`aria-describedby`).
- `:conflict` (dernier admin) : 422, la modale reste ouverte, message d'erreur de base « L'équipe doit garder au moins un administrateur. » en tête du formulaire.
- `:forbidden` : 403 (toast en Turbo Stream) ; `:not_found` : 404.
- La réponse `edit` n'affiche aucun secret : pas de `secret_response`.

**Tokens** : composants existants (`ui_modal`, `ui_button`, radios `accent-brand`, `text-error`) ; aucune valeur en dur.

**États obligatoires**

- *Vide* : sans objet (trois choix fixes).
- *Chargement* : bouton « Enregistrer » désactivé pendant l'envoi (`data-turbo-submits-with`).
- *Erreur* : 422 décrits ci-dessus.
- *Succès* : toast et fiche à jour.

**Accessibilité**

- `fieldset` + `legend` « Rôle dans l'équipe » ; chaque radio a son `label` qui englobe libellé et aide ; cible ≥ 48 px.
- Focus initial sur la case cochée ; Échap ferme la modale ; le focus revient sur « Changer le rôle ».
- Toast annoncé par la région `aria-live` existante.

**Captures exigées** : fiche d'un membre « Contenu » vue par un admin (bouton visible), modale ouverte, erreur « dernier administrateur », fiche de son propre compte (bouton absent) ; à 390 px et sur ordinateur.

## 4. Conséquences

- Le partial des radios devient la seule description des sous-rôles : toute évolution de la matrice (ADR-0100) met à jour ses aides dans le même lot.
- `annuaire-equipe`, s'il est repris, réutilise la modale telle quelle depuis sa liste.
