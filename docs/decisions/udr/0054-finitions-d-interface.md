# UDR-0054 : Finitions d'interface — titre, retour, auto-focus, infobulle, copie, envoi automatique, recherche pendant la frappe

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-29 ; textes d'infobulles validés le 2026-09-29, ouverture au survol ajoutée : voir l'amendement « survol »)* |
| **Date** | 2026-09-29 |
| **Chantier** | [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md) — critères FU-01 à FU-54 |
| **ADR lié** | [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (aucun script en ligne) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (Safari 16.4, 60 Ko de JS) · [ADR-0031](../adr/0031-second-facteur-totp-pour-l-equipe.md) · [ADR-0050](../adr/0050-authentification-et-session.md) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) |
| **Amende** | UDR-0005, 0006, 0009, 0011, 0013, 0015, 0019, 0020, 0021, 0023, 0027, 0028, 0029, 0030, 0032, 0036, 0042, 0044, 0049, 0050, 0052 (section « Amendement du 2026-09-29 » de chacune) |
| **Remplacé par** | — |

---

## 1. Contexte

Sept finitions manquent ou varient d'un écran à l'autre ([audit](../../chantiers/finitions-ux/audit.md) du 2026-09-29) :

- **le titre de l'onglet** a trois formes (« X · Lnclass », « X », « X — Y ») ; 16 modales n'en ont pas ; les trois accueils s'appellent tous « Accueil » ;
- **le retour** a quatre motifs (lien à chevron, fil complet, bouton `arrow-left`, lien texte) ; 16 écrans n'en ont pas ; l'enrôlement du second facteur n'a aucune sortie ; l'équipe, sur la page d'une classe, revient à son accueil au lieu de la fiche de l'établissement ;
- **l'auto-focus** est posé à la main sur 14 formulaires, absent de 12 ; dans une modale sans `autofocus`, le focus tombe sur la croix ; après une erreur, il revient au premier champ et non au champ fautif ;
- **l'aide contextuelle** n'existe que sous forme de `title=` (invisible au toucher) ou de phrases éloignées de ce qu'elles expliquent (« Taux de rendu », « — », « k enseignant ») ;
- **la copie** a deux contrôleurs pour un même geste, et les liens les plus critiques (invitation, montrée une seule fois) ne se copient pas ;
- **l'envoi automatique** n'existe nulle part : la personne tape six chiffres puis cherche le bouton ; les codes de secours ne se téléchargent ni ne s'impriment ;
- **la recherche** attend un clic sur « Filtrer ».

Ces écarts sont les premiers que voit un nouvel utilisateur, surtout au téléphone. Chaque UDR d'écran avait tranché pour elle-même ; il manque une règle commune et des briques qui la portent.

## 2. Décision

1. **Une brique par finition, écrite une fois** (Lot 0 du chantier), puis appliquée écran par écran. Les briques Ruby passent par `ComponentsHelper` (ou un helper dédié) et sont visibles sur `/design` (UDR-0005 §4) ; les briques JavaScript sont des contrôleurs Stimulus enregistrés par motif (ADR-0051), sans script en ligne (ADR-0049).
2. **Titre** : « Page · Espace · Lnclass », composé par un seul helper. L'espace est celui du rôle connecté ; une page publique n'en a pas. Une modale ouverte dans la page change le titre de l'onglet tant qu'elle est ouverte, et le rend à sa fermeture.
3. **Retour** : un seul motif, le lien discret à chevron gauche en tête de page, dont le libellé est le nom de la page d'arrivée. Pourquoi le lien plutôt que le bouton : il est déjà sur huit écrans, il ne concurrence pas les actions de l'en-tête, et il tient sur une ligne à 390 px. Le fil complet de la page cours disparaît. Les destinations de la navigation, les modales et les pages d'erreur n'ont pas de retour.
4. **Pages publiques** : le logo devient un lien vers l'accueil public. Un « Retour » s'ajoute seulement là où il y a un parcours (PIN oublié → connexion).
5. **Auto-focus** : une règle unique, portée par un contrôleur. Dans une modale, le premier champ (jamais la croix) ; dans une confirmation sans champ, « Annuler » ; après une erreur, le premier champ en erreur, partout ; sur une page, seulement si l'écran le demande (formulaires publics à un champ, acceptation d'une invitation, « Débloquer un compte »). Pourquoi pas partout sur les pages : au téléphone, le clavier cache le texte d'accueil des pages publiques.
6. **Infobulle** : un `<details>` natif. Pourquoi pas `popover` : il exige Safari 17, et le plancher est Safari 16.4 (ADR-0051). Pourquoi pas `title=` : invisible au toucher et au clavier. Le texte est rédigé par le chantier et validé par le porteur dans la PR (table « Textes proposés »).
7. **Copier** : un seul contrôleur, `clipboard`, qui remplace `classroom--join-code-copy` et la copie d'`identity--share`. On copie les **liens** (invitation équipe et direction, lien de classe `/c/<code>`, lien de parrainage, lien `/e/<code>`), les codes d'adhésion déjà copiables (classe, établissement) et les **codes de secours**. **Un code fait pour être dicté ne se copie pas** : code de la classe vu par l'élève (UDR-0011), code de récupération du PIN (UDR-0020).
8. **Envoi automatique** : un contrôleur, `autosubmit`, qui envoie le formulaire **une seule fois** quand la valeur d'un champ correspond à un motif. Il sert au code du second facteur (6 chiffres, vérification et enrôlement) et au code de classe de `/join` (5 caractères valides). Le code de secours a **son propre champ**, sans envoi automatique, derrière le lien « J'utilise un code de secours » : un code de secours qui commencerait par six chiffres ne peut plus partir tronqué.
9. **Codes de secours** : « Télécharger », « Copier », « Imprimer », puis la case « Je les ai gardés », obligatoire pour « Continuer ». Pas de téléchargement automatique : il peut être bloqué sans prévenir (iOS), et on ne saurait pas s'il a réussi.
10. **Acceptation d'une invitation** (décision du porteur du 2026-09-29) : le formulaire reste ; le focus est sur « Nom » ; « Créer mon compte » **n'ouvre pas** de session (UDR-0019 §2.4 et ADR-0050 inchangés) : la personne arrive sur « Se connecter » avec **son numéro pré-rempli** et le focus sur le PIN. Le numéro passe par la session Rails (cookie chiffré et signé), jamais par l'URL ni par le flash : une URL finit dans les journaux, l'historique et l'en-tête `Referer`, et tout le flash est rendu en toast. Le PIN n'est jamais pré-rempli.
11. **Recherche pendant la frappe** sur quatre listes : établissements, catalogue, élèves d'une classe (enseignant et direction), « Débloquer un compte ». Le formulaire reste un `GET` qui marche sans JavaScript, visant un Turbo Frame ; le contrôleur `search` l'envoie après 300 ms sans frappe. Pendant la frappe, l'URL est **remplacée** (pas d'historique empilé). Les listes déroulantes de filtre (catalogue, établissements, DRENA du pilotage) partent au changement. « Débloquer un compte » reste une recherche par **numéro entier** : elle part quand le numéro est complet.
12. **Pas d'index de recherche** : les tables cherchées sont petites (établissements : quelques milliers au plus ; cours : quelques centaines ; élèves d'une classe : moins de 100 ; comptes : égalité sur un index unique). Le délai de 300 ms et l'annulation par Turbo de la requête précédente bornent la charge. La mesure avant/après est au PRD §7 ; un index trigramme, s'il devenait nécessaire, passerait par le chantier de caching et un ADR.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Titre de page

