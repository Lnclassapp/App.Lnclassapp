# PRD — Finitions UX

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Sept finitions d'interface manquent ou varient d'un écran à l'autre ([audit](audit.md), [memo](memo.md)) : titre de l'onglet, lien de retour, auto-focus, aide à la demande, bouton « Copier », envoi automatique des gestes clés et recherche pendant la frappe. Le porteur a tranché le 2026-09-29 (memo, « Ce que le grill a révélé ») ; le caching et les secrets hors cache sont des chantiers séparés. Le chantier livre une brique commune par finition ([UDR-0054](../../decisions/udr/0054-finitions-d-interface.md)), l'applique écran par écran, et renvoie la personne qui accepte une invitation sur « Se connecter » avec son numéro pré-rempli.

## 2. Acteurs et permissions

Le chantier n'ajoute **aucun droit** : chaque écran garde sa règle d'autorisation actuelle. La recherche filtre une liste déjà autorisée, elle ne l'élargit jamais.

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Public (non connecté) | Revenir à l'accueil public par le logo ; envoyer `/join` au 5ᵉ caractère valide ; après une invitation acceptée, trouver son numéro pré-rempli sur « Se connecter » | Voir un numéro pré-rempli par l'URL ou par un autre navigateur ; recevoir un PIN pré-rempli |
| Élève | Voir des titres, retours et infobulles (badges, maîtrise) | Copier le code de sa classe (UDR-0011) |
| Enseignant | Copier le code **et** le lien de sa classe ; chercher un élève de sa classe | Chercher un élève d'une classe qu'il n'enseigne pas (`ReadClassroomPolicy`, 403 inchangé) ; copier un code de récupération du PIN (UDR-0020) |
| Équipe | Copier les liens d'invitation ; chercher pendant la frappe dans les établissements et « Débloquer un compte » ; second facteur à envoi automatique ; télécharger, copier, imprimer ses codes de secours | Chercher un compte par numéro partiel (UDR-0020, inchangé) ; continuer après l'activation sans confirmer « Je les ai gardés » |
| Direction | Chercher un élève dans une classe de son établissement ; lire les infobulles des indicateurs | Chercher dans une classe d'un autre établissement (règle de l'espace direction, 404/403 inchangés) |

## 3. Parcours utilisateur

### Chemin nominal

1. **Équipe, invitation** : la personne invitée ouvre le lien ; le focus est sur « Nom » ; elle remplit, clique « Créer mon compte » ; elle arrive sur « Se connecter » avec **son numéro déjà rempli** et le focus sur le PIN ; elle tape son PIN ; sur l'activation du second facteur, elle scanne le QR code et tape 6 chiffres : le code part seul ; elle voit ses 10 codes, les télécharge, coche « Je les ai gardés », clique « Continuer » et arrive sur l'accueil « Accueil · Équipe · Lnclass ».
2. **Équipe, établissements** : elle tape « coc » dans la recherche ; 300 ms après la dernière frappe, la liste se met à jour sans rechargement et le nombre de résultats est annoncé ; elle choisit une DRENA, la liste part aussitôt ; elle ouvre une fiche, puis revient par « Établissements » à la **même liste filtrée** ; elle invite la direction et copie le lien d'un clic (« Lien copié. »).
3. **Enseignant, classe** : il ouvre sa classe, copie le lien `/c/<code>` ; tape « awa » dans « Chercher un élève », retrouve Awa Bamba et génère son code de récupération (qui se dicte, sans « Copier ») ; revient par « Accueil ».
4. **Direction** : sur « Travail des élèves », elle ouvre l'aide de « Taux de rendu » d'un toucher, lit la définition ; ouvre une classe, cherche un élève, revient par « Travail des élèves ».
5. **Élève** : il tape son code de classe sur `/join` ; au 5ᵉ caractère valide, la page de sa classe s'ouvre.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Code du second facteur faux (6 chiffres) | 422, message sous le champ, champ vidé, focus sur le champ ; un seul essai consommé ; rien ne repart tant que la personne ne retape pas |
| Entrée pressée au moment où le 6ᵉ chiffre part | Une seule requête |
| Code de secours | Lien « J'utilise un code de secours » → champ séparé, sans envoi automatique ; « Vérifier » à la main |
| Sans JavaScript | Titres, retours, infobulles (`<details>`), recherche (bouton « Filtrer »), bascule du code de secours et confirmation « Je les ai gardés » marchent ; « Copier », « Télécharger », « Imprimer » sont absents ; rien ne part seul |
| Presse-papiers refusé (page hors HTTPS, navigateur) | Toast d'avertissement « La copie a échoué : sélectionnez le texte et copiez-le à la main. » |
| Invitation invalide à l'envoi (champ manquant) | 422, focus sur le premier champ en erreur, rien n'est gardé pour « Se connecter » |
| « Se connecter » rechargée après une acceptation | Numéro plus pré-rempli (valeur à usage unique) |
| Invitation périmée, servie ou révoquée | Message seul (inchangé) |
| Numéro devenu un compte entre-temps | 422, alerte en tête (inchangé) |
| Recherche d'un seul caractère | Rien ne part ; effacer le champ ré-affiche toute la liste |
| « Débloquer un compte », numéro incomplet | Rien ne part ; numéro complet (10 chiffres, ou avec `+225`/`00225`) → recherche exacte |
| Recherche sans résultat | État vide « Aucun … ne correspond » avec « Effacer la recherche » |
| Erreur serveur pendant une recherche | `ui_error_state` dans le frame, avec « Réessayer » |
| Fiche établissement ouverte depuis un lien direct | Retour vers la liste sans filtre |
| Classe vide | Pas de champ « Chercher un élève » |
| Modale sans champ (confirmation) | Focus sur « Annuler » |

