# Journal — Accueil élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Un seul chantier pour le dessin, l'exercice du jour, « fait seul » et l'invitation de l'enseignant | Choix du porteur, après avoir d'abord séparé | Non |
| 2026-10-15 | Exercice du jour calculé à la lecture, « fait seul » = session terminée sans assignation | Aucune migration, aucune écriture sur une page de lecture | ADR-0089 |
| 2026-10-15 | Placement de « fait seul », texte de l'invitation et icônes maison | Proposés par défaut, confirmés par le porteur | UDR-0084 §3.7, ADR-0089 §4.3 |
| 2026-10-15 | Carte « Ma classe » : `brand-strong` plein jusqu'à 60 %, le dégradé vers `brand` seulement dans le coin du bouton | Le texte blanc sur `brand` ne passe pas AA ; il reste sur `brand-strong` | Non (UDR-0084 §3.8) |
| 2026-10-15 | En sombre, la carte « Ma classe » est bleu clair | Pas de nouveau token : le thème sombre redéfinit déjà `brand-strong` en clair | Non |
| 2026-10-15 | CA-11 (priorité stricte) prouvé au niveau du contrôleur, pas en système | Le budget de 15 s des tests système ; le contrôleur prouve aussi que la query du jour n'est pas lue | Non |
| 2026-10-15 | La clé de cache de `DirectionHomeQuery` porte la date (v2) | La fenêtre de « fait seul » finit aujourd'hui : l'entrée de la veille ne doit pas servir après minuit | Non (ADR-0089 §4.2) |
| 2026-10-15 | `DailyExerciseQuery` lit encore `StudentHomeQuery::SUBJECT_ORDER` | L'ordre des matières a sa place dans le chantier `cours-eleve` ; il sera déplacé là | Non |
| 2026-10-15 | Lot E : le sous-titre de « À faire » devient « Ce qui t'attend aujourd'hui » quand la carte du jour s'affiche | « Les exercices assignés à ta classe » est faux pour un exercice proposé par Lnclass | Non |
| 2026-10-15 | Lot E : la page en cours garde `bg-brand-soft` au focus dans le menu de l'avatar, avec un anneau inset au focus clavier | Le gris de focus de `ui-menu-item-default` effaçait la surbrillance à l'ouverture | Non |
| 2026-10-15 | Lot E : l'avatar de l'élève dans le menu de gauche (≥ 1 024 px) prend la couleur de l'en-tête (graine `public_id`) | Le passage en navigateur a montré deux couleurs pour le même élève (violet à gauche, orange en haut) | Non (UDR-0084 §3.4) |
| 2026-10-15 | Une remédiation terminée aujourd'hui ne met pas la carte en « Bravo, à demain ! » (`kind: "standard"`, comme « fait seul ») ; tests de portée de `DailyExerciseQuery` (autre niveau, autre série, classe quittée, archivée) | Revues `silent-failure-hunter` et `security-reviewer` de la PR | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le dégradé de la maquette (`brand-strong` → `brand` sur toute la carte) cassait le contraste AA du texte blanc : refait au Lot B en aplat jusqu'à 60 %. La toile dessinait sans vérifier le contraste.
- Les lots ont laissé trois petites erreurs, corrigées au Lot E : l'en-tête HITL de `/students/menu` disait encore que le web y mène par l'avatar, le sous-titre de « À faire » parlait d'exercices assignés au-dessus de l'exercice du jour, et la page en cours perdait sa surbrillance au focus.
- `checkVisibility()` (Lot A, flèches du menu qui sautent les entrées cachées) n'existe pas avant Safari 17.4 : sur un vieil iPhone, l'ouverture du menu levait une erreur et le clavier ne marchait plus dans aucun menu déroulant. Remplacé au Lot E par `getClientRects().length`, connu partout.
- Le Lot 0 a donné à l'avatar une couleur tirée du `public_id`, mais seuls l'en-tête et le menu l'ont reçue : le menu de gauche gardait la couleur tirée du nom. Aucun test ne comparait les deux ; seul le passage en navigateur du Lot E l'a vu.
- Sous charge (load average ≈ 40, d'autres sessions sur la machine), `bin/ci` a fait tomber 21 tests système et 2 tests chronométrés ; rejoués seuls, il n'en reste que 5, tous déjà rouges sur `Develop`. Un verdict de `bin/ci` sur une machine chargée ne se lit pas sans relance.
- Les sous-agents de revue n'étaient pas disponibles dans la session du Lot E (pas d'outil Agent) : la revue a suivi leurs consignes (`.claude/agents/*.md`) à la main.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `StartExerciseSession` rattache toute session à l'assignation active de l'exercice dans la classe principale (ADR-0048), quelle que soit la page de départ : `classroom_assignment_id IS NULL` veut dire « pas donné au démarrage », pas « parti du catalogue ».
- Aucune colonne n'enregistre l'origine d'une session ; les comptes de l'enseignant et de la direction filtrent tous sur `classroom_assignment_id`.
- `StudentHomeQuery` calcule `recent_sessions` à chaque affichage alors que seul le cadre lazy le lit.
- Les cours n'ont pas de position : l'ordre « du programme » est celui du catalogue (niveau, nom du cours), puis `essentials.position` et `exercises.position`.
- Ni le casque d'aide ni la porte ouverte n'existent dans Heroicons.
- `ui-menu-item-default` pose `focus:bg-mist` : une entrée qui doit garder une autre couleur au focus ne doit pas prendre cette classe, l'ordre des utilitaires de Tailwind v4 ne garantit pas qu'une seconde classe `focus:` gagne.
- `StudentHomeQuery#assigned_exercises` garde les exercices donnés déjà faits (en fin de liste) : un élève qui a tout rendu ne revoit pas l'exercice du jour tant que l'assignation est active (ADR-0089 §4.1, « Affichage »).
- Sans `recent_sessions` dans la page (Lot B), `GET /students` coûte 19 requêtes avec un exercice donné (20 avant) et 16 sans (16 avant, la query du jour comprise).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Au téléphone, le toast « Connecté » couvre l'avatar juste après la connexion | Hors du dessin de l'accueil ; le toast part seul après 5 s | À ouvrir (shell) |
| Le chiffre « Faits seul (7 j) » de la direction n'est prouvé que par un test de contrôleur et un test de query, sans test système | Budget des tests système | À ouvrir |
| Tests système rouges sur `Develop` avant ce chantier : `identity/sign_in_test.rb:106`, `team_invitation_test.rb:62`, `finitions/public_pages_test.rb:79` et `:97`, et `teams/staff_invitation_test.rb:50` (même cause que `team_invitation` : le numéro prérempli n'est pas mis en forme) | Sans lien avec l'accueil élève | À ouvrir |
| Au téléphone, la pastille « + » de l'avatar (16 px sur 32 px) cache la seconde initiale | Tailles de l'UDR-0084 §3.4 ; à revoir au dessin | À trancher |
| L'exercice du jour ne revient pas quand tout le travail donné est fait mais encore actif (ADR-0089 §4.1 « Affichage » est plus strict que le memo) | Décision de l'ADR, à reconfirmer avec le porteur | À trancher |
| `SUBJECT_ORDER` vit dans `StudentHomeQuery` et sert aussi à `DailyExerciseQuery` | Sa place est le catalogue de l'élève | `cours-eleve` |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-15 |
| **PR** | *(ouverte à la clôture)* |
| **ADR produits** | [ADR-0089](../../decisions/adr/0089-exercice-du-jour-calcule-a-la-lecture-et-fait-seul-deduit.md) |
| **UDR produits** | [UDR-0084](../../decisions/udr/0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) |
