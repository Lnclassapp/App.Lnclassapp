# PRD — Accueil de la direction : établissement, niveaux, annonces, activité

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

La direction arrive aujourd'hui sur un tableau unique « Travail des élèves », qui aligne toutes les classes de l'établissement sans rien signaler ni rien hiérarchiser. Le porteur veut une page d'arrivée en quatre sections : une carte « Établissement » (chiffres et alertes), des bulles « Niveaux » qui mènent chacune aux cartes des classes du niveau, marquées d'une pastille rouge, jaune ou verte selon le taux de rendu, le carrousel « Annonces » de l'élève, et une « Activité récente ». Les annonces viennent du chantier `annonces`, que ce chantier affiche sans le construire ([memo](memo.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Direction (SchoolStaff, `school_admin`) rattachée | Lire l'accueil, la page de chacun de ses niveaux, l'activité récente de son établissement, et le carrousel des annonces qu'elle lit (sans les masquer) | Lire un autre établissement ; écrire quoi que ce soit de nouveau depuis ces pages ; rédiger une annonce |
| Équipe (Team) | — | Ouvrir les pages de la direction : 403 (inchangé) |
| Enseignant, Élève | — | Ouvrir les pages de la direction : 403 (inchangé) |
| Parent | — | N'existe pas dans l'application |

Règle d'autorisation : `Policies::School::ReadOwnSchoolPolicy` dans `SchoolAdmin::BaseController` (inchangée). L'établissement lu est **toujours** `current_actor.school_id`, jamais un paramètre (ADR-0065). Le masquage d'une annonce suit `Policies::Communication::DismissPolicy`, propriété du chantier `annonces`.

## 3. Parcours utilisateur

### Chemin nominal

1. Mme Kamaté, direction du Lycée moderne de Cocody, se connecte : elle arrive sur « Accueil » (`/school-admin/classrooms`).
2. La carte « Établissement » donne le nom, le type et l'année, puis « 24 classes · 1 032 élèves · 31 enseignants », puis deux alertes : « 2 classes sans enseignant : 2nde A 3, Tle A1 2 » et « 3 classes rendent moins de 40 % des devoirs : 3ème 2, 4ème 1, 6ème 5 ».
3. La section « Niveaux » montre sept bulles, de la 6ème à la Tle, chacune avec son illustration ; la bulle « 3ème » porte une pastille jaune.
4. Elle touche « 3ème » : la page « 3ème » affiche une carte par classe de 3ème, avec l'illustration du niveau, une pastille par classe, l'effectif, les devoirs donnés, le taux de rendu et la moyenne. La « 3ème 2 » a une pastille rouge (« Taux de rendu : 31 % »).
5. Elle ouvre la « 3ème 2 » : la page de la classe (inchangée) liste ses élèves ; son retour mène à « 3ème ».
6. Revenue à l'accueil, elle lit le carrousel « Annonces » (annonces de l'équipe Lnclass et des directions de son établissement), sans croix ; « Toutes les annonces » mène à la page « Annonces ».
7. Plus bas, « Activité récente » se charge : « Aujourd'hui · 10:42 — M. Kouassi a donné « Les fractions » à 3ème 2 », « Hier · 16:05 — Awa K. a rejoint 6ème 1 ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucune classe active cette année | « Établissement » : « 0 classe » et ses alertes ; « Niveaux » : état vide « Aucune classe cette année » et lien « Voir l'établissement » |
| Rien à signaler | La carte « Établissement » dit « Rien à signaler » à la place des alertes |
| Établissement non actif | Alerte en tête : « Votre établissement n'est pas actif : les enseignants ne peuvent pas s'y inscrire. » ; tout le reste se lit |
| Classe sans élève ou sans devoir | Pas de pastille ; « Aucun élève » ou « Aucun devoir donné » sur sa carte |
| `/school-admin/levels/<slug>` d'un niveau sans classe active de l'établissement, ou slug inconnu | 404 |
| Une autre direction, l'équipe, un enseignant, un élève | 403 sur toutes les nouvelles adresses (règle du `BaseController`) |
| Aucune annonce lisible | Pas de section « Annonces » |
| Aucune activité depuis 30 jours | « Rien de nouveau ces 30 derniers jours » |
| Le frame de l'activité répond une erreur | État d'erreur commun dans le frame, avec « Réessayer » ; le reste de la page reste affiché |

## 4. Critères d'acceptation

Chaque critère devient au moins un test. Identifiants `AD-NN`.

### Signal (domaine)

```gherkin
# AD-01
Étant donné un taux de rendu de 70 %, 85 % ou 100 %
Alors le signal est « vert »
Étant donné un taux de rendu de 40 % ou 69 %
Alors le signal est « jaune »
Étant donné un taux de rendu de 0 % ou 39 %
Alors le signal est « rouge »
Étant donné un taux non calculé (aucun élève ou aucun devoir)
Alors il n'y a pas de signal
```

### Accueil — carte « Établissement »

