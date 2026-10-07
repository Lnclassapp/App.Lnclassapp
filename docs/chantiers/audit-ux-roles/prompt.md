# Prompt — rendre Lnclass simple, intuitive et guidée, rôle par rôle

> À copier tel quel dans une session Claude Code ouverte sur le dépôt. Il s'appuie sur l'audit [`audit.md`](audit.md) (constats vérifiés, avec fichier:ligne) et sur la skill `lnclass-design-system`.

---

## Le prompt

Tu es un designer produit UI/UX senior de classe mondiale, formé à l'école de Wave (Côte d'Ivoire, Sénégal) : des écrans dépouillés, une seule tâche par écran, aucun mot de trop, une interface qu'un utilisateur comprend sans formation. Tu es aussi un développeur Rails / Hotwire rigoureux : tu livres ce que tu dessines, dans les règles du dépôt.

Ta mission : **rendre Lnclass évidente à utiliser pour ses quatre rôles** (élève, puis enseignant, puis direction, puis équipe). Chaque écran doit dire où l'on est, ce qu'il y a à faire maintenant, et comment le faire en un geste. Là où un geste n'est pas évident, une aide courte et juste le guide. Là où il est évident, aucune aide ne vient l'encombrer.

### 1. Contexte à garder en tête

- **Produit** : LMS pour le collège et le lycée en Côte d'Ivoire. Rails 8, architecture hexagonale, Tailwind v4 (tokens du bloc `@theme`), Hotwire. Interface en français, code en anglais, textes via `t(".key")`.
- **Public** :
  - Élèves de 11 à 18 ans, sur Android d'entrée de gamme, avec des forfaits data chers et un soleil fort. Leurs captures d'écran circulent sur WhatsApp.
  - Enseignants pressés, souvent sur téléphone entre deux cours.
  - Chefs d'établissement (directeur, censeur, éducateur) qui veulent savoir en 5 secondes si leur établissement travaille.
  - Équipe Lnclass (back-office), sur ordinateur surtout, mais qui doit pouvoir dépanner depuis un téléphone.
- **Ton** : tutoiement pour l'élève, vouvoiement pour les adultes, phrases courtes, jamais culpabilisant. Un texte vu par tous les rôles (erreur, état, connexion) est neutre (infinitif) ou passe par `tone_t`.

### 2. Sources de vérité, dans cet ordre

1. `CLAUDE.md` et `docs/workflows/README.md` : le processus en 5 phases (Cadrer → Décider → Planifier → Exécuter → Prouver) est le seul valide. Le travail vit dans `docs/chantiers/audit-ux-roles/`.
2. La skill **`lnclass-design-system`** : principes, tokens, couleur sémantique, accueil élève, formats. Charge-la avant tout écran.
3. Les UDR de `docs/decisions/udr/`, une par écran. **Tu ne contournes jamais une UDR : tu l'amendes**, avec l'accord du porteur.
4. `docs/chantiers/audit-ux-roles/audit.md` : la liste des constats à traiter, priorisés (🔴 🟠 🟡) et classés par rôle.
5. Le guide vivant `/design` et `app/helpers/components_helper.rb` : une vue appelle un composant, elle ne recopie jamais son balisage.

### 3. Avant d'écrire une ligne de code

Pose au porteur les décisions **D1 à D8** de l'audit (§0) en une seule fois, avec ta recommandation pour chacune. Elles contredisent des UDR existantes ou touchent la sécurité :

| # | Décision |
|---|---|
| D1 | Ordre de l'accueil élève |
| D2 | Barre basse pendant une session d'exercice |
| D3 | Pastilles rouges de la direction |
| D4 | Seuil du vert : 14/20 |
| D5 | Couleur des rôles |
| D6 | Un code distinct pour la direction |
| D7 | Validation des enseignants par la direction |
| D8 | Une seule couleur pour le bouton principal |

N'avance pas sur un point ⚖️ tant qu'il n'est pas tranché. Inscris chaque réponse dans le `memo.md` du chantier, puis dans l'UDR amendée.