## 4. Critères d'acceptation

Préfixe **FU-xx**. Chaque critère devient au moins un test ; le lot qui le porte est dans [`plan.md`](plan.md).

### Titre de page

```gherkin
# FU-01
Étant donné un membre de l'équipe connecté
Quand il ouvre la liste des établissements
Alors le titre du document est « Établissements · Équipe · Lnclass »

# FU-02
Plan du scénario : les accueils se distinguent
  Étant donné un compte <rôle> connecté
  Quand il ouvre son accueil
  Alors le titre du document est « <titre> »
  Exemples:
    | rôle       | titre                        |
    | élève      | Accueil · Élève · Lnclass      |
    | enseignant | Accueil · Enseignant · Lnclass |
    | équipe     | Accueil · Équipe · Lnclass     |

# FU-03
Étant donné un visiteur non connecté
Quand il ouvre « /login »
Alors le titre du document est « Connexion · Lnclass »

# FU-04
Étant donné un membre de l'équipe sur la page des niveaux
Quand il ouvre la modale « Nouveau niveau »
Alors le titre du document est « Nouveau niveau · Équipe · Lnclass »
Quand il ferme la modale
Alors le titre du document redevient « Niveaux · Équipe · Lnclass »

# FU-05
Plan du scénario : une modale ouverte par son URL a son titre
  Étant donné un compte <rôle> connecté
  Quand il ouvre directement « <url> »
  Alors l'élément <title> vaut « <titre> »
  Exemples:
    | rôle   | url                   | titre                              |
    | équipe | /teams/levels/new     | Nouveau niveau · Équipe · Lnclass  |
    | équipe | /teams/courses/new    | Nouveau cours · Équipe · Lnclass   |
    | équipe | /teams/drenas/new     | Nouvelle DRENA · Équipe · Lnclass  |
    | élève  | /profile/name/edit    | Modifier mon nom · Élève · Lnclass |

# FU-06
Étant donné l'ensemble des vues de page de l'application
Alors chacune appelle « page_title »
Et aucune vue ne pose « content_for :title »
Et aucune locale ne contient le suffixe « · Lnclass »
```

### Retour