```gherkin
# AD-02
Étant donné un établissement de 3 classes actives de l'année, dont un élève inscrit dans deux d'entre elles,
  et une classe archivée
Quand la direction ouvre l'accueil
Alors la carte « Établissement » affiche son nom, son type et l'année scolaire
Et elle compte 3 classes, chaque élève présent une seule fois, et autant d'enseignants que la page « Enseignants »

# AD-03
Étant donné une classe sans enseignant déclaré, une classe sans élève, une classe dont le taux de rendu est 31 %,
  et un enseignant sans classe
Quand la direction ouvre l'accueil
Alors la carte affiche quatre alertes, dans l'ordre : sans enseignant, sans élève, signal rouge, enseignants sans classe
Et chaque alerte nomme ses classes (trois au plus, puis « et N autres »)
Et l'alerte « enseignants sans classe » mène à la page « Enseignants »

# AD-04
Étant donné un établissement non actif
Quand la direction ouvre l'accueil
Alors la première alerte dit que l'établissement n'est pas actif et mène à la page « Établissement »

# AD-05
Étant donné un établissement sans aucune alerte
Quand la direction ouvre l'accueil
Alors la carte dit « Rien à signaler »
Et son pied propose « Voir l'établissement » et « Anciens élèves »
```

### Accueil — « Niveaux »

```gherkin
# AD-06
Étant donné un établissement qui a des classes actives en 6ème, en 3ème et en Tle (séries C et D)
Quand la direction ouvre l'accueil
Alors « Niveaux » affiche trois bulles, dans l'ordre 6ème, 3ème, Tle, chacune avec l'illustration de son niveau
Et la bulle « Tle » mène à la page du niveau Tle, qui liste les classes des deux séries

# AD-07
Étant donné que les classes de 3ème ont, ensemble, rendu 55 % des devoirs attendus
Quand la direction ouvre l'accueil
Alors la bulle « 3ème » porte une pastille jaune
Et son nom accessible dit le nombre de classes, le taux de rendu et le signal

# AD-08
Étant donné un établissement sans classe active cette année
Quand la direction ouvre l'accueil
Alors « Niveaux » affiche « Aucune classe cette année » et un lien vers « Établissement »
```

### Page d'un niveau

```gherkin
# AD-09
Étant donné les classes 3ème 1 (taux 82 %), 3ème 2 (taux 31 %) et 3ème 3 (aucun devoir)
Quand la direction ouvre la page « 3ème »
Alors elle voit trois cartes triées par nom, chacune avec l'illustration du niveau
Et 3ème 1 porte une pastille verte, 3ème 2 une pastille rouge, 3ème 3 aucune pastille et « Aucun devoir donné »
Et chaque carte affiche l'effectif, les devoirs donnés, le taux de rendu et la moyenne (« — » sous 5 élèves ayant rendu)
Et chaque carte mène à la page de sa classe
Et une légende explique les trois couleurs

# AD-10
Étant donné une classe de 3ème d'un autre établissement, archivée, ou d'une autre année
Quand la direction ouvre la page « 3ème »
Alors cette classe n'y figure pas

# AD-11
Étant donné un niveau sans classe active dans l'établissement de la direction, ou un slug inconnu
Quand la direction ouvre l'adresse de ce niveau
Alors elle reçoit 404

# AD-12
Étant donné un compte de l'équipe, d'un enseignant ou d'un élève
Quand il ouvre la page d'un niveau ou l'activité de la direction
Alors il reçoit 403

# AD-13
Étant donné la page de la classe 3ème 2
Quand la direction suit son lien de retour
Alors elle arrive sur la page « 3ème »
```

### Annonces

```gherkin
# AD-14
Étant donné deux annonces de l'équipe publiées, l'une nationale, l'autre pour l'établissement de la direction,
  et une annonce pour un autre établissement
Quand la direction ouvre l'accueil
Alors le carrousel « Annonces », entre « Niveaux » et « Activité récente », affiche les deux premières, et pas la troisième
Et aucune carte ne porte de croix « Masquer »

# AD-15
Étant donné une annonce affichée dans le carrousel de la direction
Quand une demande de masquage est forgée par la direction
Alors elle est refusée (403) et rien n'est enregistré

# AD-16
Étant donné qu'aucune annonce n'est lisible par la direction
Quand elle ouvre l'accueil
Alors la section « Annonces » est absente
```

### Activité récente

```gherkin
# AD-17
Étant donné, dans les 30 derniers jours, un devoir donné par M. Kouassi à 3ème 2, l'arrivée d'Awa Koné en 6ème 1
  et l'arrivée d'un enseignant dans l'établissement
Quand la direction ouvre l'accueil
Alors « Activité récente » se charge en différé
Et affiche les trois événements, du plus récent au plus ancien, groupés par jour
Et l'élève est nommé « Awa K. »

# AD-18
Étant donné 12 événements dans les 30 derniers jours, un événement vieux de 31 jours,
  et des événements d'un autre établissement
Quand la direction ouvre l'activité
Alors elle voit les 10 plus récents, et ni le plus vieux ni ceux de l'autre établissement

# AD-19
Étant donné aucun événement dans les 30 derniers jours
Quand la direction ouvre l'activité
Alors elle lit « Rien de nouveau ces 30 derniers jours »
```