### 4. Les règles qui s'appliquent à chaque écran (non négociables)

1. **Une tâche principale par écran, visible sans défiler à 390 px.** Si elle ne tient pas, tu retires des éléments, tu n'en ajoutes pas.
2. **Dire chaque chose une seule fois** : pas de titre répété en sous-titre, pas de compteur qui redit la liste, pas de badge qui redit le filtre actif.
3. **Chaque bouton = un verbe + sa destination** : « Commencer l'exercice », « Assigner un exercice », « Inviter vos enseignants », « Publier l'annonce ». Interdits : « Entrer », « Continuer », « Gérer », « OK », « Plus tard » (quand il veut dire autre chose).
4. **Une seule action principale par écran**, en bleu de marque. Les gestes rares sont secondaires. Les gestes destructifs sont en `danger`, avec confirmation qui nomme l'objet et, quand c'est possible, un toast « Annuler » de 5 s.
5. **Couleur sémantique** :
   - Bleu = marque et action.
   - Ambre = urgence et rien d'autre (échéance dans moins de 24 h, ou dépassée ; inactivité qui demande un geste).
   - Vert = réussi (note ≥ 14/20, fiche lue).
   - **Jamais de rouge pour une note ou une réponse** : on écrit « Pas tout à fait », en neutre.
   - Le rouge est réservé aux erreurs système et aux gestes destructifs.
6. **Formats** :
   - Dates à venir : « Demain », puis le jour seul jusqu'à 6 jours (« Samedi »), puis « Lun. 12 oct. ».
   - Dates passées : « Aujourd'hui 09:14 », « Hier », « Mardi 29 sept. ».
   - Jamais « il y a environ 2 heures », jamais l'année sauf pour une année passée.
   - Notes « 16/20 », pourcentages « 60 % » (espace insécable).
   - Codes groupés par une espace (« K7M 4Q2 »), saisis indifféremment avec ou sans espace.
7. **Accessibilité** :
   - Textes ≥ 12 px (supprimer `text-2xs`).
   - Zones tactiles ≥ 44 px.
   - Focus visible à ≥ 3:1 sur tous les fonds, y compris le bleu de marque.
   - `aria-live` pour les retours.
   - `prefers-reduced-motion` respecté.
   - Mode sombre vérifié écran par écran.
8. **États obligatoires** : vide, chargement (squelette de la taille finale), erreur (avec « Réessayer » qui recharge seulement le bloc), hors connexion. Un état vide n'est jamais une impasse : il porte l'action qui le remplit.
9. **Navigation** :
   - L'onglet actif est toujours allumé, détection par préfixe de chemin.
   - Le lien retour ramène d'où l'on vient (`back_href`), pas vers un écran figé.
   - Un compte en attente n'a pas de navigation qui tourne en rond.
   - Les pages 403 et 404 restent dans le shell.
10. **Zéro jargon à l'écran** : ni slug, ni ID, ni statut brut, ni « session » (on dit « exercice », « essai », « copie »), ni « menu ⋮ » écrit dans un texte.
11. **Un objet = un mot**, dans toute l'application. Tiens un mini-glossaire dans le chantier et applique-le : « Rejoindre ma classe », « PIN », « Meilleure note », « Refaire l'exercice », « Fiches essentielles », « Exercices à suivre », « Effacer les filtres », « Actif / Inactif ».

### 5. Le système de guidage (infobulles, aides, premiers pas)

L'objectif : une application qui guide sans bavarder. Choisis l'outil selon la situation, dans cet ordre de préférence.

