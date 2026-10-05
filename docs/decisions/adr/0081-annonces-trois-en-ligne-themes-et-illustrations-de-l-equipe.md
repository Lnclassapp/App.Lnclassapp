# ADR-0081 : Une annonce dure 30 jours et un auteur en a 3 en ligne au plus ; thème de couleur, illustrations SVG de l'équipe reconstruites, enregistrements de téléphone acceptés

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-05 : dessins de l'équipe en une seule couleur compris)* |
| **Date** | 2026-10-05 |
| **Chantier** | `docs/chantiers/annonces-v2` |
| **Remplace** | — *(amende l'[ADR-0078](0078-annonces-trois-auteurs-classes-ciblees-et-retrait.md) §4.1 « date de fin » et §4.4 « fichiers »)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0078 a donné à toute annonce en ligne une date de fin **choisie par l'auteur** (30 jours par défaut, 90 au plus). Elle a aussi borné l'apparence à 8 illustrations livrées avec l'application, et l'audio à un MP3 qui commence par `ID3` ou par une trame, ou à un M4A de marque `M4A `, `mp42` ou `isom`.

Après une journée d'usage, le porteur demande cinq changements (grill du [memo](../../chantiers/annonces-v2/memo.md)) :

- ne plus saisir de date de fin : la durée devient automatique, et un auteur garde **3 annonces en ligne au plus**, la 4ᵉ archivant la plus ancienne ;
- un thème de couleur par annonce, parmi 10 ;
- une bibliothèque d'illustrations que **l'équipe enrichit avec des dessins SVG** qui suivent le thème ;
- l'acceptation des enregistrements de téléphone ;
- un décompte des caractères, qui ne touche que l'interface (UDR-0075).

Deux points sont dangereux :

- un SVG peut contenir du code : script, gestionnaire d'événement, `foreignObject`, lien externe, entité XML ;
- un plafond compté sans verrou laisse passer une 4ᵉ annonce si deux publications du même auteur arrivent ensemble.

## 2. Moteurs de décision

- L'auteur ne saisit rien de plus qu'avant, et sait ce qui partira (grill, questions 1 et 3).
- Rien de ce qu'un compte de l'équipe téléverse ne peut s'exécuter dans le navigateur d'un élève, même si ce compte est compromis.
- La règle de lecture de l'ADR-0078 §4.3 reste **la seule** : la fin calculée la nourrit sans la changer.
- Le nombre de requêtes de l'accueil élève reste constant (ADR-0067).
- La couleur d'une carte se vérifie par un test de contraste, en clair et en sombre (UDR-0065).

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Pas de durée maximale, seul le plafond fait partir une annonce | La règle la plus simple pour le porteur | Une annonce oubliée resterait en ligne des mois (grill, question 1) |
| B — Plafond compté par signature (direction d'un établissement, équipe Lnclass) | Le carrousel n'affiche pas 9 annonces de direction | La 4ᵉ d'une direction archiverait l'annonce d'une collègue (grill, question 2) |
| C — Stocker le SVG envoyé et le servir comme fichier (`<img>`) | Un SVG en `<img>` n'exécute rien | Il ne prend pas la couleur du thème ; ouvert seul dans un onglet, il s'exécuterait |
| D — Nettoyer le SVG envoyé, puis l'insérer tel quel dans la page | Il garde toutes ses couleurs | Un nettoyeur qui oublie un cas devient une faille XSS chez des mineurs, et le texte stocké devrait être marqué sûr à chaque rendu |
| E — Convertir tout audio en MP3 côté serveur | Tout format passe | Il faudrait ffmpeg et une tâche de fond, pour un gain marginal (grill, question 8) |

## 4. Décision

### 4.1 Durée et plafond (amende l'ADR-0078 §4.1)

- **Plus de date de fin choisie.** `ends_at` = parution + **30 jours** (`Message::DURATION`). Pour une annonce programmée, la fin court depuis sa date de parution. La modification d'une annonce publiée ne change pas sa fin. Un brouillon n'a pas de fin. `Message::MAX_DURATION` et la contrainte des 90 jours disparaissent ; la contrainte « une annonce programmée ou publiée a une fin » reste.
- **3 annonces en ligne au plus par compte auteur** (`Message::LIVE_CAP = 3`). « En ligne » = `published`, `published_at <= now < ends_at`. Ne comptent pas : brouillon, programmée, archivée, retirée, terminée.
- **À chaque parution** (création publiée tout de suite, brouillon ou programmée publiée par son auteur, passage du job de publication), dans **la même transaction** :
  1. la ligne `users` de l'auteur est verrouillée (`SELECT … FOR UPDATE`) ;
  2. ses annonces en ligne sont lues, de la plus ancienne à la plus récente ;
  3. les plus anciennes passent à `archived` jusqu'à ce qu'il en reste `LIVE_CAP - 1` ;
  4. la nouvelle paraît.

  Deux publications simultanées du même auteur se suivent donc, et il n'a jamais plus de 3 annonces en ligne.
- L'archivage par le plafond est un archivage ordinaire : même statut, même gel, mais pas de journal, comme l'archivage par l'auteur. Le résultat du use case nomme les annonces archivées, et le toast les nomme (UDR-0075).
- Le formulaire montre à l'avance l'annonce qui partirait. Une query lit les annonces en ligne de l'auteur ; c'est une lecture d'information, la transaction refait le calcul sous verrou.

### 4.2 Thème

- `messages.theme` : chaîne non nulle, par défaut `ciel`, dans une liste fermée de 10 clés (`Message::THEMES` : `ciel lagune menthe citron mangue corail hibiscus lavande indigo nuit`), avec une contrainte en base.
- Un thème est un jeu de 4 tokens redéfinis **à l'échelle de la carte** par `[data-announcement-theme="<clé>"]` :
  - `--color-brand-soft` : le fond ;
  - `--color-school` : le texte, la signature et `fill-school` ;
  - `--color-brand` : l'illustration ;
  - `--color-brand-strong` : l'illustration et le badge officiel.

  Chaque thème a des valeurs en clair et dans les deux blocs sombres de l'UDR-0065. Les 8 dessins de base suivent sans être réécrits, puisqu'ils utilisent déjà ces tokens.
- Un test de palette calcule, pour chaque thème et chaque mode, le contraste du texte (≥ 4,5:1, signature à 80 % comprise) et celui du badge (≥ 3:1).

### 4.3 Illustrations de l'équipe : reconstruites, jamais insérées

- **Table `message_illustrations`** :
  - `public_id` (14) ;
  - `name` (30) ;
  - `view_box` ;
  - `shapes` (`jsonb`) : la liste des formes reconstruites ;
  - `created_by_id` ;
  - `retired_at` ;
  - les horodatages.

  Une contrainte borne `shapes` à 500 formes au plus.
- **Côté annonce** : `messages.illustration` (clé de base) devient nullable, et `messages.illustration_id` (référence vers une illustration de l'équipe) s'ajoute. Une contrainte impose **exactement l'une des deux**.
- **Lecture du fichier**, par le port `Ports::Communication::DrawingReaderPort#read(bytes:)` et son adaptateur d'infrastructure, avec Nokogiri en XML strict, sans réseau, sans DTD :
  - poids : 50 Ko au plus, vérifié avant lecture ;
  - refus si DOCTYPE ou entité, élément `script`, `foreignObject`, `style`, `iframe`, `image` ou `use`, attribut `on*`, `href` ou `xlink:href`, `url(` dans une valeur ;
  - refus aussi s'il n'y a pas de `viewBox` ou pas de forme ;
  - les éléments de forme permis (`path rect circle ellipse line polyline polygon`, et `g` pour la structure) sont recopiés avec leurs seuls attributs géométriques (`d x y width height rx ry cx cy r x1 y1 x2 y2 points transform fill-rule`), chacun validé par une expression stricte ;
  - tout le reste (titres, métadonnées, `defs`, éléments d'éditeur, couleurs, classes, styles) est **ignoré** ;
  - le port rend `view_box` et `shapes`, ou une erreur nommée (`:unsafe`, `:not_svg`, `:empty`).
- **Rendu** : un helper construit le `<svg>` avec le constructeur de balises de Rails, à partir de `shapes`, en revérifiant la liste blanche. Il n'insère **jamais** de texte stocké et n'appelle jamais `html_safe`. Le dessin est **d'une seule couleur** : toutes les formes prennent `fill-brand-strong`, la couleur d'illustration du thème. C'est ainsi qu'un dessin de l'équipe suit le thème et le mode sombre (grill, question 5).
- **Retrait** : `retired_at` est posé. L'illustration sort du choix (un formulaire forgé qui la vise reçoit 422), mais les annonces qui la portent la gardent jusqu'à leur fin. Une illustration n'est jamais supprimée.
- **Écriture** : `Policies::Communication::ManageIllustrationsPolicy` donne le droit à l'équipe seule (403 sinon). Ce sont les use cases `AddIllustration`, `RenameIllustration` et `RetireIllustration`. Toute personne connectée lit.

### 4.4 Audio des téléphones (amende l'ADR-0078 §4.4)

`Entities::Communication::AudioHeader` lit les **4096** premiers octets, au lieu de 12. Le poids reste vérifié avant toute lecture.

- **MP3** :
  - une étiquette `ID3` ;
  - ou une trame MPEG valide (synchronisation, version et couche définies, débit ni libre ni réservé, fréquence définie) au début, **ou après des octets nuls de remplissage**.
- **MP4/3GP** : une boîte `ftyp` en tête, dont la marque majeure est l'une de `M4A ` `M4B ` `mp41` `mp42` `isom` `iso2` `3gp4` `3gp5` `3gp6` `3g2a` `MSNV` `dash` `f4a `. Il est servi en `audio/mp4`.
- **Refusés** : AMR (`#!AMR`), OGG (`OggS`), WAV (`RIFF…WAVE`) et tout le reste, avec le message « Ce fichier n'est pas accepté. Exportez l'enregistrement en MP3 ou M4A. ».

## 5. Conséquences

### 🟢 Positives

- L'auteur ne saisit plus de date : le formulaire perd un champ obligatoire.
- Une carte n'affiche jamais de vieilles annonces d'un même auteur.
- Le SVG de l'équipe n'atteint jamais la page tel qu'il a été envoyé : seule une liste de formes revérifiée est rendue.
- Les 8 dessins de base et les dessins de l'équipe suivent le thème et le mode sombre par les mêmes tokens.

### 🔴 Coûts consentis

- **Une annonce d'événement lointain** (une sortie dans 6 semaines) part au bout de 30 jours. L'auteur doit la programmer plus tard ou la republier.
- **Les dessins de l'équipe sont monochromes** : un dessin multicolore est rendu d'une seule couleur. Les 8 de base restent multicolores.
- **Un 3GP qui contient de l'AMR** (vieux téléphones) passe le contrôle d'en-tête mais ne se lit pas dans un navigateur. Le lecteur affiche alors son état « Lecture impossible » (UDR-0071 §3.4). Lire le codec demanderait de parcourir l'arbre MP4 en entier.
- **L'archivage par le plafond n'est pas journalisé**, comme l'archivage par l'auteur. Seul le toast de l'auteur le dit.
- **Un verrou par auteur** : ses publications sont sérialisées, ce qui est sans effet visible à l'échelle d'un compte.

## 6. Notes d'implémentation

```ruby
# app/domain/ports/communication/message_repository_port.rb (ajout, Lot 0)
# Verrouille le compte auteur (SELECT … FOR UPDATE sur users) puis rend ses annonces en ligne, la plus ancienne d'abord.
def live_of(author_id:, now:) = raise NotImplementedError

# app/domain/use_cases/communication/create_message.rb (dans la transaction de la parution)
live = @messages.live_of(author_id: actor.user_id, now:)
archived = live.first([ live.size - (Message::LIVE_CAP - 1), 0 ].max)
archived.each { @messages.update(message: it.with(status: "archived")) }
```

```ruby
# app/domain/ports/communication/drawing_reader_port.rb (Lot 0)
# bytes : String (50 Ko au plus, déjà vérifiés) → Result success({ view_box:, shapes: }) | failure(:unsafe | :not_svg | :empty)
def read(bytes:) = raise NotImplementedError
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/communication/create_message_test.rb` et `publish_scheduled_messages_test.rb` (AV-03, AV-04) :
  - la 4ᵉ parution archive la plus ancienne en ligne ;
  - un brouillon, une programmée, une archivée, une retirée ou une terminée ne comptent pas.
- `test/infrastructure/repositories/communication/message_repository_test.rb` : deux transactions concurrentes du même auteur laissent 3 annonces en ligne (AV-05).
- `test/infrastructure/drawing_reader_test.rb` : chaque SVG piégé est refusé (script, `onload`, `foreignObject`, `href`, `xlink:href`, `url(`, DOCTYPE, entité, `style`, `use`, `image`), et un SVG d'Inkscape est reconstruit sans ses métadonnées (AV-09).
- `test/helpers/communication/illustrations_helper_test.rb` : le rendu d'une illustration de l'équipe ne contient que les éléments et attributs permis, et ne passe jamais par `html_safe` (vérifié par un `grep` du test d'architecture).
- `test/design/announcement_themes_test.rb` : les 10 thèmes, clair et sombre, tiennent leurs contrastes (AV-07).
- `test/domain/entities/communication/audio_header_test.rb` : un fichier réel par variante (AV-12).
- La règle de lecture `ReadableMessages#scope` ne change pas : son test reste vert sans modification.