```gherkin
# FU-07
Étant donné un membre de l'équipe sur la fiche du « Lycée moderne de Cocody »
Quand il ouvre la classe « 3e A » de cet établissement
Alors un lien de retour « Lycée moderne de Cocody » mène à la fiche de l'établissement

# FU-08
Étant donné un enseignant de la classe « 3e A »
Quand il ouvre la page de la classe
Alors un lien de retour « Accueil » mène à son accueil

# FU-09
Étant donné un membre de l'équipe sur la liste des établissements filtrée par « coc » et la DRENA « Abidjan 1 »
Quand il ouvre une fiche puis clique « Établissements »
Alors la liste affichée est filtrée par « coc » et la DRENA « Abidjan 1 »
Et si la fiche avait été ouverte par un lien direct, « Établissements » mène à la liste sans filtre

# FU-10
Plan du scénario : les écrans imbriqués ont un retour
  Étant donné un compte <rôle> connecté
  Quand il ouvre « <écran> »
  Alors un lien de retour « <libellé> » est le premier lien du contenu principal
  Exemples:
    | rôle       | écran                  | libellé             |
    | équipe     | Niveaux                | Accueil             |
    | équipe     | Séries                 | Accueil             |
    | équipe     | Matières               | Accueil             |
    | équipe     | DRENA                  | Accueil             |
    | équipe     | Barème des classes     | Accueil             |
    | équipe     | Croissance             | Accueil             |
    | équipe     | Débloquer un compte    | Accueil             |
    | équipe     | Rapport d'import       | Imports             |
    | enseignant | Inviter un collègue    | Classes             |
    | élève      | Mon profil             | Accueil             |
    | direction  | Classe « 3e A »        | Travail des élèves  |

# FU-11
Étant donné l'ensemble des vues de l'application
Alors aucun lien de retour n'est un bouton à icône « arrow-left »
Et aucun fil d'Ariane à plusieurs niveaux n'existe

# FU-12
Étant donné un membre de l'équipe sur l'activation du second facteur
Quand il clique « Se déconnecter »
Alors sa session est fermée et il arrive sur « Se connecter »

# FU-13
Plan du scénario : le logo des pages publiques mène à l'accueil public
  Étant donné un visiteur non connecté sur « <page> »
  Quand il clique le logo « Lnclass, accueil »
  Alors il arrive sur l'accueil public
  Exemples:
    | page                            |
    | /login                          |
    | /join                           |
    | /c/<code>                       |
    | /teacher-signup                 |
    | /teacher-signup/without-code    |
    | /invitations/<token>            |
    | /identity/pin-reset             |

# FU-14
Étant donné un visiteur connecté sur la page d'un cours
Alors le seul lien de retour est « Cours », vers le catalogue
```

### Auto-focus

```gherkin
# FU-15
Étant donné un membre de l'équipe sur la page des niveaux
Quand il ouvre la modale « Nouveau niveau »
Alors le focus est sur le champ « Nom », pas sur le bouton de fermeture

# FU-16
Étant donné la modale « Nouveau niveau » ouverte
Quand il l'envoie avec un nom vide
Alors la modale est re-rendue en 422
Et le focus est sur le champ « Nom », marqué en erreur

# FU-17
Étant donné un visiteur sur « /c/<code> »
Quand il envoie l'inscription sans prénom
Alors la page est re-rendue en 422
Et le focus est sur le premier champ en erreur

# FU-18
Étant donné un membre de l'équipe sur la liste des niveaux
Quand il ouvre la confirmation « Supprimer » d'un niveau
Alors le focus est sur « Annuler »

# FU-19
Plan du scénario : le focus d'arrivée sur les pages publiques
  Étant donné un visiteur sur « <page> » sans erreur
  Alors le focus est <focus>
  Exemples:
    | page                  | focus                              |
    | /login                | sur le champ du numéro             |
    | /join                 | sur le champ du code               |
    | /c/<code>             | laissé au navigateur (aucun champ) |
    | /teacher-signup       | laissé au navigateur (aucun champ) |

# FU-20
Étant donné l'ensemble des vues de l'application
Alors aucune ne contient l'attribut « autofocus »
```

### Infobulle

```gherkin
# FU-21
Étant donné un membre de la direction sur « Travail des élèves »
Quand il active l'aide de « Taux de rendu »
Alors la définition du taux de rendu s'affiche sous l'en-tête
Et le bouton d'aide s'appelle « Aide : Taux de rendu » et annonce son état ouvert
Et sans JavaScript, la même aide s'ouvre (élément details)

# FU-22
Étant donné un membre de l'équipe sur la liste des niveaux
Alors le badge « hors génération » n'a pas d'attribut title
Et il est suivi d'une aide « Aide : hors génération »

# FU-23
Étant donné un écran de 390 px de large sur la page de pilotage
Quand toutes les aides de la page sont ouvertes
Alors la page ne défile pas horizontalement
```

