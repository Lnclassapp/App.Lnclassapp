# UDR-0097 : Modales de gestion d'un compte — modifier, désactiver, réactiver, anonymiser
<!-- index
titre: Modales de la fiche d'un compte : modifier (nom, genre, numéro), désactiver, réactiver, anonymiser avec le nom tapé
statut: Proposé
adr-lie: [0093](../adr/0093-desactivation-d-un-compte-et-anonymisation-des-adultes.md), [0036](../adr/0036-suppression-archivage-et-anonymisation.md)
problematique: Chaque geste sur un compte s'ouvre dans la modale partagée, dit ce qu'il change avant de le faire, et met la fiche à jour sans rechargement ; l'anonymisation exige de taper le nom.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | `docs/chantiers/annuaire-equipe` |
| **ADR lié** | ADR-0093 |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe agit au téléphone, souvent sur mobile : un geste mal compris (fermer les sessions d'un enseignant en cours, anonymiser le mauvais homonyme) coûte cher. La modale « Supprimer le compte » de l'élève (ADR-0036) existe déjà : elle dit ce qui est effacé et ce qui reste, et demande la date de la demande. Les nouveaux gestes doivent suivre la même forme.

## 2. Décision

- **La modale partagée** (`turbo_frame "modal"`, `ui_modal open: true`), servie à la demande comme les confirmations de la liste des établissements : pas de modale copiée dans la page.
- **Chaque modale dit l'effet avant le bouton** : sessions fermées, connexion refusée, échéance, ce qui est effacé.
- **Taper le nom** pour anonymiser : le seul geste irréversible exige une preuve que la bonne fiche est ouverte (deux « Koné Aya » existent toujours).
- **Succès en Turbo Stream** : la modale se ferme, la fiche se met à jour, un toast confirme. **Erreur** : 422 ou 409 dans la modale, champs gardés.

## 3. Règles d'implémentation

**Structure commune** — `turbo_frame_tag "modal"` > `ui_modal title:, id:, size: :sm, open: true, document_title:` ; pied : `ui_button "Annuler"` (`variant: :secondary`, `data-action: "modal#close"`) puis le bouton d'action (`type: :submit, form: <id du formulaire>`). Erreur générale : bloc `role="alert"` `bg-error-soft text-error` (forme de `teams/account_deletions/new`).

**3.1 Modifier** — `teams/account_edits/edit.html.erb`, `PATCH teams_account_edit_path`

- Titre « Modifier <nom> » ; `form_with model: @form, scope: :account, id: "account-edit-form"`.
- `ui_field :first_name` (« Prénom(s) », `maxlength: 80`), `ui_field :last_name` (« Nom », `maxlength: 50`), `ui_radio_group :gender` (« Féminin », « Masculin » : libellés partagés `genders` de `shared/common.fr.yml`), `ui_field :contact, as: :tel` (« Numéro », `inputmode: "tel"`, aide « 10 chiffres, commence par 01, 05 ou 07. »).
- Sous le numéro, `p.text-sm.text-mute` : « Changer le numéro déconnecte le compte de tous ses appareils. »
- Bouton « Enregistrer » (`check`).
- Rôle et matricule : absents du formulaire, et ignorés s'ils sont envoyés.

**3.2 Désactiver** — `teams/account_deactivations/new.html.erb`, `POST teams_account_deactivation_path`

- Titre « Désactiver <nom> ? » ; liste `ul.list-disc.pl-5.space-y-1.text-sm.text-mute` : « Il est déconnecté de tous ses appareils. » · « Il ne peut plus se connecter. » · adulte : « Sans réactivation, le compte sera anonymisé le <date>. » · élève : « Sa classe et ses résultats sont gardés. » (Q1).
- Bouton « Désactiver » (`variant: :danger`, `no-symbol`).
- Direction (Q2) : le libellé reste « Désactiver », la modale reprend le texte du retrait de l'ADR-0077 (« restaurable 30 jours ») et poste vers la route de retrait existante.

**3.3 Réactiver** — `teams/account_reactivations/new.html.erb`, `POST teams_account_reactivation_path`

- Titre « Réactiver <nom> ? » ; texte « Il pourra se connecter de nouveau avec son PIN. L'anonymisation prévue est annulée. » ; bouton « Réactiver » (`variant: :primary`, `arrow-uturn-left`).

**3.4 Anonymiser** — `teams/account_deletions/new.html.erb` étendue

- Titre « Anonymiser <nom> » ; `p` « Effacé » et « Gardé » adaptés au rôle :
  - élève (existant) : nom, numéro, photo, résultats effacés ; classe gardée en archive ;
  - enseignant : nom, numéro, photo effacés ; retiré de ses classes, devoirs en cours archivés ; annonces et contenus gardés, signés « Compte supprimé » (Q7) ;
  - équipe : nom, numéro, photo, second facteur effacés ; contenus gardés, signés « Compte supprimé ».
- `ui_field :requested_on, as: :date` (existant ; défaut : aujourd'hui, aide « Date de la demande reçue, ou de la décision de l'équipe »).
- **Nouveau** : `ui_field :confirmation_name` (« Tapez <nom> pour confirmer », `autocomplete: "off"`, `spellcheck: false`) ; la comparaison ignore la casse, les accents et les espaces en trop.
- Bouton « Anonymiser définitivement » (`variant: :danger`, `trash`).

**Tokens** — UDR-0005 seulement : `text-mute`, `text-ink`, `bg-error-soft`, `text-error` ; boutons par `ui_button`, champs par `ui_field` / `ui_radio_group`.

**Comportement**

- Chaque modale est un GET servi dans le frame `modal` depuis le menu de la fiche ; sans JavaScript, elle s'ouvre en page pleine et le formulaire redirige vers la fiche.
- Succès : `create`/`update.turbo_stream.erb` → `turbo_stream.update "modal"` (vide), `turbo_stream.replace "account-identity"` et `"account-attachment"`, toast `ui_toast` : « Compte modifié. » · « Compte désactivé. » · « Compte réactivé. » ; anonymisation : redirection vers `teams_accounts_path` avec le toast « Compte anonymisé. » (la fiche n'existe plus).
- Échec : `status: :unprocessable_entity` (formulaire), `:conflict` (dernier admin, déjà désactivé), `:forbidden` ; la modale reste ouverte avec le message.
- Bouton d'action désactivé pendant l'envoi (`data-turbo-submits-with`), contre le double clic.

**États obligatoires**

- **Chargement** : le frame `modal` montre son squelette existant pendant le GET ; le bouton affiche « Envoi… » pendant le POST.
- **Erreur** : messages du PRD §3 (« Ce numéro est déjà utilisé », « C'est le dernier administrateur… », « Le nom ne correspond pas »), liés au champ par `aria-describedby`.
- **Succès** : modale fermée, fiche à jour, toast.
- **Vide** : sans objet.

**Accessibilité**

- `ui_modal` piège le focus, `Échap` ferme, le focus revient au déclencheur du menu.
- Le premier champ (ou le bouton « Annuler » pour une confirmation) reçoit le focus à l'ouverture : jamais le bouton destructif.
- Cibles ≥ 48 px ; à 390 px, boutons du pied en pleine largeur, empilés, « Annuler » en dernier.

## 4. Conséquences

- La modale « Supprimer le compte » de l'élève devient « Anonymiser » pour tous les rôles et gagne le nom tapé.
- Tout geste futur sur un compte suit cette forme : modale à la demande, effet décrit, Turbo Stream sur `#account-identity`.
- Interdit : une confirmation `data-turbo-confirm` du navigateur pour ces gestes ; un bouton destructif focalisé par défaut.
