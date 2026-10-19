# PRD — Des images dans les fiches de cours

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Les fiches essentielles et les questions d'exercice sont en texte seul : l'éditeur et l'import retirent toute image (ADR-0051, ADR-0074 moteur 2). Pour les notions qui passent par un dessin (circuit, figure, schéma), l'élève qui révise seul sur son téléphone ne comprend pas. On ouvre les fiches et les questions aux images PNG, JPEG et WebP produites hors de l'application (Claude Design), décrites par l'import, envoyées et relues par l'équipe, et exigées avant publication (voir [memo](memo.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team `admin`, `content` | Envoyer, remplacer, retirer une image dans une fiche (à n'importe quel endroit du texte) ou en tête d'une question ; écrire son texte de remplacement ; retirer l'emplacement décrit d'une fiche ou la description d'image d'une question ; voir les images d'un brouillon | Publier une fiche ou un exercice dont un emplacement décrit n'est pas rempli, ou dont une image n'a pas de texte de remplacement |
| Team `field` | Voir les images publiées, comme le texte | Envoyer, remplacer ou retirer une image |
| Student | Voir les images des fiches et des questions **publiées** qu'il peut déjà lire (même règle que le texte : son niveau) | Voir une image d'un brouillon ou d'un contenu archivé ; envoyer une image |
| Teacher | Voir les images publiées qu'il peut déjà lire (sa matière, aux niveaux de ses classes) | Envoyer une image |
| SchoolStaff, Parent | Rien de nouveau : ce qu'ils lisent déjà du catalogue, images comprises | Envoyer une image |
| Visiteur non connecté | Rien | Lire une image de cours (adresse refusée, comme la fiche) |

Règles d'autorisation : écriture par `Policies::Catalog::ManageContentPolicy` (fiches et questions) ; lecture d'une image par la règle de lecture de la fiche ou de l'exercice qui la porte (`Policies::Catalog::ReadPublishedPolicy` + niveau de l'élève, comme `Catalog::EssentialsController#show`).

## 3. Parcours utilisateur

### Chemin nominal — fiche

1. L'équipe importe une leçon (`lnclass.course-tree` v1). Le texte d'une fiche contient un ou plusieurs emplacements `[[image: description]]` placés dans un paragraphe seul, là où l'image doit aller.
2. Elle produit chaque image dans Claude Design à partir de la description, et l'exporte en PNG ou WebP.
3. Elle ouvre la fiche en modification. Chaque emplacement est signalé (« Image à insérer : … ») et la fiche affiche « N image(s) à insérer ».
4. Elle place le curseur dans l'emplacement et clique « Insérer une image » : le navigateur réduit l'image (≤ 300 Ko, ≤ 1200 px de côté), l'envoie, et l'image **remplace** l'emplacement. Son texte de remplacement est pré-rempli avec la description.
5. Elle enregistre, puis publie la fiche (ou « Tout publier » sur le cours).
6. L'élève ouvre la fiche : chaque image apparaît à sa place, chargée quand il y arrive en faisant défiler.

### Chemin nominal — question

1. L'import porte, sur une question, `"image": { "description": "…" }`.
2. Dans la modification de l'exercice, la question affiche « Image à insérer : … » avec un bouton « Ajouter l'image ».
3. L'équipe envoie l'image (même réduction) ; le texte de remplacement est pré-rempli avec la description.
4. Elle enregistre et publie l'exercice.
5. En session d'exercice, l'élève voit l'image au-dessus de l'énoncé.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Publier une fiche avec un emplacement `[[image: …]]` restant | Refus 422, la fiche reste en brouillon ; message « Il reste N image(s) à insérer dans cette fiche. » |
| « Tout publier » un cours dont une fiche a un emplacement restant | Refus, rien n'est publié ; le message nomme la fiche |
| Publier une fiche ou un exercice dont une image n'a pas de texte de remplacement | Refus 422 ; le champ de l'image en cause est marqué « À compléter » |
| Publier un exercice dont une question a une description d'image sans image | Refus 422 ; « La question N attend son image. » |
| Fichier > 300 Ko après réduction, d'un autre format, ou contenu ne correspondant pas à son type | Refus à l'envoi, raison affichée dans l'éditeur ; rien n'est stocké |
| Plus de 30 images dans une fiche | Refus à l'envoi : « 30 images au plus par fiche. » |
| L'équipe supprime l'emplacement sans insérer d'image | La fiche redevient publiable (si rien d'autre ne manque) |
| L'équipe retire la description d'image d'une question | La question redevient publiable sans image |
| Image d'une fiche publiée remplacée | L'élève voit la nouvelle ; l'adresse de l'ancienne répond 404 |
| Élève qui demande l'image d'une fiche en brouillon, archivée, ou hors de son niveau | 404, comme la fiche |
| Visiteur non connecté qui demande une image de cours | Renvoi vers la connexion (HTML) ou 401 |
| L'image ne charge pas (réseau) | Le texte de remplacement s'affiche à sa place |
| Session expirée pendant l'envoi | 401 JSON ; l'éditeur affiche « Session expirée, reconnecte-toi. » |
| Image envoyée puis jamais enregistrée (modale fermée) | Purgée après 48 h |
| Import d'un fichier sans aucun champ image (anciennes leçons) | Inchangé : importé comme aujourd'hui |
| Description d'image vide ou > 150 caractères dans l'import | Erreur d'import sur l'élément, avec son chemin JSON |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Images dans les fiches