### Copier

```gherkin
# FU-24
Étant donné un membre admin de l'équipe qui vient de créer une invitation
Quand il clique « Copier le lien » dans la modale « Invitation créée »
Alors le presse-papiers contient le lien d'invitation affiché
Et le toast « Lien copié. » s'affiche

# FU-25
Étant donné un membre de l'équipe qui vient d'inviter la direction d'un établissement
Quand il clique « Copier le lien »
Alors le presse-papiers contient le lien d'invitation de la direction

# FU-26
Plan du scénario : les codes et liens déjà copiables le restent, avec le contrôleur unique
  Étant donné <acteur> sur <écran>
  Quand il clique « <bouton> »
  Alors le presse-papiers contient <valeur>
  Exemples:
    | acteur        | écran               | bouton           | valeur                     |
    | un enseignant | la page de sa classe | Copier           | le code en majuscules      |
    | un enseignant | la page de sa classe | Copier le lien   | l'URL « /c/<code> »        |
    | l'équipe      | la fiche établissement | Copier le code | le code d'établissement    |
    | l'équipe      | la fiche établissement | Copier le lien | l'URL « /e/<code> »        |

# FU-27
Étant donné un élève sur « Ma classe » et un enseignant devant la modale du code de récupération
Alors aucun bouton « Copier » n'est proposé pour le code de la classe de l'élève ni pour le code de récupération

# FU-28
Étant donné un enseignant sur « Inviter un collègue »
Quand il clique « Copier le lien »
Alors le presse-papiers contient son lien de parrainage
Et un partage « copy » est enregistré pour lui

# FU-29
Étant donné un navigateur qui refuse l'écriture dans le presse-papiers
Quand l'utilisateur clique un bouton de copie
Alors le toast « La copie a échoué : sélectionnez le texte et copiez-le à la main. » s'affiche
```

### Acceptation d'une invitation

```gherkin
# FU-30
Étant donné une invitation valable
Quand la personne invitée ouvre le lien
Alors le focus est sur le champ « Nom »
Et aucun champ de numéro n'est affiché

# FU-31
Étant donné une invitation d'équipe valable pour le 01 00 00 00 09
Quand la personne invitée envoie un formulaire valide
Alors aucune session d'authentification n'est ouverte
Et elle arrive sur « Se connecter » avec le numéro « 01 00 00 00 09 » pré-rempli et le champ PIN vide
Et le focus est sur le champ PIN
Et ni l'URL de redirection ni le flash ne contiennent le numéro

# FU-32
Étant donné la personne arrivée sur « Se connecter » avec son numéro pré-rempli
Quand elle recharge la page
Alors le champ numéro est vide
Et une invitation de direction acceptée mène de même à « Se connecter », numéro pré-rempli, puis à « Travail des élèves » après le PIN

# FU-33
Étant donné une invitation valable
Quand la personne invitée envoie un formulaire sans nom
Alors la page est re-rendue en 422
Et le focus est sur le champ « Nom »
Et une visite de « Se connecter » ensuite n'a pas de numéro pré-rempli
```

### Envoi automatique et second facteur

```gherkin
# FU-34
Étant donné un membre de l'équipe sur la vérification du second facteur
Quand il tape les 6 chiffres d'un code valable sans cliquer « Vérifier »
Alors le formulaire part une seule fois
Et il arrive sur son accueil

# FU-35
Étant donné un membre de l'équipe sur la vérification du second facteur
Quand il tape 6 chiffres d'un code faux
Alors la page est re-rendue en 422 avec le champ vidé et le focus dessus
Et une seule tentative de second facteur est journalisée
Et aucun nouvel envoi ne part tant qu'il n'a pas retapé 6 chiffres

# FU-36
Étant donné un membre de l'équipe sur la vérification du second facteur
Quand il tape le 6ᵉ chiffre puis Entrée aussitôt
Alors une seule requête de vérification est reçue

# FU-37
Étant donné un membre de l'équipe sur la vérification du second facteur
Quand il clique « J'utilise un code de secours »
Alors un champ « Code de secours » remplace le champ du code
Et taper 6 caractères dans ce champ n'envoie rien
Et « Vérifier » avec un code de secours valable le mène à son accueil
Et sans JavaScript, le lien mène à la même variante

# FU-38
Étant donné un membre de l'équipe sur l'activation du second facteur
Quand il tape les 6 chiffres affichés par son application
Alors le formulaire part seul et ses 10 codes de secours s'affichent

# FU-39
Étant donné un champ à envoi automatique
Alors son aide dit « Le code est envoyé dès le 6ᵉ chiffre. » et lui est reliée par aria-describedby
Et à l'envoi, la région d'état annonce « Envoi du code… »

```