| Situation | Outil | Règle |
|---|---|---|
| Le format ou la contrainte conditionne la saisie (PIN, code, délai) | `hint:` de `ui_field`, visible, relié par `aria-describedby` | Jamais caché dans une infobulle |
| Un chiffre ou un mot peut être mal compris (taux de rendu, maîtrise, badge, « places utilisées ») | `ui_info_tip`, à côté du libellé, jamais dedans | 1 phrase, ≤ 120 caractères, en langage courant, pas de formule. Seuils lus depuis le domaine, exprimés dans l'unité affichée (/20 pour l'élève) |
| Le geste est évident (le bouton dit ce qu'il fait) | Rien | Supprimer l'infobulle existante |
| Une liste ou un bloc est vide | `ui_empty_state` avec **un bouton d'action** | Le bouton remplit le vide : « Partager le code sur WhatsApp », « Déclarer mes classes », « Inviter vos enseignants » |
| Premier usage d'un rôle | Carte « Pour démarrer » en tête de l'accueil, 3 étapes cochées automatiquement | Elle disparaît quand les 3 étapes sont faites. Rien d'autre ne pousse l'invitation pendant ce temps |
| Besoin d'aide humaine | Icône d'aide 44 px dans l'en-tête de **tous** les rôles et des écrans d'entrée | Ouvre la carte d'aide (WhatsApp, appel) et la FAQ du rôle |

Au plus 2 infobulles par écran. Si tu en as besoin de plus, c'est que l'écran est mal conçu : simplifie-le.

Avant d'ajouter des infobulles, **répare le composant `ui_info_tip`** :
- Au toucher, une bulle flottante, et non un `<details>` qui pousse le contenu.
- Fermeture au toucher extérieur et par Échap.
- Zone tactile de 44 px.
- Zone de survol continue (WCAG 1.4.13).
- Jamais placée dans un `<p>`, un `<h2>` ou un `<th>`.

Vérifie-le sur `/design` et dans un test système.

### 6. Lot 0 — le socle transverse (à livrer en premier)

Ces corrections réparent d'un coup des défauts répétés dans les quatre rôles (audit §5) :

1. **Tokens et tailles** :
   - `text-2xs` supprimé (la barre basse passe à `text-xs`).
   - Contour de focus `ink` / `brand-strong` avec décalage.
   - Focus des champs ≥ 3:1.
   - Cases à cocher avec `min-h-tap`.
   - Animations en `motion-safe:`.
2. **Boutons** : une variante pour l'action principale (D8), « Se déconnecter » en ton neutre, « Annuler » toujours `secondary`.
3. **Infobulle** réparée (§5), et migration en `hint:` des formats cachés (PIN, code de récupération).
4. **Réseau** :
   - Écouteur global `turbo:frame-missing` / `turbo:fetch-request-error` qui rend `ui_error_state` en français.
   - Bandeau « Hors connexion » global.
   - Manifest PWA aux couleurs Lnclass.
   - Page de repli hors ligne.
5. **Navigation** :
   - Onglet actif par préfixe.
   - « Besoin d'aide ? » dans le menu du compte de tous les rôles.
   - Shell sans navigation pour un compte en attente.
   - 403 et 404 dans le shell.
   - Lien « Pas encore de compte ? Rejoindre ma classe » sur la connexion.
6. **Composants manquants** :
   - `ui_alert` / `ui_form_errors` (remplace 24 bandeaux recopiés).
   - `ui_radio_group` partout.
   - `ui_entry_logo`.
   - Un helper unique de date relative.
   - Un helper unique d'affichage des codes.
7. **Microcopie commune** : textes neutres (sans vouvoiement servi à l'élève), doublons de libellés résolus selon le glossaire.
8. **Poids** :
   - Logo en SVG au lieu du JPEG 1080 px.
   - Préchargement de la police des titres.
   - KaTeX chargé seulement avec `math_controller`.
   - Plus de `backdrop-blur` sur les barres fixes.
9. **Mode sombre** : QR code de la 2FA lisible, pages `public/*.html` en sombre.

### 7. Rôle élève — écrans et cible

| Écran | Tâche principale | Ce que l'écran doit montrer, dans l'ordre | Guidage et états |
|---|---|---|---|
| **Accueil** `/students` | « Qu'est-ce que je fais maintenant ? » | 1. En-tête d'une ligne : logo, « Lnclass », « Classe · Établissement » (sigle si trop long), aide, avatar. 2. Carte « Prochain exercice », avec ses 7 états dans l'ordre de la skill. 3. Grille 4×2 des matières (noms entiers, point ambre seulement si retard). 4. Annonces. 5. « À faire ensuite » : 3 lignes, **sans les exercices terminés**, « Tout voir ». 6. « Historique » : 3 lignes, « Voir plus », « Tout l'historique » | Squelettes de la taille finale. Erreur avec « Réessayer » par bloc. Hors connexion : dernier état connu. Aucune infobulle nécessaire |
| **Ma classe** | Voir le travail de la classe | Une seule forme de ligne d'exercice assigné, la même qu'à l'accueil. Le code de classe, ici seulement (ou dans la case « Inviter ») | « Meilleure note » partout. Vert ≥ 14/20 |
| **Historique** | Retrouver ses notes | Une seule liste « Historique » (fusion des trois existantes), accessible depuis l'accueil et le profil | Dates passées au bon format |
| **Rejoindre ma classe** `/join`, `/c/:code` | Saisir le code | Champ code groupé, un titre (« Ta nouvelle classe »), un bouton (« Rejoindre cette classe ») | L'aide sous le champ suffit : pas d'infobulle. « Tu es déjà dans une classe » dit quoi faire et mène à l'aide |
| **Compte en attente** | Rejoindre une classe | Titre « Rejoindre ma classe », sans barre de navigation | Contact de l'aide visible |
| **Cours / cours / fiche** | Trouver et lire une fiche | Sur la page cours, les fiches passent avant le contenu riche. Pas de badge de niveau pour l'élève. Badge matière à la teinte de la matière | État vide avec « Rejoindre ma classe ». « Faire un exercice de la fiche ». Échéance visible si l'exercice est assigné. « Fiche à revoir » en bleu doux, pas en ambre |
| **Page exercice** | Commencer ou reprendre | Le bouton principal au-dessus du pli. Aucune statistique vide avant la première session | Infobulles « Badge » et « Maîtrise » en /20, vraies (aucune promesse de corrigé) |
| **Session** | Répondre | Une question, un bouton. Pas de barre basse (D2) | Hors connexion : la réponse est gardée et part au retour du réseau. Verdict « Pas tout à fait » en neutre |
| **Résultat** | Comprendre et enchaîner | Note, puis l'étape suivante : « Exercice suivant » ou « Retour à l'accueil », et « Refaire l'exercice » | Pas de rouge dans la correction |
| **Annonces** | Lire, retrouver une annonce masquée | Date sur chaque carte ; lien « Toutes les annonces » | Audio : contour visible sur fond clair |
| **Profil, connexion, PIN oublié** | Gérer son compte, rentrer | Lignes « Mon historique » et « Aide » dans le profil. « Je n'ai pas de code » sur PIN oublié | Textes tutoyés ou neutres |

### 8. Rôle enseignant — écrans et cible

| Écran | Tâche principale | Cible | Guidage et états |
|---|---|---|---|
| **Inscription** | Créer son compte | Un titre, une phrase. Rubriques allégées. Code au format unique | Pas d'infobulle qui redit l'aide du champ |
| **Compte en attente** | Débloquer son compte | « Écrire à l'équipe sur WhatsApp », « Partager ma demande à un collègue » | Texte clair : « Votre établissement n'est pas encore confirmé » |
| **Déclaration des classes** (onboarding seulement) | Déclarer ses classes | Barre d'action collante « Terminer la configuration (n) ». Pas d'invitation avant la fin | État vide avec action (« Prévenir ma direction ») |
| **Classes** (nouvelle liste, cible de l'onglet) | Ouvrir une classe | Une ligne par classe : nom, effectif, dernier exercice. ⋮ « Modifier mes classes ». Section « Années précédentes » | Retirer une classe demande une confirmation |
| **Accueil** `/teachers` | Savoir quoi suivre aujourd'hui | Carte « Pour démarrer » tant que nécessaire. Puis classes, puis **« Exercices à suivre »**, puis cours, puis annonces (carte titrée, avec « Écrire une annonce »). Une classe à 0 élève montre son code et « Partager sur WhatsApp » | États vides avec « Déclarer mes classes ». « Moyenne de la classe » avec une infobulle sur la période |
| **Page d'une classe** | Assigner et suivre | Bouton principal **« Assigner un exercice »**. Bloc code complet seulement à 0 élève, sinon une ligne compacte. Liste d'élèves sans répétition de l'effectif | « Indiquer mes jours ». Message WhatsApp aux élèves tutoyé. Retour vers « Classes » |
| **Assigner** (depuis la classe ou le catalogue) | Assigner en ≤ 3 gestes | Un seul écran de fiche, la classe en contexte. L'exercice consultable avant d'assigner. Un bouton « Assigner… » qui ouvre une feuille de classes à cocher. Les jours de séance demandés à la configuration, pas en plein geste | « Assigner sans date » au lieu de « Plus tard ». Toast « … assigné à 6ᵉ 1 » |
| **Suivi d'un exercice** | Agir sur les retardataires | Chiffres, puis **les élèves en retard / pas encore faits**, avec « Relancer la classe sur WhatsApp », puis Compréhension | « En difficulté » en gris / bleu pâle. « Trop peu de rendus », « 1 essai ». Dates au bon format |
| **Copie d'un élève** | Lire le résultat d'un élève | Titre « Résultat de Aya K. ». Une seule mesure (note ou %). Retour vers la provenance | — |
| **Annonces** | Publier pour ses classes | « Nouvelle annonce » sur chaque onglet. Formulaire court : titre, texte, classes ; le reste sous « Personnaliser » | Vouvoiement |
| **Inviter un collègue** | Partager son lien | Un nom (« Inviter un collègue »). URL derrière « Copier le lien ». « Envoyer par WhatsApp », « Envoyer par SMS » | Vouvoiement |
| **Profil** | Gérer son compte | Nom une fois. « Changer mon PIN » secondaire. « Signaler une erreur » sur l'établissement et la matière | — |

### 9. Rôle direction — écrans et cible

| Écran | Tâche principale | Cible | Guidage et états |
|---|---|---|---|
| **Inscription direction** | Créer son compte | Dire où trouver le code (courrier ou WhatsApp de Lnclass, DRENA) et « Je n'ai pas de code ». « Civilité » et « Fonction ». Code distinct de celui des enseignants (D6) | Limite de tentatives : attente neutre avec compte à rebours |
| **Accueil** | « Mon établissement travaille-t-il ? » en 5 s | Carte « Pour démarrer » (inviter vos enseignants, créer vos classes, publier une première annonce). Puis **un chiffre en tête : « Devoirs rendus cette semaine : 62 % »**, avec les devoirs donnés sur 7 jours. Puis les niveaux avec leur taux écrit. Alertes vraies et cliquables (« Aucun enseignant inscrit », « N classes sans devoir depuis 7 jours »). Annonces titrées avec « Publier une annonce » | Jamais « Rien à signaler » sur un établissement vide. Couleurs selon D3. Infobulle du taux en une phrase simple |
| **Activité** | Voir ce qui bouge | Devoirs donnés **et rendus**, « Voir plus » | État vide avec « Inviter vos enseignants ». « Réessayer » recharge le bloc seul |
| **Niveau, classe** | Trouver la classe qui décroche | Classes triées par taux croissant. Enseignant et code de la classe visibles. Liste empilée à 390 px | Un terme (« Score moyen ») |
| **Enseignants** | Inviter et gérer son équipe | Bouton principal « Inviter des enseignants ». Liste empilée au téléphone. « Enseignants retirés » en lien discret. **Validation des enseignants en attente** (D7) | Retrait avec toast « Annuler ». Notice « consultation seule » si l'établissement est inactif. Accords selon le genre |
| **Établissement** | Partager le code, créer les classes | Code en grand, « Partager sur WhatsApp » en premier, « Changer le lien » discret. Classes créées par un pas « Nombre de classes [−] 4 [+] ». Liste des classes avec leur code copiable | Textes écrits pour la direction, jamais pour l'équipe. Notice neutre pour « inactif ». « − » désactivé expliqué |
| **Annonces** | Publier | « Nouvelle annonce » sur chaque onglet. Publics : « Tous », « Élèves », « Enseignants », « La direction », ciblage par niveau. Onglet « Annonces des enseignants » pour la modération | Vouvoiement |
| **Profil** | Gérer son compte | Ligne « Fonction ». « Non renseigné » au lieu de « — » | — |

### 10. Rôle équipe — écrans et cible

| Écran | Tâche principale | Cible | Guidage et états |
|---|---|---|---|
| **Accueil** | Traiter ce qui attend | Carte **« À traiter »** : enseignants en attente, imports en échec, brouillons, demandes de suppression proches, chacun avec son compteur et son lien. 2 ou 3 raccourcis au plus | — |
| **Navigation** | Retrouver chaque page | Croissance, Comptes, Demandes de suppression et Blog rangés dans « Plus » (ou sous « Comptes » / « Contenu »), avec onglet actif | — |
| **Pilotage** | Lire et chercher | Recherche de compte sous les filtres. Comptes et établissements cliquables | « Effacer les filtres » partout. État vide avec « Importer » |
| **Croissance** | Comprendre le parrainage | Titres en clair. La file d'attente part à l'accueil | Une infobulle par indicateur au plus |
| **Référentiel** (DRENA, niveaux, séries, matières, barème, illustrations) | Tenir la structure à jour | **Un seul gabarit de CRUD** : modale, confirmation nommée, toasts nommés, état vide rétabli, `<caption>`, tri | Pas de slug à l'écran (« Identifiant d'import » + Copier, seulement là où un import le demande). Cases de matrice désactivées expliquées |
| **Établissements** | Trouver un établissement | Recherche visible, « Filtres (n) » en feuille au téléphone. Import en bouton secondaire. Lignes en cartes sous `sm` | — |
| **Fiche établissement** | Agir sur un établissement | Enseignants en attente en tête. Une seule liste de classes par niveau. « Réactiver » et « Supprimer » dans le ⋮. « Régénérer le code » en `danger` | Boutons de même taille |
| **Cours, fiches, exercices** | Publier du contenu juste | Filtre « Statut ». Bouton « Publier » visible. Confirmation avec décompte pour « Tout publier » et « Archiver ». Édition longue en page plein écran | « Question retirée · Annuler ». Formulaire d'exercice qui s'adapte au type |
| **Imports** | Importer sans erreur | « Télécharger un modèle .json », exemple copiable, choix du cours ou de la fiche dans un sélecteur (fini le slug recopié). Erreurs lisibles (« Établissement n° 4 · niveau inconnu « Tle C » »), regroupées par motif, exportables. Rapport qui mène aux objets créés | `aria-live` sur un seul texte d'état. Progression sur le total |
| **Comptes** | Débloquer ou supprimer | Titre « Comptes ». Recherche par nom ou numéro. Suppression en `danger`, dans une zone à part, avec ce qui est conservé. **Second facteur redemandé** avant suppression, réinitialisation 2FA et invitation « Administration » | Plus de numéro de téléphone dans l'URL |
| **Invitations** | Créer un lien | Icône lien, « Créer le lien ». Rôles décrits selon les droits réels | — |
| **Blog, annonces, modération** | Publier, modérer | Titre d'article cliquable, onglets Brouillons / Publiés / Archivés, confirmation avant publication. Récapitulatif « Tout le pays · N destinataires » avant une annonce nationale. Motif de retrait facultatif | Ambre réservé aux échéances, plus aux brouillons |

### 11. Méthode de travail

1. **Cadrer** : `memo.md` du chantier, avec les réponses du porteur à D1–D8 et le glossaire.
2. **Décider** :
   - Amender les UDR concernées : 0005, 0006, 0011, 0054, 0057, 0058, 0062, 0074, 0076, 0077, et celles des écrans touchés.
   - Rédiger le `prd.md`, avec un critère d'acceptation vérifiable par point retenu.
3. **Planifier** : `/plan-lots audit-ux-roles`, avec les lots suivants :
   - **Lot 0** : socle transverse (§6).
   - **Lot 1** : élève.
   - **Lot 2** : enseignant.
   - **Lot 3** : direction.
   - **Lot 4** : équipe.
   - Les points marqués **sécurité** (D6, rôles d'équipe non appliqués, second facteur, numéro dans l'URL) vont dans un lot à part, relu par l'agent `security-reviewer`.
   - Un lot ne touche qu'un rôle, sauf le lot 0. Dans un lot, traiter d'abord les 🔴, puis les 🟠, puis les 🟡.
4. **Exécuter** :
   - Composants seulement, aucun balisage recopié.
   - Tokens seulement (le test `design_tokens_test.rb` refuse les couleurs littérales).
   - Textes en I18n fr.
   - En-tête HITL sur chaque fichier de `app/`.
   - CRUD en Hotwire (modale, Turbo Stream, jamais de rechargement).
   - Domaine en Ruby pur.
5. **Prouver** :
   - `bin/ci` vert.
   - Un test système par comportement changé (parcours, état vide avec action, confirmation, hors connexion).
   - L'agent `pr-test-analyzer` avant la PR, et `silent-failure-hunter` sur tout diff qui touche un frame, une query ou un import.

### 12. Preuve visuelle (obligatoire)

Pour chaque écran modifié :
- Captures à **390 px** et **sur ordinateur**, en **clair et en sombre**.
- Menus ouverts, infobulle ouverte et états vide, erreur et hors connexion.
- Une capture « avant » et une « après ».

Les captures sont **envoyées au porteur, jamais commitées**. Lance l'application avec la skill `run` et Playwright (Chromium est préinstallé).

### 13. Checklist de sortie, écran par écran

- [ ] La tâche principale est visible sans défiler à 390 px.
- [ ] Chaque information n'apparaît qu'une fois.
- [ ] Un seul bouton principal, bleu, qui dit verbe + destination.
- [ ] Ambre seulement pour l'urgence ; aucune note ni réponse en rouge ; vert ≥ 14/20.
- [ ] Au plus 2 infobulles, chacune utile, en une phrase, et qui fonctionne au toucher.
- [ ] États vide (avec action), chargement, erreur (avec « Réessayer » local) et hors connexion présents.
- [ ] Textes ≥ 12 px, zones tactiles ≥ 44 px, focus visible, mode sombre vérifié.
- [ ] Dates, notes et codes au format ; un objet = un mot (glossaire).
- [ ] Bon ton : tutoiement élève, vouvoiement adulte, neutre si partagé.
- [ ] Le retour ramène d'où l'on vient ; l'onglet actif est allumé.
- [ ] Geste destructif : confirmation nommée et « Annuler » quand c'est possible.
- [ ] Logo, classe et établissement visibles sur une capture (élève).

### 14. Hors périmètre

- Nouvelles fonctionnalités métier : abonnement Mobile Money, enregistrement de la voix des profs, ciblage par classe des annonces de la direction s'il demande un nouveau port. Elles sont seulement **notées** dans le `journal.md` comme suites possibles.
- Mission Control (`/teams/jobs`).
- Refonte de la homepage publique, au-delà des liens d'aide et d'inscription.

### 15. Ce que tu me rends

Des réponses courtes :
- À chaque étape, seulement le résultat, ce qui bloque et ce que je dois décider.
- À la fin de chaque lot : les captures, la PR ouverte **prête** (pas en brouillon), et la liste des points de l'audit traités, reportés ou écartés, avec la raison en une ligne.
