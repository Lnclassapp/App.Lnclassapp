# UDR-0098 : Établissement courant de l'enseignant — choisi dans le panneau du compte, nommé dans l'en-tête, seul visible sur l'accueil, le catalogue, l'assignation et les annonces
<!-- index
titre: Établissement courant de l'enseignant — choisi dans le panneau du compte, nommé dans l'en-tête, seul visible sur l'accueil, le catalogue, l'assignation et les annonces
statut: Accepté *(porteur, 2026-10-16 ; §3.5 amendé le 2026-10-16 : MET-4 ; §3.6 ajouté : MET-8)*
adr-lie: [0094](../adr/0094-enseignant-multi-etablissements-et-etablissement-courant.md)
problematique: Rubrique « Établissement » du panneau du compte (site et `/teachers/menu` de Lnclass Teacher) à partir de deux établissements, un bouton par établissement, le courant coché ; ligne de détail = établissement courant ; accueil, catalogue, cibles d'assignation, activités et annonces bornés à l'établissement courant ; une classe hors établissement courant ne s'ouvre pas (retour à l'accueil, MET-4). Rien ne change pour un enseignant d'un seul établissement. Amende UDR-0082 §3.2, 0077, 0069
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16) — §3.4 et §3.5 amendés le 2026-10-16 (MET-4) ; §3.6 ajouté (MET-8) |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/multi-etablissements-enseignant`](../../chantiers/multi-etablissements-enseignant/prd.md) — critères ME-07 à ME-12 |
| **ADR lié** | [ADR-0094](../adr/0094-enseignant-multi-etablissements-et-etablissement-courant.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Un enseignant de deux établissements a des classes qui portent les mêmes noms (« 6ème 1 » existe dans les deux). S'il les voit ensemble, il assigne un exercice ou publie une annonce dans la mauvaise classe. Il lui faut savoir, sur chaque page, **dans quel établissement il est**, et changer en deux touchers, sur le site comme dans « Lnclass Teacher ».

## 2. Décision

- **Un établissement à la fois**, choisi dans le **panneau du compte** (l'avatar), là où l'enseignant cherche déjà « Mon profil ». Pas de sélecteur dans l'en-tête : à 390 px, la rangée de l'UDR-0082 §3.1 est pleine.
- **Le nom de l'établissement courant** est la ligne de détail du panneau (déjà affichée sous le nom) et la ligne d'établissement de l'accueil. Il suffit de lire l'accueil pour savoir où l'on est.
- **Un bouton par établissement** plutôt qu'une liste déroulante : trois au plus (ADR-0094), une cible tactile chacun, et un formulaire simple qui marche sans JavaScript.
- **Un enseignant d'un seul établissement ne voit aucun changement** : pas de rubrique, pas de lien « Changer ».

## 3. Règles d'implémentation

> Contrat d'exécution. Clés de locale sous `shared.navigation.account_panel.schools` et `classroom.teacher_homes.show`.

### 3.1 Panneau du compte — amende l'UDR-0082 §3.2

Dans `shared/navigation/_account_panel`, pour un enseignant dont `TeacherSchoolsQuery` rend **deux établissements ou plus**, une rubrique entre l'identité et `nav` :

```
section#account_schools[aria-labelledby="account_schools_title"].border-b.border-line.py-3
  h2#account_schools_title.px-3.text-xs.font-bold.uppercase.tracking-wide.text-mute → « Établissement »
  ul.mt-1
    li (un par établissement, le principal d'abord, puis par date de rattachement)
      button_to teacher_current_school_path, method: :patch,
                params: { school_public_id: }, form: { id: "switch-school-<public_id>" }
        → classes du lien du panneau (min-h-tap, w-full, rounded-ln, px-3, focus-visible:outline-brand)
        → ui_icon "check" (courant) ou span.size-5 vide (les autres), text-brand-strong
        → span.min-w-0.flex-1.truncate → nom de l'établissement
        → ui_badge « Principal » (size: :sm, ton neutre) pour l'établissement principal
      le courant : aria-current="true", font-semibold, et le bouton est `disabled` (rien à changer)
```

- Un enseignant **d'un seul établissement** n'a pas cette rubrique.
- **« Mes établissements »** (UDR-0099) est une entrée des liens du panneau de l'enseignant, quel que soit le nombre d'établissements : `NavigationHelper::ACCOUNT_PANELS[:teacher]`, après « Mon profil », icône `building-office-2`, `href: teacher_schools_path`.
- La ligne de détail (`ShellUser#detail`) est le nom de l'**établissement courant**.
- `/teachers/menu` (page du panneau, ouverte en modale par Lnclass Teacher) rend le même contenu.

### 3.2 Changer d'établissement

- `PATCH /teachers/current-school` (`School::CurrentSchoolsController#update`) appelle `School::SwitchCurrentSchool` avec la session courante.
- **Succès** : `303` vers `teacher_home_path`, toast `:success` « Vous êtes dans <nom de l'établissement>. ».
- **Refus** (établissement non rattaché, inconnu) : `303` vers `teacher_home_path`, toast `:error` « Cet établissement ne fait pas partie des vôtres. ». Aucun détail de plus.
- Dans Lnclass Teacher, la redirection vers l'accueil ferme la modale du panneau et remplace l'onglet Accueil (règle de navigation de l'ADR-0086 pour une redirection hors d'une page modale) ; à vérifier sur appareil au Lot A.

### 3.3 Accueil de l'enseignant — amende l'UDR-0077 et l'UDR-0069

- Classes, « Cours » (niveaux enseignés), « Activités » (exercices à suivre) et bulles d'invitation ne lisent que l'**établissement courant**.
- La ligne d'établissement de l'accueil (nom de l'établissement, `text-sm text-mute`) devient, **à partir de deux établissements seulement** :
  `p.flex.items-center.gap-2` → nom de l'établissement courant · `link_to « Changer », teacher_menu_path, class: "min-h-tap inline-flex items-center text-sm font-medium text-brand-strong"`, `aria-label` « Changer d'établissement ». Sur le site, ce lien ouvre le même panneau que l'avatar (déclencheur-lien, UDR-0061).
- Établissement courant **sans classe déclarée** : l'état vide existant de l'accueil (« Sélectionnez vos classes ») s'applique, avec le nom de l'établissement courant.

### 3.4 Autres écrans bornés à l'établissement courant

| Écran | Règle |
|---|---|
| Sélection des classes (`/teachers/classrooms`) | Classes de l'établissement courant, comme aujourd'hui (elle lit déjà `actor.school_id`). Titre de page inchangé, sous-titre = nom de l'établissement courant |
| Catalogue de l'enseignant | Niveaux enseignés **dans l'établissement courant** |
| « Assigner un exercice » | Cibles : classes actives de l'établissement courant |
| Annonces de l'enseignant (écrire) | Classes cochables de l'établissement courant (déjà lu par `actor.school_id`) |
| Annonces reçues, « Mes annonces », encadré du plafond | Celles de l'établissement courant ; une annonce écrite dans un autre établissement n'y existe pas (404). Le plafond de 3 se compte par établissement (ADR-0094 §10) |
| Collègues en attente (accueil) | Ceux de l'établissement courant |
| Inviter un collègue | Deux liens (§3.6, MET-8) : celui de l'établissement **courant**, puis le lien de parrainage |

### 3.5 Une classe hors de l'établissement courant — amendé le 2026-10-16 (MET-4)

Chaque établissement est un espace autonome (ADR-0094 §10) : une classe d'un autre de ses établissements **ne s'ouvre pas** tant que l'enseignant n'y est pas passé, ni sa page, ni son suivi, ni « Assigner », ni ses jours de séance.

- Page (lien partagé, rappel, onglet resté ouvert) : `303` vers l'accueil de l'établissement courant, toast `:error` « Cette classe n'est pas dans l'établissement où vous êtes. Changez d'établissement depuis votre compte. ». Aucun établissement n'est nommé.
- Geste en Turbo Stream (se déclarer, assigner, archiver un devoir) : le même toast, `403`, rien n'est écrit.
- Rien ne bascule tout seul : l'enseignant change d'établissement par le panneau du compte (§3.1), puis rouvre le lien.

*Version d'origine (remplacée) : la page s'ouvrait et nommait l'établissement de la classe.*

### 3.6 « Inviter un collègue » : deux liens — ajouté le 2026-10-16 (MET-8), amende l'UDR-0050

Page `/teachers/invite` (`identity/referrals/show`), dans cet ordre, `div.flex.max-w-3xl.flex-col.gap-6` :

1. **`#invite_colleagues`** (`identity/referrals/_invite`) : `ui_card` titre « Inviter un collègue de <établissement courant> », sous-titre « Partagez ce lien : vos collègues de <établissement> s'inscrivent avec l'établissement déjà rempli. » ; compteur et badge « Ambassadeur » (UDR-0050, inchangés : tous les filleuls) ; « Le lien de votre établissement » `a#referral_link` = `/i/<teacher_schools.invite_token>` ; WhatsApp, SMS, « Copier le lien », partage natif (comptés). Le message nomme l'établissement.
2. **`#invite_others`** (`identity/referrals/_sponsor`) : `ui_card` titre « Inviter un autre collègue », icône `share`, sous-titre « Pour un collègue d'un autre établissement : il choisit le sien en s'inscrivant. » ; « Votre lien de parrainage » `a#sponsor_link` = `/i/<teacher_profiles.referral_token>` ; les mêmes quatre partages, comptés ; message « Bonjour ! J'utilise Lnclass avec mes classes. Inscris-toi comme enseignant avec ce lien, tu choisiras ton établissement : <lien> ». Aucun établissement n'y est nommé.

- La bulle « Inviter » de l'accueil et la carte « Parrainage » de la barre latérale partagent le **lien de l'établissement courant** ; « Plus d'options » mène à la page, qui porte les deux.
- **Inscription par le lien de parrainage** (`/i/<jeton>`, sans compte) : le formulaire standard (DRENA puis établissement), précédé de `p#sponsor-preview` (`bg-brand-soft`, icône `user-plus`) « <Prénom Nom> vous invite sur Lnclass. Choisissez votre DRENA, puis votre établissement. » ; le jeton voyage en champ caché ; sans JavaScript, la DRENA revient sur le lien.
- **Lien de parrainage ouvert par un enseignant connecté** : `ui_empty_state` « Ce lien sert à inscrire un nouveau collègue », « Vous avez déjà un compte : ajoutez un établissement depuis « Mes établissements ». », bouton « Mes établissements ».
- À 390 px : les deux cartes pleine largeur, boutons repliés en lignes ; aucun défilement horizontal.

### États obligatoires

- **Un seul établissement** : aucun élément de cette UDR n'apparaît (test système qui le vérifie).
- **Deux ou trois** : rubrique du panneau, lien « Changer » sur l'accueil.
- **Établissement courant quitté ou retiré** pendant la session : à la page suivante, l'accueil est celui du principal, sans message (ADR-0094 §4.2).
- **Erreur** : toast d'erreur, accueil inchangé.

### Accessibilité

- Chaque bouton d'établissement a un nom accessible « Passer à <nom> » (`aria-label`) ; le courant « <nom>, établissement actuel ».
- Cibles ≥ 48 px (`min-h-tap`) ; focus visible `outline-brand` ; ordre de tabulation : identité, établissements, « Mes établissements », liens, thème, déconnexion.
- Le toast de changement est annoncé (`role="status"`, toasts existants).
- À 390 px, aucun nom d'établissement ne déborde : `truncate`, nom complet dans `title`.

## 4. Conséquences

- Le panneau du compte de l'enseignant gagne une rubrique conditionnelle ; ceux des autres rôles ne changent pas.
- Toute nouvelle lecture de l'enseignant qui liste des classes, des annonces ou des devoirs reçoit l'établissement courant ; une lecture « toutes écoles confondues » est interdite, sans exception (§3.5, MET-4). Un test de non-fuite par écran le garde.
- Les captures du Lot A montrent le panneau et l'accueil à 390 px et sur ordinateur, avec un et deux établissements, et le panneau ouvert dans Lnclass Teacher.