### Envoi automatique de `/join`

```gherkin
# FU-44
Étant donné un visiteur sur « /join »
Quand il tape « kfm37 »
Alors la page de la classe « KFM37 » s'ouvre sans clic
Et taper « kfm3 » ou « kio37 » n'envoie rien
```

### Codes de secours

```gherkin
# FU-40
Étant donné les 10 codes de secours affichés après l'activation
Quand le membre de l'équipe clique « Continuer » sans cocher « Je les ai gardés »
Alors il reste sur la page
Quand il coche « Je les ai gardés » puis clique « Continuer »
Alors il arrive sur son accueil

# FU-41
Étant donné les 10 codes de secours affichés
Quand il clique « Télécharger »
Alors un fichier « lnclass-codes-de-secours.txt » contenant les 10 codes est téléchargé

# FU-42
Étant donné les 10 codes de secours affichés
Quand il clique « Copier »
Alors le presse-papiers contient les 10 codes, un par ligne
Quand il clique « Imprimer »
Alors la boîte d'impression du navigateur est demandée

# FU-43
Étant donné l'activation du second facteur réussie
Alors aucun téléchargement ne démarre sans clic
```

### Recherche pendant la frappe

```gherkin
# FU-45
Étant donné un membre de l'équipe sur la liste des établissements
Quand il tape « coc » dans la recherche et attend
Alors seule la liste se met à jour, sans rechargement de page
Et l'URL porte « search=coc » sans nouvelle entrée d'historique
Et le nombre d'établissements trouvés est annoncé
Quand il choisit une DRENA dans la liste déroulante
Alors la liste se met à jour sans clic sur « Filtrer »

# FU-46
Étant donné un navigateur sans JavaScript sur la liste des établissements
Quand il remplit la recherche et clique « Filtrer »
Alors la page filtrée s'affiche

# FU-47
Étant donné un catalogue qui contient « Mathématiques 3e »
Quand un visiteur connecté tape « mathematiques » dans « Rechercher un cours »
Alors « Mathématiques 3e » est affiché
Quand il tape « zzz »
Alors l'état vide « Aucun cours ne correspond » propose « Effacer la recherche »

# FU-48
Étant donné un enseignant sur la page de sa classe qui compte Awa Bamba et Koffi Yao
Quand il tape « awa » dans « Chercher un élève »
Alors seule Awa Bamba est listée et « 1 élève » est annoncé
Et un élève d'une autre classe n'apparaît jamais
Et une classe sans élève n'affiche pas le champ de recherche

# FU-49
Étant donné un membre de la direction sur une classe de son établissement
Quand il tape le début du nom d'un élève
Alors seuls les élèves correspondants de cette classe sont listés

# FU-50
Étant donné un membre de l'équipe sur « Débloquer un compte »
Quand il tape « 05 11 22 33 »
Alors aucune recherche ne part
Quand il complète en « 05 11 22 33 44 »
Alors la carte du compte s'affiche sans clic
Et « 05 11 22 33 » seul ne trouve jamais de compte (recherche exacte inchangée)

# FU-51
Étant donné une liste à recherche pendant la frappe
Quand l'utilisateur tape un seul caractère
Alors aucune requête ne part
Quand il efface le champ
Alors la liste complète revient

# FU-52
Étant donné un membre de l'équipe sur le pilotage
Quand il choisit une DRENA dans la liste déroulante
Alors les chiffres de la DRENA s'affichent sans clic sur « Filtrer »
```

### Transverses

```gherkin
# FU-53
Plan du scénario : aucune page touchée ne déborde à 390 px
  Étant donné un écran de 390 px de large
  Quand <acteur> ouvre « <page> »
  Alors la page ne défile pas horizontalement
  Exemples:
    | acteur     | page                                   |
    | équipe     | codes de secours                       |
    | équipe     | vérification du second facteur         |
    | enseignant | page de sa classe                      |
    | visiteur   | acceptation d'une invitation           |
    | tous       | catalogue avec recherche               |

# FU-54
Étant donné les assets compilés
Alors le JavaScript tient sous le plafond de 60 Ko gzip (ADR-0051)
Et le contrôleur « classroom--join-code-copy » n'existe plus
```

