# UDR-0050 : Inviter un collègue, partager sa classe, s'inscrire sans code, valider les comptes en attente, page Croissance

| | |
|---|---|
| **Statut** | Proposé *(défauts appliqués le 2026-09-28, à confirmer par le porteur)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/croissance-parrainage`](../../chantiers/croissance-parrainage/prd.md) — critères CP-01 à CP-18 |
| **ADR lié** | [ADR-0063](../adr/0063-parrainage-demarrage-a-froid-et-mesure-du-k-factor.md) · [ADR-0057](../adr/0057-code-d-etablissement.md) · [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) · amende [UDR-0006](0006-shell-applicatif-par-role.md) (aucune entrée), [UDR-0018](0018-accueil-equipe.md) (raccourci), [UDR-0026](0026-accueil-enseignant.md), [UDR-0025](0025-declaration-des-classes.md), [UDR-0027](0027-page-classe.md), [UDR-0036](0036-gestion-des-etablissements.md), [UDR-0041](0041-page-profil.md), [UDR-0044](0044-inscription-enseignant-par-code-d-etablissement.md) · composants [UDR-0005](0005-design-system-fondateur.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Un enseignant convaincu n'a aucun geste pour faire venir ses collègues ; il recopie à la main un code qu'il n'a d'ailleurs jamais vu. Ses élèves rejoignent sa classe par un code qu'il dicte en salle. Un enseignant dont l'établissement n'a pas reçu son code est bloqué à l'inscription. L'équipe ne voit ni les comptes à valider ni l'effet des invitations.

## 2. Décision

1. **Le partage se fait depuis le téléphone de l'enseignant**, par les canaux qu'il utilise déjà : WhatsApp d'abord (bouton principal), SMS, copier le lien, et le partage natif du système quand il existe. Le message est **prêt**, en français, et ne contient aucune donnée d'élève.
2. **Le bloc « Inviter un collègue » vit sur l'accueil enseignant**, après les sections du shell, et sur une page « Inviter un collègue » atteinte depuis la déclaration des classes. Il montre le compteur de filleuls et, au-delà de 3, le badge Ambassadeur.
3. **Les collègues en attente** de son établissement apparaissent sur l'accueil d'un enseignant actif, avec « Je confirme » : c'est le geste du garant.
4. **Partager la classe** : sur la page d'une classe, sous le code, « Partager sur WhatsApp » avec un message pour le groupe de la classe.
5. **S'inscrire sans code** : un lien discret sous le champ du code d'établissement mène au même formulaire, où le code national ou la recherche DRENA → établissement remplace le code.
6. **Écran d'attente** : l'enseignant en attente lit le nom de son établissement, l'état de sa demande et quoi faire (demander à un collègue de confirmer).
7. **Fiche établissement** : section « Enseignants en attente » (Valider / Refuser, refus confirmé) et code national dans l'en-tête et le formulaire.
8. **Page Croissance** (`/teams/growth`) : lecture seule, période 7 / 30 / 90 jours, k et sa décomposition en tête avec la cible, puis parrains, classement des établissements, demandes en attente. Liée depuis l'accueil équipe ; **aucune entrée de navigation**.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### Bloc « Inviter un collègue » — `identity/referrals/_invite`

**Structure**
- `ui_card id: "invite_colleagues"`, titre « Inviter un collègue », sous-titre « Partagez votre lien : vos collègues de <établissement> s'inscrivent sans chercher le code. », icône `user-plus`.
- Compteur `p#referral_count` : « Aucun collègue inscrit grâce à vous pour l'instant. » / « 1 collègue inscrit grâce à vous » / « N collègues inscrits grâce à vous » (`font-display text-2xl font-extrabold` pour le nombre) ; si ambassadeur, `ui_badge "Ambassadeur"`, `tone: :gold`, icône `trophy`, à côté.
- Lien lisible `a#referral_link` (URL complète, `break-all text-sm text-brand-strong`).
- Rangée `div#referral_share_actions` (`flex flex-wrap gap-3`), sous `data-controller="identity--share"` :
  1. « WhatsApp » : `ui_button` `brand`, icône `chat-bubble-left-right`, `href` = `https://wa.me/?text=<message encodé>`, `target="_blank"`, `rel="noopener"`, `data-action="identity--share#record"`, `data-identity--share-channel-param="whatsapp"` ;
  2. « SMS » : `secondary`, icône `device-phone-mobile`, `href` = `sms:?body=<message encodé>`, `data-action="identity--share#record"`, canal `sms` ;
  3. « Copier le lien » : `secondary`, icône `link`, `data-action="identity--share#copy"`, `aria-label` « Copier votre lien d'invitation » ;
  4. « Partager… » : `secondary`, icône `share`, `hidden`, `data-identity--share-target="native"`, `data-action="identity--share#native"` ; le contrôleur le montre si `navigator.share` existe.
- Deux `<template>` : toast `success` « Lien copié » (`copied`) et `warning` « La copie a échoué. Sélectionnez le lien et copiez-le. » (`failed`).
- Valeurs du contrôleur : `url` = `teacher_referral_shares_path`, `link` = le lien parrainé, `text` = le message.
- Message : « Bonjour ! J'utilise Lnclass avec mes classes à <établissement>. Inscris-toi comme enseignant avec ce lien, l'établissement est déjà rempli : <lien> ».