### Temps de lecture (ADR-0065, amendement du 2026-10-04)

```gherkin
# AD-23
Étant donné l'accueil d'un établissement lu une première fois
Quand la direction, ou une autre direction du même établissement, l'ouvre de nouveau dans les 5 minutes
Alors ses chiffres, ses alertes et ses pastilles sont relus sans requête
Et une classe déclarée entre-temps n'y apparaît qu'après 5 minutes
Et un autre établissement ne lit jamais cette entrée
Et le bandeau d'arrivée, l'activité, la page d'un niveau et celle d'une classe restent lus en direct
```

### Navigation et accessibilité

```gherkin
# AD-20
Étant donné une direction connectée
Alors la première entrée de sa navigation est « Accueil » (icône maison) vers /school-admin/classrooms
Et elle est active sur l'accueil, sur la page d'un niveau et sur la page d'une classe

# AD-21
Étant donné un téléphone de 375 px de large
Quand la direction ouvre l'accueil puis la page d'un niveau
Alors aucune page ne défile en largeur, et chaque bulle et chaque carte est une cible d'au moins 48 px

# AD-22
Étant donné l'accueil et la page d'un niveau
Alors chaque pastille a un équivalent texte (nom accessible de la bulle, texte de la carte, légende)
Et la page n'a qu'un titre h1
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::School::WorkSignal` (seuils 70/40, `for(rate)`) ; `Entities::School::DirectionAlerts` (quelles alertes, dans quel ordre, trois noms au plus). Aucun port, aucun use case : lecture seule (CQRS). |
| Infrastructure | `Queries::School::StudentWorkQuery` : `ClassroomRow` gagne `level_slug` et `submitted_count` ; nouvelle méthode `level(school_id:, slug:)`. Nouvelles queries `Queries::School::DirectionHomeQuery` (carte et bulles) et `Queries::School::SchoolActivityQuery` (événements). Aucune migration. |
| Delivery | `SchoolAdmin::ClassroomsController#index` (accueil) ; `SchoolAdmin::LevelsController#show` ; `SchoolAdmin::ActivitiesController#show` (frame différé) ; routes `levels/:slug` et `activity`. |
| UI | `school_admin/classrooms/index` réécrit (`_school_card`, `_levels`), `school_admin/levels/show` (`_classroom_card`), `school_admin/activities/_activity` ; `ui_subject_bubble(signal:)` ; illustrations de niveau ; tokens `signal-*` ; navigation « Accueil ». Carrousel : partial du chantier `annonces`, réutilisé tel quel. |

## 6. Décisions rattachées

- **ADR-0065, amendement du 2026-10-04** — l'accueil de la direction est gardé 5 minutes (AD-23), sur la mesure du budget de l'ADR-0067.
- **UDR-0074** — Accueil de la direction : établissement, niveaux, annonces, activité. Amende l'UDR-0052 (§2.1 « pas d'accueil », §2.2 « des tableaux, pas des cartes ») et l'UDR-0006 (navigation `school_admin`).
- **Pas de nouvel ADR** : aucun port, aucune table, aucune dépendance, aucun contrat de use case ne bouge ; le chantier n'ajoute que des lectures (queries) et deux règles de domaine pures. La seule stratégie de persistance nouvelle (le cache de l'accueil) amende l'ADR-0065. L'ADR-0065 (définitions du travail des élèves) est appliqué tel quel ; la seule écriture touchée (masquer une annonce) appartient au chantier `annonces` et à son ADR-0078.
- **Dépendance externe** : chantier `annonces`, mergé dans `Develop` le 2026-10-04 (PR #162) **sans** la décision D-A1. Décision du porteur du même jour : le carrousel de la direction est en lecture seule, sans croix ; D-A1 relève d'un chantier à part.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL de l'accueil (hors frame différé), quel que soit le nombre de classes | 5 (tableau) | nombre fixe, ≤ 12, identique pour 3 et 30 classes | **11** pour 3, 12 et 30 classes (10 accueil + 1 bandeau d'arrivée) ; + 3 d'authentification et 2 de navigation, communes à toute page — challenger, phase 5 |
| Requêtes SQL de la page d'un niveau | — | nombre fixe, ≤ 6 | **4** au challenger ; **5** depuis le décompte des élèves distincts (O1) — test de comptage constant |
| Requêtes SQL du frame d'activité | — | nombre fixe, ≤ 4 | **3**, de 0 à 10 événements — challenger, phase 5 |
| Temps serveur de l'accueil (`test/performance/school/heavy_screens_budget_test.rb`, p95 des queries, ADR-0067) | « Travail des élèves » : 92,6 ms sur `Develop`, même machine | < 100 ms | Sans cache : 138 à 152 ms (mesure alternée : ancienne page 89,6 ms en médiane, accueil 110,8 ms). **Décision du porteur : 5 minutes de cache** (ADR-0065, amendement du 2026-10-04) → **0,1 ms à chaud** (cache mémoire du test ; une lecture Solid Cache en production), **123 ms à froid**, une fois toutes les 5 minutes par établissement |
