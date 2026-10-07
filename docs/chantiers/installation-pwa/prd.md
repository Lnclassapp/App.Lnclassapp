# PRD — Installer Lnclass sur le téléphone (PWA)

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Lnclass ne vit que dans un onglet du navigateur : pas d'icône sur le téléphone, et la fiche d'application du site est celle du générateur (« AppLnclassapp », rouge). Ce chantier rend le site **installable** : icône et nom « Lnclass », ouverture en plein écran, page « Pas de connexion » propre à Lnclass, bandeau d'invitation pour les élèves et les enseignants sur téléphone, et un indicateur d'usage dans le pilotage de l'équipe. Les exercices hors ligne sont un chantier distinct, `eleve-hors-ligne`, qui suivra ([memo](memo.md), question 10).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur non connecté | Installer par le menu de son navigateur ; voir la page « Pas de connexion » | Voir le bandeau d'installation |
| Student | Installer depuis le bandeau (Android) ou suivre le mode d'emploi (iPhone) ; reporter le bandeau de 3 jours ; ouvrir Lnclass depuis l'icône | Faire un exercice sans réseau (chantier `eleve-hors-ligne`) ; retrouver une page de compte sans réseau |
| Teacher | Les mêmes gestes que l'élève | Les mêmes limites |
| SchoolStaff (direction) | Installer par le menu du navigateur | Voir le bandeau |
| Team | Installer par le menu du navigateur ; lire dans son pilotage le nombre d'élèves et d'enseignants qui ont ouvert l'app installée sur la période | Voir le bandeau |

Règles d'autorisation : la fiche d'application, le programme d'arrière-plan et la page « Pas de connexion » sont **publics** (aucune donnée de compte). Le bandeau est rendu par le shell pour les rôles `student` et `teacher` seulement. L'indicateur suit la règle d'accès du pilotage existant (espace équipe, ADR-0062) : aucune policy nouvelle.

## 3. Parcours utilisateur

### Chemin nominal — Android

1. Awa, élève, se connecte sur Chrome Android. Le navigateur annonce que le site est installable.
2. Un bandeau apparaît au-dessus de la barre de navigation basse : « Installe Lnclass sur ton téléphone » avec « Installer » et « Plus tard ».
3. Awa touche « Installer » : la fenêtre d'installation du navigateur s'ouvre ; elle accepte. Le bandeau disparaît.
4. L'icône « Lnclass » (le baobab sur fond bleu) est sur son écran d'accueil. En la touchant, Lnclass s'ouvre en plein écran, sans barre d'adresse, sur son accueil.
5. Le serveur note qu'Awa a ouvert Lnclass depuis l'app installée ; l'équipe la compte dans son pilotage.

### Chemin nominal — iPhone

1. Un enseignant connecté sur Safari iPhone voit le bandeau avec le mode d'emploi : « 1. Touchez Partager. 2. Puis « Sur l'écran d'accueil ». » et « Plus tard ».
2. Il suit les deux étapes. En ouvrant Lnclass depuis l'icône, il ne voit plus jamais le bandeau dans l'app installée.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Sans réseau, on ouvre Lnclass ou on change de page | La page « Pas de connexion » de Lnclass s'affiche à la place de l'erreur du navigateur ; « Réessayer » recharge la page demandée |
| « Plus tard » | Le bandeau disparaît et ne revient pas sur ce téléphone avant 3 jours |
| Stockage du navigateur absent ou vidé (navigation privée) | Le bandeau peut réapparaître ; aucune erreur |
| L'utilisateur refuse dans la fenêtre d'installation d'Android | Le bandeau se comporte comme « Plus tard » |
| Navigateur qui ne sait pas installer (WebView de Facebook ou WhatsApp, ancien Chrome) | Aucun bandeau ; le site marche comme avant |
| App déjà installée, ouverte depuis l'icône | Aucun bandeau |
| Écran large (ordinateur) | Aucun bandeau |
| Direction, équipe, page publique | Aucun bandeau |
| Ouverture depuis l'icône sans être connecté | Page de connexion ; aucune ouverture comptée tant qu'aucun compte n'est connecté |
| Une page de compte a été vue, puis le réseau tombe | Rien de cette page n'est servi depuis le téléphone : page « Pas de connexion » |

## 4. Critères d'acceptation