Scénario: une image insérée à la place d'un emplacement est vue par l'élève
  Étant donné une fiche en brouillon dont le texte contient « [[image: un circuit simple avec une pile et une lampe]] »
  Quand un membre de l'équipe contenu insère une image PNG de 200 Ko à cet emplacement et enregistre
  Alors le texte de la fiche ne contient plus d'emplacement
  Et l'image a pour texte de remplacement « un circuit simple avec une pile et une lampe »
  Quand il publie la fiche et son cours
  Alors un élève du niveau de la fiche voit l'image dans la fiche, avec loading="lazy"

Scénario: un emplacement restant bloque la publication
  Étant donné une fiche en brouillon contenant deux emplacements d'image
  Quand un membre de l'équipe contenu publie la fiche
  Alors la publication est refusée avec « Il reste 2 image(s) à insérer dans cette fiche. »
  Et la fiche reste en brouillon

Scénario: une image sans texte de remplacement bloque la publication
  Étant donné une fiche en brouillon avec une image dont le texte de remplacement est vide
  Quand un membre de l'équipe contenu publie la fiche
  Alors la publication est refusée et le texte de remplacement de cette image est signalé « À compléter »

Scénario: Tout publier refuse un cours dont une fiche n'est pas prête
  Étant donné un cours en brouillon dont une fiche contient un emplacement d'image
  Quand un membre de l'équipe contenu lance « Tout publier » sur le cours
  Alors rien n'est publié
  Et le message nomme la fiche en cause

Scénario: une fiche sans image se publie comme avant
  Étant donné une fiche en brouillon sans emplacement ni image
  Quand un membre de l'équipe contenu publie la fiche
  Alors la fiche est publiée

Scénario: un fichier trop lourd est refusé à l'envoi
  Quand un membre de l'équipe contenu envoie une image de 400 Ko pour une fiche
  Alors l'envoi est refusé avec une raison qui cite 300 Ko
  Et aucune image n'est stockée

Scénario: un fichier déguisé est refusé
  Quand un membre de l'équipe contenu envoie un fichier « schema.png » dont le contenu est un SVG
  Alors l'envoi est refusé
  Et aucune image n'est stockée

Scénario: les métadonnées sont retirées
  Quand un membre de l'équipe contenu envoie une image JPEG portant une position GPS
  Alors l'image stockée ne contient plus aucune métadonnée EXIF

Scénario: le rôle terrain ne peut pas envoyer d'image
  Quand un membre de l'équipe terrain envoie une image pour une fiche
  Alors l'envoi est refusé (403)

Scénario: une image de brouillon n'est pas lisible par un élève
  Étant donné une fiche en brouillon avec une image
  Quand un élève demande l'adresse de cette image
  Alors il reçoit 404

Scénario: une image hors du niveau de l'élève n'est pas lisible
  Étant donné une fiche publiée de 3ème avec une image
  Quand un élève de 6ème demande l'adresse de cette image
  Alors il reçoit 404

Scénario: une image de cours n'est pas lisible sans connexion
  Quand un visiteur non connecté demande l'adresse d'une image de fiche publiée
  Alors il n'obtient pas l'image

Scénario: une image publiée se garde dans le navigateur seulement
  Quand un élève lit une image de fiche publiée
  Alors la réponse porte « Cache-Control: max-age=3600, private » et une revalidation par ETag rejoue la règle de lecture

Scénario: une image remplacée n'est plus servie
  Étant donné une fiche publiée avec une image
  Quand l'équipe remplace cette image et enregistre
  Alors l'adresse de l'ancienne image répond 404
  Et l'élève voit la nouvelle image

Scénario: plus de 30 images par fiche
  Étant donné une fiche qui a déjà 30 images
  Quand un membre de l'équipe contenu envoie une 31e image pour cette fiche
  Alors l'envoi est refusé avec « 30 images au plus par fiche. »

