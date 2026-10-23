# Memo — MVP Lnclass Teacher & Student — pilote du 27 octobre

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — grill en cours (2026-10-22) |
| **Ouvert le** | 2026-10-22 |
| **Branche** | `Develop` pour la documentation (commit direct, CLAUDE.md « Sobriété de tokens ») ; une branche de code pour la PR du lundi 26 |
| **Programme** | — *(hors vagues de `refonte-application` : il choisit dans ce que les vagues ont livré)* |

---

## Le problème

L'application compte plus de cent fonctionnalités livrées en un mois, pour quatre rôles. Un élève ou un enseignant qui l'ouvre pour la première fois voit tout à la fois : il ne sait pas par où commencer, et l'écran le plus vu, l'accueil élève, s'ouvre sur « Entrer en classe » plutôt que sur le travail à faire.

Le lancement du mardi 27 octobre n'a pas besoin de nouveautés. Il a besoin d'un choix : ce qu'on garde, ce qu'on masque, ce qu'on reporte, et d'un accueil élève qui dise « voici ce que tu fais maintenant ».

## Pour qui

- **Élève** (collège et lycée, téléphone Android d'entrée de gamme, réseau faible, habitué de WhatsApp) : de l'inscription au résultat de son premier exercice.
- **Enseignant** (téléphone d'abord) : de l'inscription au suivi de ce que ses élèves ont fait.
- **Touré et Konan**, développeurs juniors : exécuter seuls, après le 27, les lots qui suivent le pilote.

## Pourquoi maintenant

- **Mardi 27 octobre** : pilote avec les contacts du porteur (élèves et enseignants), qui sert aussi de test fermé Google Play.
- **Lundi 2 novembre** : arrivée des écoles pilotes.
- **Vers le 10 novembre** : publication publique sur le Play Store, au plus tôt 14 jours après le début du test fermé.

## Hors périmètre

- **Paiement et abonnement** : lancement gratuit. Pas de case « Paiement », pas d'état « Abonnement terminé ». Le chantier `abonnement-mobile-money` reste au cadrage.
- **Espaces Direction et Équipe** : inchangés et hors recette. Aucune direction invitée avant le 2 novembre.
- **Annonces rédigées par l'enseignant** : masquées. L'élève continue de lire celles de l'équipe et de la direction.
- **Changer de classe** (élève) : masqué.
- **Hors ligne, notifications poussées** : non construits, reportés.
- **Parent** : aucun espace (retiré du plan le 2026-09-22).
- **Nouvelle fonctionnalité** autre que l'accueil élève et l'inscription par code : refusée avant le 27.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le paiement n'existe pas : que fait-on le 27 ? | Lancement gratuit | Case « Paiement » et état « Abonnement terminé » retirés de l'accueil ; la grille passe à 7 cases (6 matières + Inviter), et le porteur garde 7 cases sans les compléter |
| Comment l'élève rejoint-il sa classe ? | Le code de classe revient sur la page d'inscription, avec une case « Je n'ai pas de code » qui ouvre la cascade DRENA → établissement → niveau → classe ; le lien de classe ouvre l'inscription avec la classe déjà chargée | **Le code à 6 caractères a été supprimé de la base le 2026-10-08** (UDR-0081) : le faire revenir est une feature de données (nouvelle colonne, génération, affichage côté enseignant, vérification à débit limité), pas un simple masquage. Voir les questions ouvertes |
| « Mobile » le 27, c'est quoi ? | Play Store obligatoire | Compte personnel neuf (un ami du porteur) : test fermé obligatoire, 12 testeurs pendant 14 jours. Le pilote du 27 **est** ce test fermé ; la PWA sert de secours. Les apps n'ont jamais tourné sur un vrai téléphone : essai à faire avant le 27 |
| Qui utilise l'app le 27 ? | Les contacts du porteur, puis les écoles pilotes à partir du 2 novembre | Le pilote est accompagné : on peut masquer plus et corriger vite. Plus de 200 élèves possibles dans le test fermé |
| Que garde l'enseignant en plus de la boucle assigner → faire → voir ? | Suivi par élève, Fiches à revoir, plusieurs établissements | Les annonces de l'enseignant sont masquées : sa barre basse passe de 4 à 3 onglets |
| Que garde l'élève en plus du cœur ? | Historique, Fiches à revoir, annonces avec lecture audio | « Changer de classe » masqué dans le profil |
| Direction et Équipe ? | Inchangées, hors recette | Aucun lot ne les touche |
| Brouillons d'accueil élève : « Ma classe » ou « Wave » ? | « Wave », **avant le 27** | Le brouillon « Ma classe » est l'accueil en production ; « Wave » est à construire. C'est l'écran le plus vu du pilote, refait en 4 jours : il faut une UDR figée tôt et un retour arrière prévu |
| Brouillons enseignant ? | Aucun : partir de l'existant, épuré | Pas de refonte enseignant ; masquages et réordonnancement seulement |
| Qui code avant le 27 ? | L'orchestrateur, en une PR le lundi 26 | Touré et Konan restent sur la recette du samedi |
| Le code de classe (supprimé le 2026-10-08) : avant ou après le 27 ? | Avant le 27 | Deux gros morceaux en quatre jours (accueil « Wave » et code). Le code touche un point déjà exploité (vérification énumérable, ID-07) : revue de sécurité obligatoire avant fusion |
| Calendrier et équipe | Recette de l'existant par Touré et Konan le vendredi 23 ; l'équipe code samedi 24, dimanche 25, lundi 26 et mardi 27 | Le gel « dimanche soir » ne tient plus pour ce qui se code samedi : les UDR de l'accueil élève et de l'inscription doivent être figées **vendredi 23 au soir**. Touré et Konan exécutent des lots dès samedi, pas seulement après le 27 |
| Accueil sur ordinateur (le brouillon n'existe qu'en téléphone) | Colonne centrée et barre latérale actuelle | Un seul gabarit : l'accueil du téléphone, centré, à côté de la barre latérale Accueil · Cours · Ma classe |
| L'orange de Lnclass Teacher contre « une seule couleur de marque » | Orange en accent fin | Le bleu reste la marque ; l'orange ne sert qu'à la barre fine du haut et à l'icône de l'app Teacher |
| Deux ambres d'urgence (app et charte) | Valeurs de la charte | Un seul jeu de jetons d'urgence : texte #8a4a00 sur #fff1dc, point #f08c00 ; il remplace l'avertissement actuel |
| Premières maquettes « Wave » (2026-10-23) : qu'est-ce qui ne va pas ? | Trop de bleu foncé, trop de couleurs, manque de contraste | On garde le bandeau bleu façon Wave, mais plus clair et avec moins d'aplats. Les cases de matière passent sur un fond neutre, seule l'icône est colorée. Références visuelles : Wave et Djamo, captures à fournir par le porteur. Ordre de travail : décisions, puis agencement des écrans en gris, puis couleurs |
| Que prendre de Wave et de Djamo ? (captures du porteur, 2026-10-23) | **De Wave** : la simplicité ; le changement de compte en haut à droite ; un logo discret dans la carte ; la grille ; l'annonce ; l'historique ; pas de barre de navigation en bas. **De Djamo** : le bandeau court sur lequel la carte déborde (en bleu chez nous) ; une carte blanche avec libellé gris, grande valeur et bouton pilule bleu ; un fond blanc ; des icônes colorées sur des ronds tous de la même teinte claire ; l'avatar à gauche ; « Besoin d'aide ? » à droite | La carte du haut quitte le dégradé bleu foncé : seul le bandeau reste bleu, ce qui règle le « trop de bleu foncé ». L'élève n'a toujours pas de barre basse. Le sens de « changement de compte » pour un élève reste à préciser |
| Carte et bandeau façon Djamo : quel contenu, quel bleu ? | Sous l'avatar, une pastille de la classe qui mène à Ma classe (le changement de classe reste masqué). Bandeau en bleu Lnclass vif #00a0ff. À droite dans la carte, la grande icône de la matière | Le blanc sur #00a0ff ne se lit pas (contraste 2,9:1). Tout texte posé sur le bandeau va donc dans une pastille blanche à texte bleu, comme la pastille de compte de Wave : « Besoin d'aide ? » et la classe sous l'avatar. Le logo discret va dans un coin de la carte |
| Menu de l'avatar élève : on le supprime (l'avatar ouvrirait le profil) ? | Non, on garde le menu. « Mode sombre » et « Se déconnecter » quittent la page Profil pour le menu seul ; « Modifier mon code secret » entre dans le menu | Menu validé : en-tête (nom, classe), Mon profil, Modifier mon code secret, Mode sombre, Se déconnecter. Accueil, Cours, Ma classe, Mon historique et Besoin d'aide sortent du menu, car l'accueil les porte déjà. Le code secret quitte la page Profil, qui ne garde que les informations : photo, nom, numéro, classe, établissement, date d'inscription. Le libellé est « code secret », le mot employé partout dans l'app, et non « PIN » |
| Ma classe répète l'accueil (exercices à faire, exercices faits) : on l'allège ? | Non, Ma classe garde tout. C'est **« À faire ensuite » qui sort de l'accueil** | L'accueil montre le prochain exercice (la carte du haut) ; Ma classe montre tout le travail de la classe. « Et N autres en retard » sur la carte mène à Ma classe. Les fiches à revoir, qui devaient être des lignes de « À faire ensuite », doivent trouver une autre place |
| Où vont les fiches à revoir (la remédiation) ? Trois options montrées en gris | **Option A** : une section « Fiches à revoir » dans Ma classe, juste après les exercices assignés ; quand tout le travail assigné est fait, la carte du haut de l'accueil propose la plus ancienne fiche à revoir | L'accueil ne porte pas de ligne permanente. La carte du haut gagne un état « À revoir » (libellé, fiche, note obtenue, bouton « Revoir la fiche ») qui remplace l'état « tout fait » tant qu'une fiche reste à revoir |
| Profil élève : la grande carte du haut (photo, nom, classe) répète les lignes du dessous. On la garde ? | Non (option A) : la page commence par « Mes informations » | Six lignes : Photo (Ajouter), Nom (Modifier), Numéro (Changer), Classe, Établissement, Inscrit·e le. La classe n'a pas d'action, car le changement de classe est masqué |

## Cas limites identifiés

- **Élève sans classe** (cascade abandonnée, classe archivée) : l'accueil « Wave » doit garder un état « Choisis ta classe ».
- **Classe sans enseignant sur Lnclass** : pas d'exercice assigné ; l'accueil propose l'exercice du jour et « Inviter mon enseignant » (déjà en production).
- **Plusieurs exercices en retard** : la carte du haut montre le plus ancien et « Et N autres en retard ».
- **Lien de classe régénéré par l'équipe** entre l'envoi WhatsApp et l'inscription : l'élève tombe sur la cascade, pas sur une erreur.
- **Collégien de moins de 13 ans** sans compte Google : il ne peut pas rejoindre le test fermé ; il passe par la PWA.
- **Enseignant de plusieurs établissements** : l'accueil et les classes ne montrent que l'établissement courant (UDR-0098).

## Questions encore ouvertes

- Accueil « Wave » : retour à l'accueil actuel si la recette de lundi échoue (interrupteur proposé, pas encore tranché) ?
- Carte des écrans enseignant : accueil réordonné autour de « ce que mes élèves ont fait » (à montrer en images).
- Design system : fond et gris chauds (crème, actuels) ou froids (blanc, charte « Wave ») pour toute l'app ; encre, carte du haut et teinte menthe à consolider dans le bloc `@theme`.
- Périmètre ([`perimetre.md`](perimetre.md)) : proposé, à valider ligne à ligne par le porteur.
