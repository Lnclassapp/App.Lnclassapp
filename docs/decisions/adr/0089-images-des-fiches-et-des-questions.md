# ADR-0089 : Les fiches et les questions portent des images vérifiées, envoyées par l'équipe, annoncées par l'import et exigées avant publication
<!-- index
titre: Images des fiches et des questions : tables par contexte, emplacements de l'import, plafonds mobiles, service sous la règle de lecture
statut: Proposé
problematique: Les fiches et les questions refusent toute image (ADR-0051, ADR-0074 moteur 2) ; comment les ouvrir aux images sans fournisseur externe, sans fuite et sans alourdir la lecture sur mobile ?
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-10 |
| **Chantier** | `docs/chantiers/images-dans-les-cours` |
| **Remplace** | — |
| **Amende** | [ADR-0074](./0074-blog-public-articles-images-et-referencement.md) (moteur 2 « les cours et les fiches ne changent pas ») · [ADR-0051](./0051-navigateurs-supportes-et-budget-de-poids.md) (l'éditeur refuse toute image : vrai désormais pour le cours seul) |
| **Complète** | [ADR-0035](./0035-cycle-de-vie-et-propriete-du-contenu.md) (conditions de publication) · [ADR-0060](./0060-photo-de-profil-stockee-privee-recadree-par-le-navigateur.md) (`ImageHeader`, réduction par le navigateur) · [ADR-0068](./0068-import-de-plusieurs-fichiers-de-cours-et-ecriture-acceleree.md) (`RichTextSanitizer`, `ContentTreeWriter`) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Une fiche essentielle et une question d'exercice ne contiennent que du texte. Le choix date de septembre 2026 : l'éditeur Trix des cours annule tout fichier (ADR-0051), `RichTextSanitizer` retire toute pièce jointe, et l'ADR-0074, qui a ouvert le blog aux images, a gardé les cours fermés (moteur 2, BL-15). La méthode de rédaction en tire la règle « pas d'image, un schéma se décrit en mots ».

La production des leçons de la progression 2026-2027 a montré la limite : la première leçon de Physique-Chimie de 6e (« Le circuit électrique ») est difficile à comprendre sans schéma, et il en va de même pour la géométrie, la cellule, les cartes. L'équipe a décidé le 2026-10-10 d'ouvrir les fiches **et** les questions aux images.

Contraintes de départ, tirées du grill (memo) :
- **Pas de fournisseur d'IA d'image dans l'application** : les images sont produites dans Claude Design, hors de l'application, exportées en PNG ou WebP, puis envoyées par l'équipe.
- Les leçons naissent d'un **import JSON** produit par un prompt : l'import doit dire **où** va une image et **ce qu'elle montre**, sans transporter l'image.
- L'élève révise **sur téléphone, avec peu de données** : 300 Ko au plus par image.
- **Rien ne fuit** : le catalogue est sous connexion ; un brouillon et ses images restent invisibles des élèves.

## 2. Moteurs de décision

1. **Réutiliser le chemin éprouvé des images d'article** (ADR-0074) : réduction par le navigateur, vérification des octets par `ImageHeader`, retrait des métadonnées, pièce jointe Action Text par `sgid`, service par un contrôleur Lnclass, purge des orphelines. Six corrections JPEG successives ont montré le coût d'un second chemin.
2. **Un contenu publié est complet** : aucune image annoncée ne manque, chaque image a son texte de remplacement.
3. **Le lecteur paie peu** : 0 Ko de JavaScript ajouté aux pages de lecture, images en `loading="lazy"`, poids plafonné.
4. **Les contextes bornés restent étanches** : la fiche appartient au catalogue, la question à l'évaluation.
5. **Les anciens fichiers d'import restent valides** sans modification.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Générer l'image dans l'application (API d'image) | Moins de manipulations pour l'équipe | Écartée par le porteur (grill, question 4) : pas de fournisseur ni de coût par image pour l'instant |
| B — SVG dessiné par le prompt, dans le JSON | Une leçon = un fichier ; net à toute taille | Un SVG est du code (scripts, liens externes) : un nettoyage SVG complet serait un nouveau risque ; écarté au grill (question 5) |
| C — Image encodée dans le JSON d'import | Une leçon = un fichier | Fichiers lourds (50 fichiers / 50 Mo par import), vérification d'image dans le job d'import ; écartée au grill |
| D — Une table d'images partagée, polymorphe (fiche ou question) | Un seul store, un seul contrôleur | Traverse deux contextes bornés ; `owner_type` polymorphe sans clé étrangère réelle ; règles de lecture différentes (fiche, session d'exercice) |
| **E — Une table par contexte (`essential_images` au catalogue, `question_images` à l'évaluation), vérification et plafonds partagés (`Entities::Shared::ContentImage`, `Dtos::Shared::ContentImageInput`), emplacements textuels `[[image: …]]` dans le texte de la fiche, `image.description` sur la question dans le schéma d'import** | Réutilise le chemin du blog ; clés étrangères réelles ; chaque contexte garde sa règle de lecture ; l'emplacement survit à l'assainissement et à Trix sans balise nouvelle | **Retenue** — voir coûts consentis |

## 4. Décision

> **Nous ouvrons les fiches essentielles et les questions aux images JPEG, PNG et WebP fixes, de 300 Ko et 1200 px au plus, envoyées une à une par l'équipe `admin` ou `content` après réduction par le navigateur, vérifiées par `ImageHeader` et privées de leurs métadonnées ; nous les rangeons dans `essential_images` (catalogue) et `question_images` (évaluation) ; l'import annonce une image de fiche par un emplacement `[[image: description]]` dans le texte et une image de question par `image.description` ; une fiche ou un exercice ne se publie pas tant qu'un emplacement reste ou qu'une image n'a pas de texte de remplacement ; une image se sert par un contrôleur Lnclass sous la règle de lecture du contenu qui la porte, en cache navigateur privé et immuable.**

### 4.1 Plafonds partagés

`Entities::Shared::ContentImage` : `CONTENT_TYPES = %w[image/jpeg image/png image/webp]`, `MAX_BYTES = 300 * 1024`, `MAX_SIDE = 1200`, `ALT_MAX = 150`, `MAX_PER_ESSENTIAL = 30` (plafond anti-abus ; pas de limite métier, grill question 6). `Dtos::Shared::ContentImageInput` est `Dtos::Communication::ArticleImageInput` paramétré par ces plafonds ; l'article garde les siens (1 Mo, 1600 px).

### 4.2 Tables

| `essential_images` | Contrainte |
|---|---|
| `public_id` | `string(14) NOT NULL`, unique ; une ligne ne change jamais de fichier |
| `essential_id` | `bigint NULL`, FK `essentials` `on_delete: :restrict` (ADR-0036 : rien ne part par une clé étrangère) ; `NULL` tant que la fiche n'est pas enregistrée |
| `alt` | `string(150) NULL` ; exigé à la publication |
| `content_type`, `byte_size`, `width`, `height` | `CHECK IN ('image/jpeg','image/png','image/webp')`, `byte_size BETWEEN 1 AND 307200`, côtés `BETWEEN 1 AND 1200` |

| `question_images` | Contrainte |
|---|---|
| `public_id` | `string(14) NOT NULL`, unique |
| `question_id` | `bigint NULL`, FK `questions` `on_delete: :restrict`, **index unique partiel** `WHERE question_id IS NOT NULL` : une image par question |
| `alt`, `content_type`, `byte_size`, `width`, `height` | comme `essential_images` |

`questions.image_description` : `string(150) NULL`. Le fichier est `has_one_attached :file`, créé `analyzed: true` (pas de libvips, ADR-0060).

### 4.3 Emplacements d'une fiche

Un emplacement est un paragraphe dont tout le texte est `[[image: <description>]]`, description de 1 à 150 caractères. `Entities::Catalog::ImageSlot.scan(html)` les lit (Ruby pur, expression régulière sur le texte des `<p>`). Ils traversent `RichTextSanitizer` et Trix comme du texte ordinaire : aucune balise nouvelle. L'éditeur remplace l'emplacement par l'image insérée (UDR-0084) et pré-remplit son texte de remplacement avec la description.

### 4.4 Conditions de publication

- `PublishEssential` : `:conflict` `base: [:image_slots_left]` (avec `count`) si `ImageSlot.scan` trouve un emplacement ; `:invalid` `:"image_alts.<public_id>"` pour chaque image sans texte de remplacement.
- `PublishCascade` (« Tout publier ») : vérifie toutes les fiches **avant** d'écrire ; un refus nomme la fiche ; rien n'est publié.
- `PublishExercise` : `Entities::Assessment::Question#structure_errors` gagne `:image_missing` (description sans image) et `:image_alt_blank` ; `publishable?` les lit déjà.
- Une question **tentée** ne se modifie plus (ADR-0036, ADR-0054) : son image non plus.

### 4.5 Service

`GET /images/fiches/:public_id` (`Catalog::EssentialImagesController#show`) et `GET /images/questions/:public_id` (`Assessment::QuestionImagesController#show`), sous `AuthenticatedController` :
- lecture refusée (`404`) si le contenu porteur n'est pas lisible par l'acteur selon la règle du texte (fiche et cours publiés, niveau de l'élève, matière de l'enseignant) ; l'équipe `admin`/`content` lit aussi les brouillons ;
- publié : `Cache-Control: max-age=31536000, private, immutable`, `ETag` = `public_id` (304 sans lire le bucket) ; brouillon : `private, no-store` ;
- jamais de cache **public** : le catalogue est sous connexion (différence avec le blog).

Remplacer une image crée une nouvelle ligne ; l'ancienne, plus citée, est supprimée à l'enregistrement : son adresse répond 404.

### 4.6 Import (`lnclass.course-tree` v1, ajout compatible)

- Fiche : rien ne change dans le schéma ; l'emplacement vit dans `content`.
- Question : propriété facultative `"image": { "description": string(1..150) }`, `additionalProperties: false`. Un ancien fichier reste valide.
- `ContentTreeWriterPort::QuestionNode` gagne `image_description`. L'import ne crée jamais d'image.

### 4.7 Envoi et purge

`POST /teams/essential-images` et `POST /teams/question-images` (JSON, comme `Teams::ArticleImagesController`), paramètre `essential` / `question` (public_id ou slug) pour tenir le plafond par fiche. Les images envoyées et jamais citées depuis 48 h sont purgées chaque jour (`Catalog::PurgeOrphanEssentialImagesJob`, `Assessment::PurgeOrphanQuestionImagesJob`, `config/recurring.yml`).

## 5. Conséquences

### 🟢 Positives

- Une notion qui passe par un dessin se lit enfin sur téléphone, à l'endroit où le texte en parle.
- Aucun fournisseur, aucune clé, aucun coût par image dans l'application.
- Un seul chemin de vérification d'image (celui du blog), paramétré au lieu de dupliqué.
- Les anciens fichiers d'import et les 24 leçons existantes ne bougent pas.

### 🔴 Coûts consentis

- **Deux tables, deux stores, deux contrôleurs de service** quasi jumeaux : le prix de l'étanchéité catalogue / évaluation.
- **Un emplacement est du texte** : une faute de frappe (`[image: …]`) n'est pas reconnue et passe la publication. Le prompt et le validateur de la méthode de rédaction en portent la forme exacte.
- **Cache privé seulement** : chaque élève télécharge chaque image une fois (pas de relais partagé).
- **300 Ko / 1200 px** : une image très détaillée (carte) peut perdre en lisibilité ; l'équipe la recadre.
- **Travail manuel** : chaque image est produite dans Claude Design puis envoyée à la main, fiche par fiche.
- **« Tout publier » peut désormais refuser** un cours entier pour une seule image manquante.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/catalog/image_slot.rb
module Entities
  module Catalog
    # Un emplacement d'image annoncé par l'import : un paragraphe dont tout le texte est « [[image: description]] ».
    ImageSlot = Data.define(:description) do
      PATTERN = %r{<p>\s*\[\[image:\s*([^\]<]{1,150}?)\s*\]\]\s*</p>}

      def self.scan(html) = html.to_s.scan(PATTERN).map { new(description: it.first) }
    end
  end
end
```

```ruby
# app/infrastructure/repositories/shared/rich_text_sanitizer.rb : l'admission par sgid devient paramétrée par modèle
def self.call(html, image_ids: nil, image_model: "Orm::ArticleImage")
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/catalog/image_slot_test.rb` : emplacements reconnus, et ignorés hors d'un paragraphe seul.
- `test/domain/use_cases/catalog/publish_essential_test.rb` et `publish_cascade_test.rb` : refus avec emplacement restant ou alt vide.
- `test/domain/use_cases/assessment/publish_exercise_test.rb` : refus `image_missing`.
- `test/domain/dtos/shared/content_image_input_test.rb` : 300 Ko, 1200 px, SVG déguisé, EXIF retiré.
- `test/controllers/catalog/essential_images_controller_test.rb` : 404 brouillon, 404 hors niveau, `Cache-Control` privé immuable.
- `test/infrastructure/repositories/catalog/import_schema_validator_test.rb` : ancien fichier valide, description vide refusée.
- Contraintes `CHECK` en base : un octet de trop échoue même hors du domaine.
