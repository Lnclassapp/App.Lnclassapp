# PRD — Fiches de cours à l'identique des maquettes

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Issue de suivi : #318. Référence de design : [`docs/design/fiches-cours/`](../../design/fiches-cours/README.md).

## 1. Contexte

Le contenu d'une leçon n'est qu'un texte mis en forme ; le porteur a décidé le 2026-10-27 que les 3 fiches maquettées (Thalès, Lentilles, Texte argumentatif) deviennent le cahier des charges, au pixel près. Le chantier livre la fiche de cours d'une leçon : un document de blocs importé ([ADR-XXXX](../../decisions/adr/XXXX-fiche-de-cours-en-donnees-importees.md)), rendu dans l'habillage des maquettes ([UDR-XXXX](../../decisions/udr/XXXX-fiche-de-cours-a-l-identique-des-maquettes.md)), avec ses figures, ses exercices corrigés dans la page, « Je m'entraîne » et la rédaction libre. Les 3 fiches sont livrées en données et importées.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Équipe (admin ou contenu) | importer une fiche de cours ; lire la fiche d'une leçon en brouillon ou publiée | importer une fiche pour une leçon absente ; remplacer une fiche existante |
| Élève | lire la fiche d'une leçon publiée de son niveau ; faire les exercices, « Je m'entraîne », la rédaction | lire une leçon en brouillon ou archivée ; garder une note (rien n'est enregistré) |
| Enseignant | lire la fiche d'une leçon publiée, la projeter | importer |

Règles : import par `Policies::Catalog::ManageContentPolicy` (comme `ImportEssentials`) ; lecture par `Policies::Catalog::ReadPublishedPolicy` (comme la fiche essentielle).

## 3. Parcours utilisateur

### Chemin nominal

1. L'équipe envoie `thales.json` (format `lnclass.course-sheet` v1, `course` = slug de la leçon) sur l'écran d'import existant.
2. Le rapport d'import compte 1 fiche importée.
3. L'élève ouvre la leçon publiée, puis « Fiche de cours » *(nom en attente du porteur)*.
4. Il lit les 3 pages : Seyès, thème bleu et rouge, Kalam et Source Serif 4.
5. Il touche « sécantes » : la bulle du lexique s'ouvre, avec la définition et l'exemple. Il fait défiler : elle se ferme.
6. Il bascule « Explications simples : non » : les reformulations disparaissent.
7. Il déplace M sur la figure : configuration, longueurs et rapports se mettent à jour ; « Libérer N » permet de tester la réciproque.
8. Exercice 4 : il tape « 3,6 » et « 4.2 », touche « Vérifier » : « juste » sous chaque champ, « Tout est juste, bravo ! ».
9. « Je m'entraîne » : il répond, appuie sur Entrée, le score passe à 1 / 1 ; « Nouvel exercice » tire un autre énoncé.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Fichier mal formé, `kind` inconnu, HTML dans une chaîne, URL, paramètre hors bornes, fichier > 1 Mo | Fichier refusé entier ; le rapport nomme page, section, position et raison |
| Mot `[[clé|…]]` absent du lexique, ou clé définie deux fois | Fichier refusé avec la raison |
| Leçon inconnue | Fichier refusé (`unknown_target`) |
| La leçon a déjà une fiche de cours | Ignorée, comptée « ignorée », rien n'est modifié |
| Élève sur une leçon en brouillon | Refus, comme pour une fiche essentielle |
| Leçon sans fiche de cours | Pas de lien « Fiche de cours » sur la leçon ; l'adresse directe répond 404 |
| Champ vide puis « Vérifier » | « à compléter » en gris sous le champ |
| Réponse fausse | « à revoir » en rouge ; « Certaines réponses sont à revoir. » |
| « 4,20 », « 4.2 », « 4,2 » pour 4,2 ; 4,21 pour 4,2 | juste (tolérance ±0,011) |
| Même énoncé « Je m'entraîne » vérifié deux fois | Le score ne compte qu'une fois |
| Choix figé (Texte argumentatif, ex. 5) | Le premier clic fige la réponse |
| JavaScript coupé | Texte, encadrés, tableaux et figures fixes se lisent ; les explications simples sont visibles |

## 4. Critères d'acceptation

```gherkin
# CA-1 Import nominal
Étant donné une leçon « la-propriete-de-thales » sans fiche de cours
Quand un membre de l'équipe contenu importe thales.json
Alors la leçon a une fiche de cours au thème « blue » de 3 pages
Et le rapport compte 1 fiche importée

# CA-2 Refus d'un fichier hostile ou mal formé
Étant donné un fichier dont un bloc contient « <script> », ou un kind « inconnu », ou un mot du lexique non défini
Quand il est importé
Alors rien n'est écrit
Et le rapport nomme la page, la section, la position du bloc et la raison

# CA-3 Fiche existante
Étant donné une leçon qui a déjà une fiche de cours
Quand une nouvelle fiche est importée pour elle
Alors la fiche existante est inchangée et le rapport la compte « ignorée »

# CA-4 Permissions
Étant donné un élève
Quand il ouvre la fiche de cours d'une leçon en brouillon
Alors l'accès est refusé
Et un enseignant n'a pas accès à l'import

# CA-5 Lecture
Étant donné une leçon publiée avec sa fiche de cours
Quand un élève l'ouvre
Alors il voit 3 pages « Page 1 », « Page 2 », « Page 3 », les titres de sections numérotés, les encadrés et le texte échappé

# CA-6 Lexique et explications simples
Quand l'élève touche un mot souligné
Alors la bulle affiche son titre, sa définition et son exemple
Et « Lexique » liste tous les mots
Et « Explications simples : non » masque les reformulations

# CA-7 Exercice corrigé
Quand l'élève tape « 3,6 » pour AN et vérifie
Alors « juste » s'affiche sous le champ
Et « 3,62 » est « à revoir », un champ vide « à compléter »
Et « Indice » et « Correction » se déplient

# CA-8 Je m'entraîne
Quand l'élève vérifie un énoncé juste deux fois puis tire un nouvel énoncé
Alors le score affiche « 1 / 1 » puis l'énoncé change

# CA-9 Figure de Thalès
Quand l'élève déplace M en configuration verrouillée
Alors N suit, les trois rapports sont égaux et la configuration s'affiche
Et « Réinitialiser » remet A(70,165), B(360,55), C(345,285), kM = kN = 0,45

# CA-10 Simulateur et construction des lentilles
Quand l'élève déplace l'objet en deçà du foyer
Alors l'image virtuelle est tracée en pointillés et l'application « loupe » s'affiche
Et l'exercice de construction accepte le point image placé juste

# CA-11 Texte argumentatif
Quand l'élève active « thèse » puis touche un segment coloré
Alors les segments de thèse se colorent et l'explication s'affiche
Et la rédaction libre compte connecteurs, mots et paragraphes

# CA-12 Habillage isolé
Alors design_tokens_test refuse toujours une couleur hexadécimale, Kalam ou Source Serif hors des dossiers de la fiche de cours
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Catalog::CourseSheet`, `Entities::Catalog::SheetDocument` (validation des blocs, `kind` fermés, lexique), `Ports::Catalog::CourseSheetRepositoryPort`, `UseCases::Catalog::ImportCourseSheet` (adaptateur `Importer`), `Entities::Catalog::NumericAnswer` (tolérance, côté Ruby pour les tests et le contrôle des fichiers) |
| Infrastructure | migration `course_sheets`, `Orm::CourseSheet`, `Repositories::Catalog::CourseSheetRepository`, `Queries::Catalog::CourseSheetQuery`, schéma `config/schemas/lnclass.course-sheet.v1.json` |
| Delivery | `GET /courses/:course_slug/fiche` → `Catalog::CourseSheetsController#show` |
| UI | `app/views/catalog/course_sheets/` (page, section, un partial par type de bloc, un par `kind`), `app/assets/stylesheets/course_sheet.css`, polices `public/fonts/`, contrôleurs `app/javascript/controllers/course_sheet/` |
| Données | `db/seeds/data/course_sheets/{thales,lentilles,texte-argumentatif}.json` |

## 6. Décisions rattachées

- ADR-XXXX — Fiche de cours en données importées, figures en liste fermée.
- UDR-XXXX — Fiche de cours à l'identique des maquettes (nom à l'écran et téléphone en attente du porteur).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Poids de la fiche Thalès (HTML + CSS + JS + polices, compressé) | — | ≤ 350 Ko | |
| Requêtes SQL de l'écran | — | ≤ 5 | |