**Total : 54 critères (FU-01 à FU-54).**

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Rien. `AcceptInvitation` renvoie déjà le compte créé, dont le contrôleur lit le numéro. Aucune entité, aucun port, aucun contrat modifié. |
| Infrastructure | `Queries::Shared::TextSearch` (fragment de recherche sans casse ni accents). Paramètre `search:` sur `Queries::Catalog::CourseCatalogQuery`, `Queries::Classroom::ClassroomOverviewQuery` (élèves) et `Queries::School::StudentWorkQuery` (élèves d'une classe). `school_public_id` ajouté à `Queries::Classroom::ClassroomHeaderQuery::Row`. **Aucune migration, aucun index.** |
| Delivery | `Identity::InvitationsController#accept` (`session[:login_contact]`) ; `Identity::SessionsController#new` (lecture unique de `session[:login_contact]`) ; `Identity::SecondFactorsController#new/#create` (paramètre `backup`) ; lecture de `q` dans `Catalog::CoursesController`, `Classroom::ClassroomsController`, `SchoolAdmin::ClassroomsController`. **Aucune route nouvelle.** |
| UI | Helpers `page_title`, `document_title`, `back_href`, `ui_back_link`, `ui_page_header(back:)`, `ui_info_tip`, `ui_copy_button`, `ui_modal(document_title:)` ; partials `components/_back_link`, `_info_tip`, `_copy_button` ; contrôleurs Stimulus `clipboard`, `autofocus`, `autosubmit`, `search`, `download` ; suppression de `classroom--join-code-copy` ; utilitaire CSS `summary-plain` ; ≈ 75 vues touchées (titre, retour, auto-focus, infobulle, copie, recherche). |

## 6. Décisions rattachées

- **Aucun ADR** : l'authentification ne change pas (ADR-0050 et UDR-0019 §2.4 tenus : pas de session à l'acceptation, décision du porteur du 2026-09-29) ; la recherche n'ajoute ni index ni extension (UDR-0054 §2.12, mesure au §7).
- [UDR-0054](../../decisions/udr/0054-finitions-d-interface.md) — finitions d'interface. `Accepté` (par le porteur le 2026-09-29 ; textes d'infobulles à valider dans la PR).
- Amendements datés du 2026-09-29 (`Proposé`) : UDR-0005 (briques), 0006 (titre, retour, auto-focus, toasts à l'impression), 0009 (`/join`), 0011 (copie toujours interdite), 0013 (recherche du catalogue, retour de la page cours), 0015, 0021, 0023, 0028, 0029, 0030 (libellés de retour et titres), 0019 (copie, numéro pré-rempli sur « Se connecter », focus), 0020 (recherche pendant la frappe, copie toujours interdite), 0027 (contrôleur de copie, lien de classe, retour selon le rôle, recherche d'élève), 0032 (infobulle du badge), 0036 (recherche, retour filtré), 0042 (focus des confirmations), 0044 (contrôleur de copie), 0049 (DRENA au changement, infobulles), 0050 (copie du partage, retours, infobulles de Croissance), 0052 (retour, recherche, infobulles de la direction).

## 7. Mesures

La recherche pendant la frappe multiplie les requêtes sur la liste des établissements. On mesure avant d'en conclure qu'un index manque.

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Durée serveur de `GET /teams/schools?search=coc` (frame), base de démonstration + 3 000 établissements, médiane de 20 appels | à mesurer au Lot D1 | < 150 ms | à mesurer au Lot D1 |
| Requêtes par frappe (recherche des établissements) | 1 par clic | ≤ 1 par pause de 300 ms, 0 sous 2 caractères | — |
| JavaScript gzip (`bin/check-asset-budget`) | 39,7 Ko (2026-09-25) | < 60 Ko | à mesurer au Lot Z |

Si la durée dépasse la cible, le Lot D1 s'arrête et le point remonte au chantier de caching (index trigramme, ADR), sans index improvisé.
