# PRD — App Android « Lnclass Teacher » pour les enseignants

> Les specs sont figées ici. Toute évolution se fait par modification explicite de ce fichier.
> Périmètre : **l'app enseignants**, après l'app élèves ([prd.md](prd.md)). Décisions : [memo](memo.md#reprise-du-2026-10-08--lnclass-teacher), [ADR-0085](../../decisions/adr/0085-coque-android-enseignants-lnclass-teacher.md), [UDR-0081](../../decisions/udr/0081-en-tete-enseignant-et-barres-de-lnclass-teacher.md).

## 1. Contexte

Un enseignant ne trouve pas Lnclass sur le Play Store. Ce chantier livre « Lnclass Teacher » : une coque Hotwire Native qui affiche les pages du site avec des barres natives, quatre onglets en bas, l'avatar et l'aide en haut. Il change aussi l'en-tête de l'enseignant sur le site, sur le modèle de celui de l'élève.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Teacher | Installer l'app ; se connecter, s'inscrire (`/teacher-signup`, lien d'invitation `/i/`) ; tout ce qu'il fait sur le site ; ouvrir le panneau du compte | Rien de plus que sur le site |
| Student | Rien dans l'app enseignants : refusé après un PIN correct, envoyé vers l'app « Lnclass » | Ouvrir une session dans l'app enseignants |
| SchoolStaff, Team | Rien dans aucune des deux apps : renvoyés vers le site | — |
| Team (pilotage) | Lire le nombre d'enseignants qui ont ouvert l'app Android sur la période | — |

## 3. Parcours

1. M. Koné installe « Lnclass Teacher » (APK de test) : l'icône du baobab au bras levé, sur fond orange, apparaît.
2. Il se connecte. Son accueil s'affiche avec l'avatar en haut à gauche, « Besoin d'aide ? » à droite et quatre onglets en bas : Accueil, Classes, Cours, Annonces.
3. Il ouvre une classe, puis touche « Assigner un exercice » : la page s'ouvre en plein écran, sans onglets. Il assigne, et la page se referme.
4. Il touche son avatar : le panneau s'ouvre, avec son nom, son établissement, « Mon profil », « Inviter un collègue », le thème et « Se déconnecter ».

| Situation | Comportement attendu |
|---|---|
| Un élève se connecte dans l'app enseignants (PIN correct) | Aucune session ; « Utilisez l'app Lnclass » |
| Un enseignant se connecte dans l'app élèves (PIN correct) | Aucune session ; « Utilisez Lnclass Teacher » |
| La direction ou l'équipe dans l'une ou l'autre | Aucune session ; « continuez sur le site » |
| PIN faux, quel que soit le rôle | Le même message d'échec pour tous |
| Lien d'inscription enseignant reçu sur WhatsApp, app installée par le Play Store | Il s'ouvre dans l'app |
| Enseignant sur le site, dans le navigateur | Nouvel en-tête : avatar à gauche, aide et thème à droite, sans logo |
| Direction et équipe sur le site | En-tête inchangé |

## 4. Critères d'acceptation

```gherkin
# CA-T1 — Le site reconnaît la coque enseignants
Étant donné un User-Agent qui contient « Hotwire Native » et « LnclassTeacherAndroid/1.0 »
Quand un enseignant connecté ouvre son accueil
Alors la page n'a ni en-tête, ni barre latérale, ni barre basse
Et elle contient l'élément du pont avec l'adresse « /teachers/menu »

# CA-T2 — Configuration des chemins
Quand on demande « /android/v1/path-configuration.json »
Alors « /teachers/menu », « /classrooms/<id>/assignments/new » et « /classrooms/<id>/session_days/edit » s'ouvrent en contexte « modal »

# CA-T3 — Refus croisés
Étant donné un élève au PIN correct dans la coque enseignants
Alors aucune session n'est ouverte et la page affiche « Utilisez l'app Lnclass »
Étant donné un enseignant au PIN correct dans la coque élèves
Alors aucune session n'est ouverte et la page affiche « Utilisez Lnclass Teacher »
Étant donné la direction au PIN correct dans la coque enseignants
Alors la page affiche « Cette app est réservée aux enseignants » et un lien vers le site
Et un PIN faux donne le même message d'échec à tous les rôles

# CA-T4 — Enseignant accepté
Étant donné un enseignant au PIN correct dans la coque enseignants
Alors une session est ouverte et il arrive sur son accueil

# CA-T5 — Ouverture comptée
Étant donné un enseignant connecté dans la coque enseignants
Quand l'app ouvre « /?source=android »
Alors son compte porte `android_opened_at` et le pilotage affiche « dont app Android : 1 enseignant »

# CA-T6 — En-tête de l'enseignant sur le site
Étant donné un enseignant connecté dans un navigateur, à 390 px
Alors l'en-tête montre son avatar à gauche, « Besoin d'aide ? » et l'interrupteur à droite, sans logo
Et toucher l'avatar ouvre le panneau avec « Mon profil » et « Inviter un collègue »
Et « /teachers/menu » rend le même contenu comme une page, refusée à un élève
Et la direction voit l'en-tête d'origine

# CA-T7 — Liens ouverts dans l'app
Quand on demande « /.well-known/assetlinks.json » avec des empreintes configurées
Alors la réponse déclare « com.lnclass.student » et « com.lnclass.teacher » (ou leurs identifiants configurés)

# CA-T8 — La coque
Quand on compile « bin/android-build teacher recette »
Alors on obtient un APK « com.lnclass.teacher.recette », minSdkVersion 28, qui charge « https://app-staging.lnclass.com »
Et son User-Agent contient « LnclassTeacherAndroid/ »
Et ses quatre onglets démarrent sur « /?source=android », « /teachers/classrooms », « /courses » et « /announcements »
Et « bin/android-build recette » produit toujours l'app élèves
```

## 5. Mesures

| Métrique | Cible |
|---|---|
| Taille de l'APK de recette enseignants | ≤ 10 Mo |
| Requêtes du pilotage | inchangées |
| Poids ajouté au JavaScript d'entrée | 0 (le pont existe déjà) |