**Comportement**
- `identity--share#record` : `navigator.sendBeacon(url, FormData{authenticity_token, channel})`, puis laisse le lien s'ouvrir. `#copy` : presse-papiers, toast, puis enregistrement `copy`. `#native` : `navigator.share({ text, url })`, puis `native` ; une annulation n'enregistre rien.
- `POST /teachers/invite/shares` → 204 ; 403 hors policy ; 422 pour un canal inconnu.
- Absent si l'enseignant n'a pas d'établissement actif.

**Accueil enseignant** (`classroom/teacher_homes/show`) : après la grille des sections, dans l'ordre, `_pending_colleagues` (si non vide) puis `_invite`.

**`_pending_colleagues`** : `ui_card id: "pending_colleagues"`, « Collègues en attente », sous-titre « Ils se sont inscrits à <établissement> sans code. Confirmez seulement ceux que vous connaissez. », icône `hand-raised` ; liste `ul` de `li#join_request_<public_id>` : nom, `ui_subject_badge` de la matière, « Demande du <date> » ; `button_to` « Je confirme » (`secondary`, `sm`, icône `check`, `aria-label` « Confirmer que <nom> enseigne à <établissement> ») en `POST join_request_vouch_path(public_id)`. Succès : Turbo Stream `remove` de la ligne (ou de la carte si c'était la dernière) + toast « <nom> est validé(e). Vous êtes son parrain. » ; repli HTML : redirection vers l'accueil.

**Page « Inviter un collègue »** (`GET /teachers/invite`) : `ui_page_header` « Inviter un collègue », puis `_invite`. Sans établissement actif : `ui_empty_state` « L'invitation n'est pas ouverte », « Seul un enseignant d'un établissement actif peut inviter. ».

**Déclaration des classes** (`classroom/teaching_selections/index`) : `ui_page_header` reçoit en action un `ui_button` `secondary` `sm` « Inviter un collègue », icône `user-plus`, vers `teacher_invite_path`.

### Profil — `identity/profiles/show`

- Pour un enseignant ambassadeur, entre les deux cartes : `ui_card id: "profile_ambassador"`, `ui_badge "Ambassadeur"` `gold` `trophy`, texte « N collègues se sont inscrits grâce à vous. Merci ! ».

### Partage de la classe — `classroom/classrooms/_header`

- Dans le bloc du code (si `join_code_display`), sous l'aide : `ui_button` `brand` `sm` « Partager sur WhatsApp », icône `chat-bubble-left-right`, `href` `https://wa.me/?text=<message>`, `target="_blank"`, `rel="noopener"`, `id="classroom_whatsapp_share"`.
- Message : « Rejoignez la classe <classe> (<établissement>) sur Lnclass : <URL /c/code>. Code de la classe : <ABC12>. » Jamais de nom d'élève ni d'effectif.

### Inscription sans code — `identity/pending_teacher_registrations/new`

- Même page que l'inscription (`identity/teacher_registrations/new`, deux colonnes), titre « S'inscrire sans code d'établissement », sous-titre « Votre compte sera validé par l'équipe Lnclass ou par un collègue déjà inscrit. ».
- Formulaire `form#pending-teacher-registration-form` (scope `teacher_registration`, `POST /teacher-signup/without-code`) : mêmes rubriques ; la rubrique « Établissement et matière » contient `ui_field :national_code` (« Code national de l'établissement », `inputmode="numeric"`, `maxlength` 8, aide « 6 chiffres, celui des résultats du BEPC. »), puis `p` « ou » (`text-center text-xs text-mute uppercase`), puis `ui_field :drena_public_id` (select, `data-action="school--drena-schools#load"`) et le frame `schools` de l'UDR-0024 (`school/drena_schools/index`), sous `data-controller="school--drena-schools"`.
- Sur l'inscription par code (`_form`, sans `@preview`), sous le champ du code : lien `a#no-school-code` « Mon établissement n'a pas encore de code Lnclass » (`min-h-tap text-sm text-brand-strong`) vers `new_pending_teacher_registration_path`.
- Erreurs : `national_code` « Établissement introuvable. Vérifiez le code national. » (inconnu, inactif, brouillon) ; « Saisissez le code national ou choisissez votre établissement. » (`base`, rien fourni) ; « Trop de demandes sont en attente pour cet établissement… » (`base`) ; 429 comme l'inscription.
- Succès : session ouverte, redirection vers `pending_account_path` avec le toast « Compte créé. Il sera activé dès qu'il est validé. ».

### Écran d'attente — `identity/pending_accounts/show`

- Cas `:teacher` avec demande `pending` : `ui_empty_state` icône `clock`, titre « Votre demande est en cours de validation », description « Établissement : <nom>. Demandez à un collègue déjà inscrit sur Lnclass de confirmer votre demande depuis son accueil, ou attendez la validation de l'équipe. ».
- Demande `rejected` : icône `no-symbol`, « Votre demande n'a pas été acceptée », « Contactez l'équipe Lnclass si vous pensez qu'il s'agit d'une erreur. ».
- Sans demande : le texte existant. Bouton « Se déconnecter » dans tous les cas.

### Fiche établissement — `teams/schools`

- En-tête (`_header`) : dans la `dl`, `div#school_national_code` « Code national » `<dd font-mono>` si présent.
- Formulaire (`_form`) : `ui_field :national_code`, facultatif, `inputmode="numeric"`, `maxlength` 6, aide « 6 chiffres, facultatif. Sert à l'inscription sans code. ». Erreurs : format « Le code national compte 6 chiffres. », pris « Ce code national est déjà celui d'un autre établissement. ».
- Section `_join_requests` (`section#school_join_requests`, `aria-labelledby`), rendue en tête de la colonne des enseignants, **seulement s'il y a des demandes en attente** : `h2` « Enseignants en attente (N) », puis une ligne `li#join_request_<public_id>` par demande : nom, numéro groupé, matière, « Demande du <date> », `button_to` « Valider » (`primary`, `sm`, `PATCH … decision=approve`) et « Refuser » (`secondary`, `sm`, ouvre `ui_modal` `reject-join-request-<public_id>` : « Refuser la demande de <nom> ? », « Le compte restera bloqué sur l'écran d'attente. », pied Annuler / Refuser la demande).
- `PATCH /teams/schools/:school_public_id/join-requests/:public_id` → redirection 303 vers la fiche avec `notice` « <nom> est rattaché(e) à l'établissement. » / « La demande de <nom> est refusée. » ; déjà traitée → `alert` « Cette demande a déjà été traitée. ».
- Liste des établissements : la recherche « Nom ou sigle » devient « Nom, sigle ou code national ».

### Page Croissance — `teams/growth/show`

**Structure**
- `ui_page_header` « Croissance », sous-titre « Parrainage entre enseignants et arrivée des élèves, sur les <N> derniers jours. ».
- `nav#growth_periods` (`aria-label` « Période ») : trois liens pilule 7 / 30 / 90 jours (`aria-current="page"` sur l'actif, `bg-ink text-white` ; sinon `border border-line bg-white`).
- `section#growth_k` : `ui_card` : « k enseignant », valeur `font-display text-5xl font-extrabold` (une décimale, « — » si nul), puis `p` « = <i> partages par enseignant × <c> % de conversion », puis `ui_badge` de cible (« Cible 0,75 · ambition 2 », `tone: :success` si k ≥ 0,75, `:warning` sinon). Note `text-xs text-mute` : « Cohorte : enseignants inscrits sur la période. Un partage peut toucher tout un groupe : la conversion peut dépasser 100 %. ».
- `ul#growth_metrics` (`grid grid-cols-2 gap-3 lg:grid-cols-3`), une tuile `li` par indicateur (`rounded-ln bg-mist p-4`, nombre `font-display text-3xl`, libellé `text-sm text-mute`) : Partages, Inscriptions enseignants, dont parrainées, Conversion, Cycle viral médian (« N j »), Élèves par enseignant actif.
- Deux colonnes `lg:grid-cols-2` : `ui_card#growth_top_referrers` « Meilleurs parrains » (`ol`, nom, établissement, nombre) ; `ui_card#growth_leaderboard` « Établissements les plus actifs » (`ol`, nom, DRENA, « N enseignants », lien vers la fiche).
- `ui_card#growth_pending` « Demandes en attente (N) » : les 5 plus anciennes (nom de l'établissement → fiche, date).

**Comportement** : lecture seule, navigation Turbo ; réservé à l'équipe (403 sinon). Accueil équipe : raccourci `ui_button` `secondary` « Croissance », icône `arrow-trending-up`, vers `teams_growth_path`, après « Importer ».

**États obligatoires**
- Vide : 0 partout, « — » pour conversion, k et cycle ; « Aucun parrainage sur la période. », « Aucun enseignant actif pour l'instant. », « Aucune demande en attente. ».
- Chargement : sans objet (rendu serveur).
- Erreur : période inconnue → 30 jours.
- Succès : sans objet (lecture).

**Tokens** : composants `ui_*` et tokens `@theme` seulement (`mist`, `gold`, `brand`). Aucun graphique, aucune bibliothèque.

**Accessibilité**
- Chaque tuile se lit nombre puis libellé ; les icônes sont décoratives.
- Les boutons de partage ont un libellé visible ; « Copier le lien » a un `aria-label` qui dit ce qu'il copie.
- Cibles ≥ 48 px ; à 390 px, les boutons de partage et les tuiles passent à la ligne, sans défilement horizontal ; les liens longs se coupent (`break-all`).

## 4. Conséquences

- La navigation équipe reste à 5 destinations ; la page Croissance n'est atteinte que par l'accueil équipe (et l'URL).
- Tout futur partage (annonce, fiche) reprend `identity--share` et la règle : lien réel, enregistrement par `sendBeacon`, message sans donnée d'élève.
- La fiche établissement a désormais une section qui n'apparaît qu'en présence de demandes.