Scénario: une image envoyée et jamais enregistrée est purgée
  Étant donné une image de fiche envoyée il y a 49 heures et citée par aucune fiche
  Quand la purge quotidienne tourne
  Alors l'image et son fichier sont supprimés

Fonctionnalité: Image d'une question

Scénario: l'élève voit l'image au-dessus de l'énoncé
  Étant donné un exercice publié dont une question porte une image avec un texte de remplacement
  Quand un élève de ce niveau répond à cette question en session
  Alors l'image est affichée avant l'énoncé
  Et son attribut alt vaut le texte de remplacement

Scénario: une description d'image sans image bloque la publication de l'exercice
  Étant donné un exercice en brouillon dont la question 2 a une description d'image sans image
  Quand un membre de l'équipe contenu publie l'exercice
  Alors la publication est refusée avec « La question 2 attend son image. »

Scénario: retirer la description rend la question publiable
  Étant donné une question avec une description d'image sans image
  Quand l'équipe retire la description et enregistre
  Alors l'exercice peut être publié

Fonctionnalité: Import

Scénario: l'import garde les emplacements et les descriptions
  Quand l'équipe importe une leçon dont une fiche contient « <p>[[image: une cellule animale]]</p> » et dont une question porte « image: { description: "une pile" } »
  Alors la fiche importée contient l'emplacement
  Et la question importée a la description « une pile » et aucune image

Scénario: une ancienne leçon s'importe comme avant
  Quand l'équipe importe une leçon sans aucun champ image
  Alors l'import réussit sans erreur, comme avant ce chantier

Scénario: une description d'image invalide est refusée
  Quand l'équipe importe une leçon dont une question porte une description d'image vide
  Alors l'import signale une erreur sur cette question, avec son chemin JSON
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Shared::ContentImage` (plafonds : 300 Ko, 1200 px, 30 par fiche, alt 150) ; `Entities::Catalog::EssentialImage` ; `Entities::Catalog::ImageSlot` (lecture des emplacements `[[image: …]]`) ; `Entities::Assessment::Question` gagne `image_description` et `image` ; `Dtos::Shared::ContentImageInput` (vérification par `Entities::Shared::ImageHeader`, retrait des métadonnées) ; ports `Ports::Catalog::EssentialImageStorePort`, `Ports::Assessment::QuestionImageStorePort` ; use cases `UploadEssentialImage`, `ReadEssentialImage`, `UploadQuestionImage`, `ReadQuestionImage` ; `PublishEssential`, `PublishCascade`, `PublishExercise` gagnent leurs conditions |
| Infrastructure | migrations `essential_images`, `question_images`, `questions.image_description` ; `Orm::EssentialImage` (pièce jointe Action Text par sgid, comme `Orm::ArticleImage`), `Orm::QuestionImage` ; `EssentialImageStore`, `QuestionImageStore` ; `RichTextSanitizer` admet les images d'une fiche ; `EssentialRepository` rattache les images citées et leurs alts ; `ContentTreeWriter` et le schéma `lnclass.course-tree.v1.json` portent `image.description` ; job de purge des orphelines |
| Delivery | `Teams::EssentialImagesController#create`, `Teams::QuestionImagesController#create` (JSON, comme `Teams::ArticleImagesController`) ; `Catalog::EssentialImagesController#show`, `Assessment::QuestionImagesController#show` (service sous la règle de lecture, cache privé immuable) ; routes |
| UI | formulaire de fiche (bouton « Insérer une image », emplacements signalés, lignes de texte de remplacement) ; champ image d'une question dans le formulaire d'exercice ; rendu de l'image dans la fiche et dans la carte de question ; `rich_text_editor_controller` en mode images pour les fiches ; prompt de rédaction et `docs/contenus/README.md` mis à jour |

## 6. Décisions rattachées

- [ADR-0105](../../decisions/adr/0105-images-des-fiches-et-des-questions.md) — images des fiches et des questions : tables par contexte, emplacements textuels, plafonds, service sous la règle de lecture, conditions de publication, schéma d'import. Amende ADR-0074 (moteur 2) et ADR-0051.
- [UDR-0129](../../decisions/udr/0129-images-dans-l-editeur-de-fiche-la-question-et-la-lecture.md) — insertion d'une image dans l'éditeur de fiche et de question, emplacements, textes de remplacement, rendu élève.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Poids d'images chargé à l'ouverture d'une fiche de 5 images (première vue, 390 px) | 0 Ko | ≤ 300 Ko (une seule image visible, les autres en différé) | |
| JavaScript ajouté aux pages de lecture élève | 0 Ko | 0 Ko | |
| Temps serveur de la page fiche (budget ADR-0067) | dans le budget | inchangé | |
