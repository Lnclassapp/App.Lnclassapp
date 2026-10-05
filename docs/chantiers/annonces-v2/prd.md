# PRD — Annonces, deuxième version — saisie guidée, illustrations de l'équipe, trois annonces visibles, thèmes de couleur

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Les annonces (V6a, PR #162, [ADR-0078](../../decisions/adr/0078-annonces-trois-auteurs-classes-ciblees-et-retrait.md), [UDR-0071](../../decisions/udr/0071-annonces.md)) sont livrées depuis le 2026-10-04. Le porteur s'en est servi et demande cinq changements à la création d'une annonce ([memo](memo.md), grill de 9 questions) :

1. un décompte des caractères du titre et du texte ;
2. une bibliothèque d'illustrations enrichie par l'équipe ;
3. l'acceptation des enregistrements audio des téléphones ;
4. plus de date de fin à saisir : 30 jours automatiques, et **3 annonces en ligne au plus par auteur** ;
5. un **thème de couleur** par annonce, au choix parmi 10.

Le chantier de correction [`annonce-audio-mp3`](../annonce-audio-mp3/memo.md), arrêté faute de fichier à reproduire, est repris ici sous forme de spécification (point 3).

## 2. Acteurs et permissions

| Acteur | Peut faire | Ne peut pas faire |
|---|---|---|
| Auteur (équipe, direction, enseignant) | Voir le décompte ; choisir un thème parmi 10 et une illustration de la bibliothèque (les 8 de base et celles de l'équipe) ; joindre un MP3 ou un M4A enregistré au téléphone ; publier en sachant quelle annonce partira | Saisir une date de fin ; garder plus de 3 annonces en ligne ; ajouter une illustration (sauf l'équipe) |
| Équipe | En plus : ajouter une illustration SVG à la bibliothèque, la renommer, la retirer du choix | Supprimer une illustration qu'une annonce en ligne utilise encore : elle est retirée du choix, son dessin reste servi |
| Élève, lecteur | Lire des cartes à la couleur de leur thème, avec leur illustration | — |
| Visiteur non connecté | Rien | Tout : « Se connecter » |

Les règles d'autorisation existantes ne changent pas (`PublishPolicy`, `ManageOwnPolicy`, `WithdrawPolicy`, `ReadFilePolicy`, `DismissPolicy`). La bibliothèque d'illustrations a sa propre règle : l'équipe seule écrit, et tout acteur connecté lit.

## 3. Parcours utilisateur

### Chemin nominal — un enseignant publie sa 4ᵉ annonce

1. M. Kouassi a 3 annonces en ligne : « Réunion parents » (1er octobre), « Fiches chapitre 3 » (3 octobre), « Sortie au musée » (5 octobre). Il ouvre « Nouvelle annonce ».
2. Il tape son titre. Le décompte affiche « 18 / 60 ». Il tape le texte, et le décompte affiche « 97 / 140 ». À 20 caractères restants, le décompte passe en ambre ; à 0, en rouge, et la saisie s'arrête.
3. Il choisit le thème « Mangue » parmi 10 pastilles, puis l'illustration « Bus scolaire » que l'équipe a ajoutée. L'aperçu de la carte prend les couleurs du thème.
4. Il joint l'enregistrement fait avec son téléphone (un M4A de marque `3gp4`). Il n'y a plus de champ « Visible jusqu'au ».
5. Au-dessus du bouton, un encadré dit : « Tu as déjà 3 annonces en ligne. En publiant, « Réunion parents » sera archivée. »
6. Il publie. Le toast dit « Annonce publiée. « Réunion parents » est archivée. ». Dans « Mes annonces », la nouvelle est « Publiée le 6 oct. · jusqu'au 4 nov. », et « Réunion parents » est « Archivée ».
7. Awa (3ème B) voit la nouvelle carte, orange, dans son carrousel. « Réunion parents » n'y est plus.

### Autre chemin nominal — l'équipe enrichit la bibliothèque

1. Fatou (équipe) ouvre « Référentiel ». Une tuile indique « 8 illustrations d'annonce · Gérer → ».
2. La page « Illustrations d'annonce » liste les 8 de base (« Fournie par Lnclass », non modifiables) et celles de l'équipe.
3. « Ajouter une illustration » : un nom (« Bus scolaire », 30 caractères au plus) et un fichier SVG d'une seule couleur, de 50 Ko au plus. L'aperçu montre le dessin aux couleurs de 3 thèmes.
4. Elle l'ajoute. Tous les auteurs le trouvent dans le choix d'illustration, après les 8 de base.
5. Plus tard, elle la retire : elle disparaît du choix, mais les annonces qui l'utilisent la gardent jusqu'à leur fin.

### Chemins alternatifs et erreurs

- **Annonce programmée** : à la programmation, rien ne part. L'encadré dit « À sa parution, si tu as encore 3 annonces en ligne, la plus ancienne sera archivée. ». C'est à la parution, au passage du job de publication, que la plus ancienne en ligne de l'auteur part.
- **Brouillon** : il ne compte pas et n'archive rien.
- **Modification d'une annonce déjà publiée** : elle ne compte pas comme une parution et n'archive rien. Sa date de fin ne change pas.
- **Fichier SVG refusé** :
  - s'il contient un script, une balise `foreignObject`, un lien externe, une entité XML ou un DOCTYPE : « Ce dessin n'est pas accepté : il contient autre chose que des formes. » ;
  - s'il dépasse 50 Ko : « Ce fichier est trop lourd (50 Ko au plus). » ;
  - si ce n'est pas un SVG : « Ce fichier n'est pas un dessin SVG. ».
- **Audio refusé** (AMR, OGG, WAV…) : « Ce fichier n'est pas accepté. Exportez l'enregistrement en MP3 ou M4A. »
- **Un non-membre de l'équipe** sur la page « Illustrations d'annonce » : 403.

## 4. Critères d'acceptation

```gherkin
# AV-01 — Décompte du titre et du texte
Étant donné le formulaire d'une nouvelle annonce
Quand l'auteur tape un titre de 18 caractères et un texte de 97 caractères
Alors le titre affiche « 18 / 60 » et le texte « 97 / 140 »
Et à 20 caractères restants le décompte passe en ambre, à la limite en rouge, et un lecteur d'écran entend le seuil franchi
Et la saisie reste bornée à 60 et 140 caractères (maxlength) ; sans JavaScript, le décompte rendu par le serveur reste

# AV-02 — Plus de date de fin à saisir
Étant donné le formulaire d'une annonce, nouvelle ou en modification
Alors il n'a pas de champ « Visible jusqu'au »
Et une annonce publiée le 6 octobre à 10:00 se termine le 5 novembre à 10:00, 30 jours après (ADR-0081 §4.1)
Et une annonce programmée prend sa fin 30 jours après sa date de parution
Et la modification d'une annonce publiée ne change pas sa date de fin
Et un paramètre visible_until forgé est ignoré

# AV-03 — Trois annonces en ligne au plus par auteur
Étant donné un auteur qui a 3 annonces en ligne, publiées les 1er, 3 et 5 octobre
Quand il publie une 4e annonce
Alors celle du 1er octobre est archivée, dans la même transaction que la publication
Et il a 3 annonces en ligne
Et les annonces d'un autre auteur, collègue ou direction du même établissement, ne sont pas touchées

# AV-04 — Ce qui compte comme en ligne
Étant donné un auteur avec 2 annonces en ligne, 1 programmée, 1 brouillon, 1 archivée, 1 retirée et 1 terminée
Quand il publie une annonce
Alors rien n'est archivé (il en a 3 en ligne)
Et quand la programmée paraît au passage du job, la plus ancienne en ligne est archivée par le job
Et modifier une annonce publiée n'archive rien

# AV-05 — Deux publications au même instant
Étant donné un auteur qui a 3 annonces en ligne
Quand deux de ses publications arrivent en même temps
Alors il a 3 annonces en ligne après les deux, jamais 4

# AV-06 — L'auteur est prévenu
Étant donné un auteur qui a 3 annonces en ligne, dont « Réunion parents » est la plus ancienne
Quand il ouvre « Nouvelle annonce »
Alors un encadré dit « Tu as déjà 3 annonces en ligne. En publiant, « Réunion parents » sera archivée. »
Et après publication, le toast nomme l'annonce archivée
Et avec 2 annonces en ligne, l'encadré n'est pas affiché

# AV-07 — Dix thèmes
Étant donné le formulaire d'une annonce
Alors 10 thèmes sont proposés (« Ciel » par défaut), chacun avec son nom pour un lecteur d'écran
Et la carte publiée prend le fond, le texte et les couleurs d'illustration de son thème, dans le carrousel, « Reçues », « Mes annonces » et la modération
Et chaque thème garde un contraste d'au moins 4,5:1 pour le texte (signature à 80 % comprise) et 3:1 pour le badge officiel, en clair et en sombre (test de la palette)
Et un thème inconnu envoyé par un formulaire forgé est refusé (422)

# AV-08 — L'équipe ajoute une illustration
Étant donné Fatou, de l'équipe
Quand elle ajoute « Bus scolaire » avec un SVG d'une seule couleur de 12 Ko
Alors l'illustration apparaît dans le choix de tous les auteurs, après les 8 de base
Et sur une carte, elle prend la couleur de son thème
Et la tuile « Illustrations d'annonce » du Référentiel en compte 9

# AV-09 — Un SVG n'est jamais du code
Étant donné un SVG qui contient un script, un gestionnaire d'événement (onload…), un foreignObject, un lien href externe, un DOCTYPE ou une entité
Quand l'équipe le téléverse
Alors il est refusé (422), rien n'est enregistré
Et un SVG accepté est enregistré reconstruit : seules les formes permises et leurs attributs géométriques restent
Et le dessin est rendu dans la page à partir de cette reconstruction, jamais à partir du fichier envoyé

# AV-10 — Retirer une illustration
Étant donné « Bus scolaire », utilisée par une annonce en ligne
Quand Fatou la retire
Alors elle n'est plus proposée aux auteurs
Et l'annonce en ligne garde son dessin jusqu'à sa fin
Et un formulaire forgé qui choisit une illustration retirée est refusé (422)
Et les 8 illustrations de base ne peuvent être ni retirées ni modifiées

# AV-11 — Seule l'équipe gère la bibliothèque
Étant donné un enseignant, une direction ou un élève
Quand il ouvre la page « Illustrations d'annonce » ou envoie un ajout ou un retrait
Alors il reçoit 403
Et un visiteur est envoyé à « Se connecter »

# AV-12 — Les enregistrements des téléphones sont acceptés
Étant donné un MP3 précédé d'octets de remplissage avant sa première trame, et des M4A de marques 3gp4, 3gp5, mp41, mp42, M4A, M4B, isom
Quand un auteur les joint
Alors chacun est accepté et servi en audio/mpeg ou audio/mp4
Et un AMR, un OGG/Opus et un WAV sont refusés avec « Ce fichier n'est pas accepté. Exportez l'enregistrement en MP3 ou M4A. »
Et le poids reste vérifié avant toute lecture (10 Mo)
```

## 5. Modélisation préliminaire

| Couche | Éléments | Nouveau ou existant |
|---|---|---|
| Domaine | `Message` (thème, illustration de la bibliothèque, fin calculée) ; `MessageInput` (plus de date de fin, thème, illustration) ; `AudioHeader` (variantes) ; entité d'illustration et son DTO d'envoi ; lecteur de SVG (reconstruction par liste blanche) ; policy de gestion de la bibliothèque ; use cases d'ajout et de retrait d'illustration ; plafond de 3 dans `CreateMessage`, `UpdateMessage` (brouillon publié) et `PublishScheduledMessages` | Existants modifiés + nouveaux |
| Infrastructure | colonnes `messages.theme` et référence d'illustration ; table des illustrations de l'équipe ; repository et query de la bibliothèque ; verrou par auteur à la publication | Nouveaux |
| Delivery | formulaire d'annonce ; page « Illustrations d'annonce » de l'équipe (liste, ajout, retrait) ; tuile du Référentiel | Modifiés + nouveaux |
| UI | carte thémée ; sélecteur de thème ; sélecteur d'illustration élargi ; décompte (contrôleur `communication--character-count` de l'UDR-0067, réutilisé) ; encadré du plafond | Modifiés + nouveaux |

## 6. Décisions rattachées

- ADR : [0081](../../decisions/adr/0081-annonces-trois-en-ligne-themes-et-illustrations-de-l-equipe.md) (amende l'ADR-0078 §4.1 et §4.4)
- UDR : [0075](../../decisions/udr/0075-annonces-themes-illustrations-et-decompte.md) (amende l'UDR-0071 §3.2, §3.3 et §3.8)

## 7. Mesures

- Accueil élève : le nombre de requêtes reste constant (16 avec des annonces), thèmes et illustrations de l'équipe compris ; mesuré comme au chantier `annonces`.
- Budget des tests système : 15 s au plus pour ce chantier (ADR-0069 §9), mesurées face à `Develop` sur une même machine.