```gherkin
# CA-1 — Fiche d'application
Étant donné un visiteur non connecté
Quand il demande la fiche d'application du site
Alors il reçoit un manifeste JSON nommé « Lnclass », en français, affiché en plein écran
Et son adresse de départ est « /?source=app » et sa portée « / »
Et il déclare une icône de 192 px, une de 512 px et une icône « maskable » de 512 px, toutes servies en PNG
Et chaque page du site déclare ce manifeste dans son en-tête

# CA-2 — Programme d'arrière-plan
Étant donné un visiteur non connecté
Quand il demande « /service-worker.js »
Alors il reçoit du JavaScript dont l'en-tête « Cache-Control » interdit de le resservir sans revalidation (« no-cache », ou « max-age=0 » avec « must-revalidate »)
Et la page enregistre ce programme à la portée « / »

# CA-3 — Page « Pas de connexion »
Étant donné un élève connecté dont le navigateur a enregistré le programme d'arrière-plan
Quand le réseau est coupé et qu'il ouvre une autre page de Lnclass
Alors il voit le titre « Pas de connexion » et un lien « Réessayer »
Et la page ne contient ni son nom ni aucune donnée de son compte

# CA-4 — Aucune page de compte gardée sur le téléphone
Étant donné un élève connecté qui a vu son accueil
Quand le réseau est coupé et qu'il revient sur son accueil
Alors il voit la page « Pas de connexion », pas son accueil
Et le stockage du programme d'arrière-plan ne contient que la page « Pas de connexion », sa feuille de style et le logo

# CA-5 — Bandeau Android, élève et enseignant
Étant donné un élève connecté sur un téléphone Android dont le navigateur annonce que le site est installable
Quand il ouvre son accueil
Alors il voit le bandeau « Installe Lnclass sur ton téléphone » avec « Installer » et « Plus tard »
Et quand il touche « Installer », la fenêtre d'installation du navigateur s'ouvre

# CA-6 — « Plus tard » pendant 3 jours, sur ce téléphone
Étant donné un enseignant qui a touché « Plus tard » sur le bandeau
Quand il revient 2 jours plus tard sur le même téléphone
Alors il ne voit pas le bandeau
Et quand il revient 4 jours après « Plus tard », il voit le bandeau
Et aucune requête n'a été envoyée au serveur pour retenir ce choix

# CA-7 — Mode d'emploi iPhone
Étant donné un élève connecté sur Safari iPhone, hors de l'app installée
Quand il ouvre son accueil
Alors il voit le bandeau avec les deux étapes « Partager » puis « Sur l'écran d'accueil »
Et le bandeau n'a pas de bouton « Installer »

# CA-8 — Jamais de bandeau dans l'app installée
Étant donné un élève qui ouvre Lnclass depuis l'icône installée (mode plein écran)
Quand son accueil s'affiche
Alors il ne voit pas le bandeau

# CA-9 — Jamais de bandeau pour les autres
Étant donné un compte direction, puis un compte équipe, puis un visiteur sur la page d'accueil publique
Quand chacun ouvre sa page sur un téléphone Android dont le navigateur annonce que le site est installable
Alors aucun ne voit le bandeau
Et le HTML servi à la direction et à l'équipe ne contient pas le bandeau

# CA-10 — Ouverture depuis l'icône comptée
Étant donné un élève connecté
Quand il ouvre « /?source=app »
Alors son compte est marqué « ouvert depuis l'app installée » à l'heure du serveur
Et il est redirigé vers son accueil comme depuis « / »
Et un visiteur non connecté qui ouvre « /?source=app » voit la page d'accueil publique, sans rien marquer

# CA-11 — Indicateur du pilotage
Étant donné que 3 élèves et 1 enseignant ont ouvert l'app installée depuis le début de la période, 1 élève avant, et 1 élève anonymisé pendant la période
Quand un membre de l'équipe ouvre son pilotage sur cette période
Alors il lit « 3 élèves » et « 1 enseignant » dans la tuile « Ouvert depuis l'app installée »
Et un compte direction qui ouvre le pilotage de l'équipe est refusé comme aujourd'hui
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Use case `Identity::RecordAppOpen` (pose l'heure d'ouverture depuis l'app sur le compte de l'acteur) ; nouvelle méthode du port `UserRepositoryPort` |
| Infrastructure | Migration : colonne `users.app_opened_at` (datetime, nulle) ; méthode du `UserRepository` ; le pilotage (`TeamDashboardQuery`) compte les comptes non anonymisés par rôle dont `app_opened_at` tombe dans la période |
| Delivery | Routes `GET /manifest.json` et `GET /service-worker.js` (contrôleur PWA de Rails) ; `HomepageController#index` appelle le use case quand `source=app` et qu'un compte est connecté |
| UI | Manifeste et programme d'arrière-plan réécrits ; page statique `offline.html` et sa feuille ; icônes 192, 512 et « maskable » ; balise du manifeste dans le layout ; enregistrement du programme dans le JavaScript d'entrée ; partial du bandeau dans le shell et son contrôleur Stimulus ; tuile du pilotage ; clés `fr.yml` |

## 6. Décisions rattachées

- [ADR-0082](../../decisions/adr/0082-application-installable-sans-page-de-compte-sur-le-telephone.md) — Application installable : réseau seul pour les pages, seule la page « Pas de connexion » est gardée sur le téléphone ; ouverture depuis l'app notée sur le compte. Amende l'ADR-0070 (la PWA passe avant les apps Android) et l'ADR-0062 (un indicateur de plus).
- [UDR-0078](../../decisions/udr/0078-bandeau-d-installation-et-page-pas-de-connexion.md) — Bandeau d'installation (Android et iPhone), page « Pas de connexion », tuile du pilotage. Amende l'UDR-0006 (le shell porte le bandeau) et l'UDR-0049 (une tuile de plus).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Poids ajouté au JavaScript d'entrée (compressé) | — | ≤ 2 Ko (budget de l'ADR-0051) | |
| Requêtes SQL ajoutées à une page élève ou enseignant | — | 0 (le bandeau ne lit rien sur le serveur) | |
| Écritures en base à l'ouverture depuis l'icône | — | 1 au plus | |
| Score « Installable » de Lighthouse (Chrome) | non installable | installable | |