**Structure**
- Helper `page_title(page)` dans `app/helpers/page_title_helper.rb` : pose `content_for(:page_title, page)` et **renvoie** le titre complet (« Page · Espace · Lnclass »). Un argument vide lève `ArgumentError` (« page_title : titre vide »).
- Helper `document_title` (même fichier) : `[content_for(:page_title), espace, "Lnclass"].compact_blank.join(" · ")`. `espace` = `t("shared.page_title.spaces.<rôle>")` pour l'acteur connecté (`student` « Élève », `teacher` « Enseignant », `team` « Équipe », `school_admin` « Direction ») ; sans acteur (public, second facteur en cours), aucun espace.
- `layouts/application` : `<title><%= document_title %></title>`, sans toucher à `secret_response_meta_tag` (ADR-0031, `secrets-hors-cache`). Tant que le Lot Z n'est pas passé, une vue qui pose encore `content_for :title` garde son titre tel quel (repli) ; le Lot Z retire le repli.
- **« Page »** est un seul segment, sans séparateur interne (ni « · », ni « — », ni « : ») : le libellé court de l'écran (« Établissements », « Débloquer un compte »), ou le nom de l'objet pour une page d'objet (le `h1` : « 3e A », « Lycée moderne de Cocody »). Exemples : « Accueil · Équipe · Lnclass », « Connexion · Lnclass », « Nouveau niveau · Équipe · Lnclass ».
- Clé de locale : `<vue>.page_title`, sans suffixe « · Lnclass » (le helper l'ajoute). Les suffixes existants sont retirés.
- **Modale** : sa vue appelle `page_title` (titre de la page si elle est ouverte directement par son URL) et passe le résultat à `ui_modal(document_title:)`. Le contrôleur `modal` pose ce titre sur `document.title` à l'ouverture et rend le précédent à la fermeture. Une confirmation rendue dans une page ne change pas le titre (pas de `document_title:`).

**Comportement**
- Une navigation dans un frame (`advance`) ne change pas le titre (acceptable, UDR-0036).

### 3.2 Retour

**Structure**
- Partial `components/_back_link.html.erb`, appelé par `ui_back_link(label, href:)` ou par `ui_page_header(title:, subtitle:, back: { label:, href: })`, qui le rend **au-dessus** du `h1`.
- Balisage : `nav[aria-label="Retour"].mb-4.text-sm` → `a.inline-flex.min-h-tap.items-center.gap-1.5.font-medium.text-mute.transition.hover:text-ink.focus-visible:outline-2.focus-visible:outline-brand` → `ui_icon "chevron-left", variant: :mini, size: :sm` puis le libellé.
- **Libellé** : le nom de la page d'arrivée (« Établissements », « Lycée moderne de Cocody », « Accueil »), sans « Retour à ». Exception : la session d'exercice garde « Quitter la session » (UDR-0022).
- Helper `back_href(default, from:)` : renvoie l'URL de provenance (`request.referer`) si elle est de **même hôte** et que son chemin est exactement `from` (chaîne de requête conservée), sinon `default`. Sert à revenir à une liste filtrée.
- Écrans (cible · libellé) :

| Écran | Rôle | Cible | Libellé |
|---|---|---|---|
| Page cours | tous | `courses_path` | « Cours » (remplace le fil complet) |
| Fiche essentielle | tous | `course_path` | nom du cours |
| Page exercice | tous | `course_essential_path` | nom de la fiche |
| Session d'exercice | élève | `exercise_path` | « Quitter la session » |
| Résultat de session | élève, enseignant | `course_essential_path` | nom de la fiche |
| Page classe | enseignant | `teacher_home_path` | « Accueil » |
| Page classe | équipe | `school_path(<établissement de la classe>)` | nom de l'établissement |
| Cours dans la classe | enseignant | `classroom_path` | nom de la classe |
| Fiche dans la classe | enseignant | `classroom_course_path` | nom du cours |
| Assigner un cours | enseignant | `course_path` | nom du cours |
| Inviter un collègue | enseignant | `teacher_classrooms_path` | « Classes » |
| Profil | tous | accueil du rôle | « Accueil » |
| Fiche établissement | équipe | `back_href(schools_path, from: schools_path)` | « Établissements » |
| Rapport d'import | équipe | `teams_imports_path` | « Imports » (remplace le bouton) |
| Niveaux, séries, matières, DRENA, barème des classes, Croissance, Débloquer un compte | équipe | `team_home_path` | « Accueil » |
| Classe (direction) | direction | `school_admin_classrooms_path` | « Travail des élèves » (remplace le bouton) |
| PIN oublié | public | `new_session_path` | « Se connecter » (remplace le lien texte) |

- **Pages publiques** (`/login`, `/join`, `/c/<code>`, `/teacher-signup`, `/e/<code>`, `/teacher-signup/without-code`, `/invitations/<token>`, PIN oublié) : l'image du logo est enveloppée dans `link_to root_path, aria-label: "Lnclass, accueil"`, cible `min-h-tap`, focus visible.
- **Enrôlement du second facteur** : sous le formulaire, `ui_button "Se déconnecter", href: session_path, method: :delete, variant: :ghost, size: :sm`, comme sur la vérification.

### 3.3 Auto-focus

**Structure**
- Contrôleur `autofocus` (`app/javascript/controllers/autofocus_controller.js`). Cibles : `field` (le champ à viser), `fallback` (le bouton à viser faute de champ). Valeur : `mode` (`"page"` par défaut, ou `"dialog"`).
- `layouts/application` pose `data-controller="autofocus"` sur `<body>`. `components/_modal` pose `data-controller="autofocus" data-autofocus-mode-value="dialog"` sur la `<dialog>`.
- Choix de la cible, dans l'ordre :
  1. le premier `[aria-invalid="true"]` de la portée (posé par `ui_field` et `ui_radio_group`) ;
  2. mode `page` : la cible `field` si l'écran en déclare une, sinon rien ; mode `dialog` : la cible `field`, sinon le premier `input:not([type=hidden]):not([readonly]):not([disabled]), select, textarea, trix-editor` du corps de la modale, sinon la cible `fallback`, sinon le bouton de fermeture du pied (voir « Confirmations » ci-dessous) ;
  3. rien (le navigateur garde son comportement).
- En mode `page`, tout ce qui est dans une `<dialog>` est ignoré.
- Déclenchement : `connect()` en mode `page` (chaque rendu Turbo Drive reconnecte `<body>`, re-rendu 422 compris) ; événement `modal:opened` (émis par le contrôleur `modal` juste après `showModal()`) en mode `dialog`.
- `focus({ preventScroll: false })` ; aucun `select()` du texte.
- **Plus aucun attribut `autofocus`** dans les vues : ils sont remplacés par `data-autofocus-target="field"` (option `autofocus: true` de `ui_field`, qui pose cet attribut).
- Écrans qui déclarent une cible `field` sur une page : connexion (numéro, ou PIN quand le numéro est pré-rempli après une invitation), `/join` (code), vérification du second facteur (code, ou code de secours), acceptation d'une invitation (Nom), « Débloquer un compte » (numéro). Les autres pages publiques (`/c/<code>`, inscriptions, PIN oublié, enrôlement du second facteur) n'en déclarent pas : seul le cas 1 (erreur) s'y applique.
- Confirmations en `<dialog>` (désactiver, supprimer, générer, réinitialiser, régénérer) : le focus va sur « Annuler ». Sans cible `fallback` déclarée, le contrôleur prend le premier élément `[data-action~="modal#close"]` **du pied** de la modale (`components/_modal` marque le pied par `data-autofocus-footer`) ; la croix de l'en-tête, qui porte la même action, n'est jamais retenue. Aucune vue n'a donc à l'écrire.
- Champ fichier (photo, import) : il est visé comme un autre ; le focus n'ouvre pas le sélecteur.

### 3.4 Infobulle

**Structure**
- Helper `ui_info_tip(text, label:)` → partial `components/_info_tip.html.erb` :
  - `details.group.inline-block.align-middle` →
  - `summary.summary-plain.inline-grid.size-tap.cursor-pointer.place-items-center.rounded-full.text-mute.transition.hover:bg-ink/5.hover:text-ink.focus-visible:outline-2.focus-visible:outline-brand` contenant `ui_icon "information-circle", size: :sm` (décorative) et `span.sr-only` « Aide : <label> » ;
  - `div.mt-2.max-w-form.rounded-ln.bg-mist.px-4.py-3.text-left.text-sm.font-normal.text-ink` : le texte.
- Nouvel utilitaire `@utility summary-plain` (`list-style: none` et `::-webkit-details-marker { display: none }`), ajouté à UDR-0005.
- Le panneau est **dans le flux** (pas de position absolue) : il pousse le contenu au lieu de déborder, à 390 px comme au bureau.
- Placement : juste après le libellé expliqué (en-tête de colonne, libellé de tuile, badge). Jamais à la place du libellé.
- Aucun contrôleur : ouverture et fermeture au clic, au toucher, à Entrée et à Espace, par le navigateur.
- Le `title=` du badge « hors génération » (niveaux) est supprimé et remplacé par une infobulle.

**Textes** (validés par le porteur le 2026-09-29 ; clés `shared.info_tips.*` pour les textes communs, sinon dans la locale de l'écran)

| Écran | Élément | Texte proposé |
|---|---|---|
| Travail des élèves, classe (direction) | « Taux de rendu » | « Part des devoirs rendus : devoirs rendus par les élèves ÷ (élèves × devoirs donnés). Un devoir est rendu quand l'élève a terminé au moins un exercice de ce devoir. » |
| idem | « Moyenne » | « Moyenne des scores des exercices rendus par les élèves de la classe. Elle s'affiche à partir de 5 élèves ayant rendu un devoir. » |
| idem | « — » (légende sous le tableau) | « — : pas encore de chiffre (aucun élève, aucun devoir, ou moins de 5 élèves pour une moyenne). » |
| Classe (direction) | « Score moyen » | « Moyenne des scores de l'élève sur les exercices qu'il a rendus dans cette classe. » |
| Pilotage | « Réussite moyenne » | « Moyenne des scores des exercices terminés sur la période. — : aucun exercice terminé. » |
| Pilotage, tableau des DRENA | « Élèves actifs » | « Élèves qui ont commencé au moins un exercice sur la période. » |
| idem | « Établissements actifs » | « Établissements de la DRENA ouverts aux inscriptions (statut actif). Classes, enseignants et élèves se comptent sur leurs seules classes actives de l'année. » |
| Croissance | « k enseignant » | « Nombre moyen d'enseignants inscrits grâce à chaque nouvel enseignant de la période. Au-dessus de 1, chaque enseignant en amène plus d'un. » |
| idem | « Conversion par partage » | « Inscriptions parrainées ÷ partages. Un partage peut toucher un groupe entier : elle peut dépasser 100 %. » |
| idem | « Cycle viral médian » | « Délai médian entre l'inscription d'un parrain et celle de son filleul. » |
| idem | « Élèves arrivés par enseignant actif » | « Élèves entrés dans une classe sur la période, divisés par le nombre d'enseignants actifs. » |
| Niveaux | badge « hors génération » | « Ce niveau n'est pas utilisé pour générer les classes des établissements. » |
| Fiche établissement | « Code d'établissement » | « Code secret à transmettre aux enseignants de l'établissement pour qu'ils s'inscrivent. À ne pas confondre avec le code national, public, à 6 chiffres. » |
| Liste et fiche établissement | badge de statut | « Brouillon : pas encore ouvert aux inscriptions. Actif : les enseignants s'y inscrivent. Désactivé : il n'apparaît plus à l'inscription ni à la création de classe. » |
| Page classe | effectif « 12 / 40 élèves » | « 40 est le nombre maximum d'élèves de la classe. » (le plafond lu, pas « 40 » en dur) |
| Page classe | « Dernier score » | « Score de la dernière session d'exercice terminée par l'élève, en pourcentage de bonnes réponses. » |
| Accueil élève, exercice, résultat | badge Bronze / Argent / Or / Diamant | « Bronze à partir de 50 %, Argent à partir de 70 %, Or à partir de 80 %, Diamant à 100 %. » |
| idem | « Maîtrise » | « Acquis : 70 % et plus. Fragile : de 50 à 69 %. En difficulté : moins de 50 %. » |
| Inscription enseignant | « Code d'établissement » | « Code de 6 caractères donné par votre établissement ou par l'équipe Lnclass. Sans code, inscrivez-vous avec le code national. » |
| Champs de PIN (connexion) | « PIN » | « Code secret de 4 chiffres, choisi à l'inscription. Oublié ? Utilisez « PIN oublié ». » |
| Enrôlement du second facteur | « Application d'authentification » | « Une application qui affiche un code à 6 chiffres renouvelé toutes les 30 secondes, par exemple Google Authenticator ou Microsoft Authenticator. » |

### 3.5 Copier

**Structure**
- Contrôleur `clipboard` (`app/javascript/controllers/clipboard_controller.js`). Valeur : `text` (la valeur exacte à copier, fournie par le serveur). Cibles : `button`, `copied`, `failed` (deux `<template>` contenant chacun un `ui_toast`).
  - `connect()` : retire `hidden` de la cible `button`.
  - `copy()` : `navigator.clipboard.writeText(text)` ; succès → clone du toast `copied` dans `#toasts` (id neuf), puis événement `clipboard:copied` (bouillonnant) ; échec → clone du toast `failed`.
- Helper `ui_copy_button(text, label:, copied:, failed: t("shared.clipboard.failed"), aria_label: nil, variant: :secondary, size: :sm, icon: "clipboard-document")` → `span[data-controller=clipboard]` contenant `ui_button` (`hidden`, `data-clipboard-target="button"`, `data-action="clipboard#copy"`) et les deux templates.
- `identity--share` garde WhatsApp, SMS, partage natif et comptage ; son bouton « Copier le lien » devient un `ui_copy_button`, et le comptage de la copie écoute `clipboard:copied->identity--share#recordCopy`.
- `classroom--join-code-copy` est supprimé.
- Emplacements :

| Écran | Valeur | Bouton | Nom accessible |
|---|---|---|---|
| Modale « Invitation créée » (équipe) | lien `/invitations/<token>` | « Copier le lien » (`link`) | « Copier le lien d'invitation » |
| Modale « Invitation créée » (direction) | idem | idem | idem |
| Page classe | code | « Copier » (existant) | « Copier le code KFM37 » |
| Page classe | `join_classroom_url(code)` | « Copier le lien » (`link`, nouveau) | « Copier le lien de la classe » |
| Fiche établissement | code, lien `/e/<code>` | existants | inchangés |
| Inviter un collègue | lien de parrainage | existant | inchangé |
| Codes de secours | les 10 codes, un par ligne | « Copier » | « Copier les codes de secours » |

- **Jamais** de bouton « Copier » sur : le code de la classe vu par l'élève, le code de récupération du PIN, la clé du second facteur.
- Messages : « Lien copié. », « Code copié. », « Codes copiés. » ; échec « La copie a échoué : sélectionnez le texte et copiez-le à la main. ».

### 3.6 Envoi automatique

**Structure**
- Contrôleur `autosubmit` (`app/javascript/controllers/autosubmit_controller.js`), posé sur le `<form>`. Valeur : `pattern` (expression régulière, sans les barres). Cibles : `input`, `status` (région `aria-live="polite"`, `sr-only`).
  - Sur `input` : valeur débarrassée des espaces ; si elle correspond au motif, n'est pas celle du dernier envoi et qu'aucun envoi n'est en cours → `form.requestSubmit()`, écrit « Envoi du code… » dans `status`.
  - Verrou : posé juste avant `requestSubmit()` et à `turbo:submit-start` (que l'envoi vienne du contrôleur, d'Entrée ou du bouton), levé à `turbo:submit-end`. Un `submit` pendant le verrou est annulé (`preventDefault`).
  - Jamais deux envois automatiques de la même valeur. Après un 422, la page re-rendue vide le champ (comportement actuel) : l'envoi automatique repart à la saisie suivante.
- Le bouton d'envoi **reste** (sans JavaScript, rien ne change).
- L'aide du champ annonce le geste : « Le code est envoyé dès le 6ᵉ chiffre. » (second facteur) ; « La classe s'ouvre dès le code complet. » (`/join`).
- **Vérification du second facteur** (`identity/second_factors/new`) :
  - Par défaut, champ `code` : `inputmode="numeric"`, `autocomplete="one-time-code"`, `maxlength="6"`, `pattern="\d{6}"`, motif `^\d{6}$`, cible `field` de l'auto-focus.
  - Sous le champ, `link_to "J'utilise un code de secours", new_identity_second_factor_path(backup: 1)`, `data-turbo-action="replace"`.
  - Avec `backup=1` : champ `code` libellé « Code de secours », `inputmode="text"`, `autocomplete="off"`, `autocapitalize="none"`, `maxlength="12"`, **sans** `autosubmit` ; lien « Utiliser le code de l'application » vers `new_identity_second_factor_path`. Un 422 re-rend la même variante (paramètre caché `backup`).
  - Le serveur accepte les deux formes dans le même champ, comme aujourd'hui : rien ne change côté domaine.
- **Enrôlement** (`identity/second_factor_enrollments/new`) : champ `code` 6 chiffres, même contrôleur ; pas de bascule (les codes de secours n'existent pas encore) ; pas de cible `field` (le QR code est à lire d'abord).
- **`/join`** : motif `^[a-hj-np-zA-HJ-NP-Z]{3}[2-9]{2}$` (celui du code d'adhésion), valeur débarrassée des espaces et du tiret.

### 3.7 Codes de secours

**Structure** (`identity/second_factor_enrollments/backup_codes`, déjà rendue hors cache par `SecretResponse` : rien à ajouter ni à retirer)
- Sous la grille des codes, `div.flex.flex-wrap.gap-3.print:hidden` : « Télécharger » (`arrow-down-tray`), « Copier » (`ui_copy_button`), « Imprimer » (`printer`), tous `secondary`, `sm`, `hidden` tant que leur contrôleur n'est pas connecté.
- Contrôleur `download` (`app/javascript/controllers/download_controller.js`). Valeurs : `content` (texte du fichier, rendu par le serveur), `filename` (`lnclass-codes-de-secours.txt`). Actions : `save` (Blob `text/plain;charset=utf-8`, `URL.createObjectURL`, `a[download]` créé et cliqué, puis `revokeObjectURL`, toast « Fichier des codes de secours téléchargé. » cloné depuis un `<template>`) et `print` (`window.print()`).
- Contenu du fichier : « Codes de secours Lnclass », la date, la consigne « Chaque code ne sert qu'une fois. », puis les 10 codes, un par ligne.
- Puis `form#backup-codes-kept-form` en `GET` vers la destination actuelle de « C'est noté » (accueil du rôle) : case `input[type=checkbox][required]#backup_codes_kept` **sans attribut `name`** (rien n'est envoyé), libellé « Je les ai gardés », cible `min-h-tap` ; bouton « Continuer » (`brand`, pleine largeur). Sans la case, le navigateur refuse l'envoi et le dit ; sans JavaScript, c'est pareil.
- Impression : `print:hidden` sur `#toasts`, les boutons et le formulaire ; la carte et la grille restent.

### 3.8 Acceptation d'une invitation

**Structure** (`identity/invitations/show`, puis `identity/sessions/new`)
- Page d'acceptation : aucun champ de numéro (UDR-0019 §2.3 inchangé). « Nom » porte la cible `field` de l'auto-focus ; après un 422, le premier champ en erreur.
- Succès (`Identity::InvitationsController#accept`) : `session[:login_contact] = <numéro du compte créé>` (10 chiffres normalisés), puis 303 vers `new_session_path` avec le toast actuel (UDR-0019 §2.4, amendement 2026-09-28 pour la direction). **Aucune session d'authentification n'est ouverte**, aucun paramètre d'URL n'est ajouté, rien n'est mis dans le flash.
- « Se connecter » (`Identity::SessionsController#new`) : lit **et supprime** `session[:login_contact]` (`session.delete`), à usage unique. S'il est présent et valide (`Entities::Identity::Contact.normalize`), le champ numéro est rendu avec cette valeur, groupée par deux (« 01 00 00 00 09 »), modifiable, et le champ PIN porte la cible `field` de l'auto-focus ; sinon, rendu inchangé (focus sur le numéro).
- Le champ PIN reste vide, `autocomplete="current-password"` ; le numéro `autocomplete="username"`.
- Un rechargement de « Se connecter » perd le pré-remplissage (valeur consommée) : c'est voulu, la valeur ne vit qu'une requête.
- L'encadré `bg-info-soft` de l'équipe (page d'acceptation) est inchangé.

### 3.9 Recherche pendant la frappe

**Structure**
- Contrôleur `search` (`app/javascript/controllers/search_controller.js`), posé sur le `<form>` GET. Valeurs : `delay` (300), `minLength` (2), `digits` (booléen, faux par défaut). Cibles : `button` (le bouton d'envoi).
  - `connect()` : ajoute `hidden` à la cible `button` (le bouton reste pour qui n'a pas de JavaScript).
  - `queue()` (sur `input` du champ texte) : relance un délai de `delay` ms ; à son terme, envoie si la valeur (débarrassée des espaces de bord) est vide ou fait au moins `minLength` caractères. En mode `digits`, envoie seulement si la valeur réduite à ses chiffres compte 10 chiffres, ou 13 commençant par `225`, ou 15 commençant par `00225` (numéro complet, ADR-0050).
  - Envoi pendant la frappe : `data-turbo-action="replace"` posé sur le formulaire le temps de l'envoi ; `submit()` (sur `change` d'une liste) garde `advance`.
  - Turbo annule la requête précédente du même frame : rien à faire.
- Le champ texte est **hors** du frame rechargé (il garde le focus et la saisie). Le frame porte `class="block transition-opacity aria-busy:opacity-50"`.
- Un compteur `aria-live="polite"` dans le frame annonce le résultat (« 12 établissements », « 3 cours », « 2 élèves », « Aucun élève ne correspond »).
- Listes :

| Liste | Formulaire | Frame | Champ texte | Listes déroulantes | Recherche |
|---|---|---|---|---|---|
| Établissements | `form#schools-filters` (existant) | `schools` (existant) | `search` (existant) | DRENA, type, cycle, statut → `change->search#submit` | nom, sigle, code national (existant) |
| Catalogue | `form#courses-filters` | `courses` (existant) | `q` (nouveau, `ui_field as: :search`, « Rechercher un cours ») | niveau, matière → `change->search#submit` | nom du cours, sans casse ni accents |
| Élèves d'une classe (enseignant) | `form#classroom-roster-search`, `role="search"`, `aria-label` « Chercher un élève » | `classroom_roster_list` | `q` | — | nom de l'élève, sans casse ni accents |
| Élèves d'une classe (direction) | `form#student-work-search`, idem | `student_work_students` | `q` | — | nom de l'élève |
| Débloquer un compte | `form#account-lookup-form` (existant) | `account_lookup` (existant) | `contact` (existant), mode `digits`, `minLength` 0 | — | numéro exact (inchangé) |
| Pilotage, filtre DRENA | form existant | aucun (page) | — | DRENA → `change->search#submit` | inchangée |

- Recherche serveur par nom : fragment commun `Queries::Shared::TextSearch` (`translate(lower(col), accentuées, simples) LIKE :pattern`, motif échappé par `sanitize_sql_like`), le même que celui des établissements.
- La recherche des élèves d'une classe n'est proposée que si la classe a au moins un élève ; le formulaire n'apparaît pas sur une classe vide.
- Dans un frame de résultats, tout lien ou formulaire qui ne doit pas recharger le frame porte `data-turbo-frame="_top"` : « Voir le résultat » (existant), et le formulaire « Générer un code de récupération » de la liste des élèves, dont la réponse Turbo Stream ouvre la modale du code et dont le repli HTML est une page entière.

**États obligatoires** (recherche)
- Vide : aucun résultat → `ui_empty_state(icon: "magnifying-glass")` : « Aucun établissement ne correspond » (existant), « Aucun cours ne correspond » avec « Effacer la recherche », « Aucun élève ne correspond » avec « Effacer la recherche ».
- Chargement : `aria-busy` posé par Turbo sur le frame, qui s'estompe.
- Erreur : réponse non 2xx → le frame affiche `ui_error_state` avec « Réessayer » (lien vers l'URL courante).
- Succès : le frame et son compteur.

### 3.10 Tokens

- Composants `ui_*` et tokens `@theme` seulement ; un seul nouvel utilitaire, `summary-plain`. Aucune valeur arbitraire, aucun `style=`, aucune couleur hors palette (UDR-0005).
- Retour : `text-mute`, survol `text-ink`. Infobulle : `bg-mist`, `text-ink`. Numéro invité : `bg-mist`, `font-mono` non (texte courant).

### 3.11 Accessibilité et 390 px

- Cibles ≥ 48 px : lien de retour, logo public, résumé de l'infobulle, case « Je les ai gardés », boutons de copie (`sm` agrandi par le pseudo-élément de `ui_button`).
- Le lien de retour est dans un `nav` nommé « Retour » ; il précède le `h1` dans l'ordre de tabulation.
- L'infobulle est un `summary` : rôle bouton et état ouvert/fermé fournis par le navigateur ; son nom est « Aide : <libellé> ».
- L'envoi automatique est annoncé avant (aide du champ, reliée par `aria-describedby`) et pendant (région `status`) ; le focus ne bouge pas.
- La recherche annonce le nombre de résultats (`aria-live="polite"`), jamais le focus déplacé.
- L'auto-focus ne vise jamais la croix d'une modale.
- À 390 px : aucun défilement horizontal de la page ; les boutons de copie et des codes de secours passent à la ligne (`flex-wrap`) ; le panneau d'infobulle reste dans le flux ; le lien de retour tient sur une ligne (libellé tronqué par `truncate` au-delà).

### 3.12 Vérification

- `/design` gagne une section « Finitions » : `ui_back_link`, `ui_page_header(back:)`, `ui_info_tip`, `ui_copy_button`, un formulaire `autosubmit` (motif 6 chiffres), un formulaire `search` sur un frame de démonstration, une modale avec champs et une confirmation (auto-focus), le titre composé. `test/system/design_system_test.rb` les exerce dans Chrome.
- `test/helpers/page_title_helper_test.rb`, `test/helpers/components_helper_test.rb` : 100 % des lignes et branches des helpers.
- `test/views/page_titles_test.rb` (Lot Z) : toute vue de page (hors partials, layouts, composants, Turbo Streams, vues servies seulement dans un frame comme `school/drena_schools/index`, et démonstrations `design/modal` et `design/frame`) appelle `page_title`, et aucun `autofocus` ni `content_for :title` ne subsiste dans `app/views`.
- Budget JS (ADR-0051) : les quatre nouveaux contrôleurs et la suppression de `classroom--join-code-copy` tiennent sous 60 Ko gzip (`bin/check-asset-budget`).

## 4. Conséquences

- Toute nouvelle page appelle `page_title` ; toute nouvelle page imbriquée qui n'est pas une destination de la navigation déclare son retour par `back:` ou `ui_back_link`.
- Tout nouveau geste de copie passe par `ui_copy_button` ; un nouveau contrôleur de copie est interdit. Un code fait pour être dicté ne reçoit jamais de bouton « Copier ».
- Tout nouvel envoi automatique passe par `autosubmit` : motif explicite, une seule soumission, aide qui l'annonce, bouton conservé.
- Toute nouvelle liste longue filtrée reprend `search` : GET, frame, URL remplacée pendant la frappe, compteur `aria-live`.
- Toute aide à la demande passe par `ui_info_tip` ; `title=` comme seule aide est interdit.
- Interdit désormais : l'attribut `autofocus` dans une vue, `content_for :title` (après le Lot Z), un suffixe « · Lnclass » écrit dans une locale, un bouton `arrow-left` de retour, un fil d'Ariane complet, un téléchargement automatique.

---

## Amendement du 2026-09-29 — clôture du chantier (Lot Z)

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/journal.md), Lot Z. Précisions tirées de l'exécution des lots ; elles font foi en cas d'écart avec les sections ci-dessus.*

- **§3.6, bascule code / code de secours** : les liens « J'utilise un code de secours » et « Utiliser le code de l'application » sont des **visites ordinaires** (`advance`), **sans** `data-turbo-action="replace"`. Le layout déclare `turbo_refreshes_with method: :morph` : Turbo traite un `replace` vers le même chemin comme un rafraîchissement et fusionne la page, qui garderait le focus sur le lien au lieu du nouveau champ. Coût accepté : un pas d'historique de plus (Lot B).
- **§3.3, déclenchement** : en mode `page`, le contrôleur `autofocus` rejoue aussi sa règle à `turbo:morph` (sur `document`). Un re-rendu 422 d'un formulaire de page est un rafraîchissement fusionné : `<body>` n'est pas reconnecté et `connect()` ne repasse pas. Aucune vue n'a à déclarer `turbo:morph@document->autofocus#focus`.
- **§3.3, confirmations ouvertes depuis un menu ⋮** : `dropdown#openDialog` (UDR-0042) émet lui aussi `modal:opened` sur la `<dialog>` après `showModal()` ; la confirmation vise « Annuler » comme celle ouverte par `modal#open`.
- **§3.4, badge des niveaux** : le badge s'appelle « Hors barème » (UDR-0045) ; son aide se nomme donc « Aide : Hors barème » (le libellé du badge, règle « Aide : <libellé> »), et non « hors génération ». Texte inchangé.
- **§3.9, état d'erreur** : le formulaire de recherche porte un `<template data-search-target="error">` rendu par `ui_error_state` ; sur `turbo:frame-missing` (réponse sans le frame : page d'erreur, non 2xx) ou `turbo:fetch-request-error` (réseau), le contrôleur `search` le pose dans le frame. « Réessayer » rejoue **la recherche qui a échoué** (action du formulaire et ses champs) en page entière (`data-turbo-frame="_top"`) : une session expirée ou une classe disparue y montre sa vraie page. Posé sur les quatre listes : établissements, catalogue, élèves d'une classe (enseignant, direction).
- **§3.1, titres visibles des imports** : le deux-points est retiré du seul **titre de l'onglet** ; les titres visibles « Importer : DRENA » et « Import : Établissements » le gardent (la règle du segment « Page » vise l'onglet). La modale de suivi d'un import nomme l'onglet comme la page du rapport (« Import d'établissements · Équipe · Lnclass »).

## Amendement du 2026-09-29 — textes validés, ouverture au survol

*Décision du porteur du 2026-09-29 : « valide le tooltip et affiche le contenu au passage de la souris ». Elle fait foi en cas d'écart avec le §2.6 et le §3.4.*

- **Textes** : les textes du §3.4 sont validés tels quels, avec la précision « Hors barème » de l'amendement précédent.
- **Survol** : à la souris, l'infobulle s'ouvre quand le pointeur entre sur elle et se referme quand il en sort. La règle « aucun contrôleur » du §3.4 est levée pour cela seul : le contrôleur `info-tip` est posé sur le `<details>` (`pointerenter` / `pointerleave`).
  - **Souris seulement** : le contrôleur lit `event.pointerType === "mouse"`, pas la media query `(hover: hover)`, que des appareils et Chrome sans interface déclarent mal. Au toucher, `pointerenter` précède le clic, qui reste seul à ouvrir.
  - **Clic pendant le survol** : il garde l'infobulle ouverte (le navigateur la refermerait sous la souris). Elle devient ouverte « au clic » : le pointeur qui part ne la ferme plus, le clic suivant la ferme.
  - **Une infobulle déjà ouverte par un clic** n'est pas reprise par le survol.
  - **Clavier, toucher, sans JavaScript** : inchangés, le `<details>` natif suffit.
- **Panneau au survol : une bulle.** Au survol, le panneau **flotte** sous l'icône, en `position: fixed`, et ne pousse rien. La règle « dans le flux » du §3.4 vaut toujours pour l'infobulle ouverte au clic, au toucher ou au clavier, et pour celle qu'un clic a épinglée.
  - **Pourquoi pas dans le flux** : ouvert dans le flux, le panneau élargit le `<details>` et déplace l'icône (en-tête de la classe, à 390 px comme au bureau). La souris n'est plus dessus : l'infobulle se ferme, l'icône revient, elle se rouvre, et ainsi de suite.
  - **Pourquoi `fixed`, pas `absolute`** : une bulle absolue serait coupée par les tableaux défilants (`overflow-x-auto`). La position fixe y échappe. Le contrôleur la calcule depuis l'icône : bord gauche aligné, contenue dans la fenêtre à 16 px des bords, au-dessus de l'icône s'il manque la place dessous. Elle est replacée à chaque défilement.
  - **Style** : les classes `group-data-floating:` du partial (`fixed`, `z-50`, `w-max`, `max-w-bubble`, `shadow-pop`). Le nouvel utilitaire `@utility max-w-bubble` limite la bulle à `--container-form` et à la fenêtre moins 2 rem ; il s'ajoute à UDR-0005, comme `summary-plain`. Le contrôleur pose et retire `data-floating` ; ses seules écritures de style passent par le CSSOM (`left`, `top`), que la CSP stricte (ADR-0049) autorise.
  - **Épinglée par un clic**, la bulle retourne dans le flux.
- **Vérification** :
  - `test/system/design_system_test.rb` : ouverture au survol en bulle fixe, sans que l'icône bouge ; fermeture au départ du pointeur ; clic qui garde ouvert, de retour dans le flux ; clic suivant qui ferme ;
  - `test/helpers/components_helper_test.rb` : le contrôleur et ses actions sont posés.
