# Périmètre du MVP — Lnclass Teacher & Student

> Livrable 1 du chantier [`mvp-teacher-student`](memo.md). **Statut : proposé, à figer par le porteur vendredi 23 octobre au soir.**
> Règle de tri : en cas de doute, **masquer** vaut mieux que construire. « Masqué » = le code reste, l'entrée disparaît de l'interface du rôle ; « Reporté » = n'existe pas encore, viendra après le pilote.

Légende : **Gardé** · **Modifié** (gardé, retouché avant le 27) · **Construit** (nouveau avant le 27) · **Masqué** · **Reporté**

## Élève — Lnclass Student

| Fonctionnalité | Décision | Pourquoi |
|---|---|---|
| Accueil « Wave » : carte « prochain exercice », grille de 7 cases, annonces, Historique (« À faire ensuite » retiré le 2026-10-23 : Ma classe porte la liste) | **Construit** | L'accueil doit répondre à « qu'est-ce que je fais maintenant ? » dès l'ouverture, pas renvoyer vers « Entrer en classe » |
| Inscription par code de classe, case « Je n'ai pas de code » | **Construit** | Décision du porteur : un code tapé est la voie la plus directe quand le prof l'écrit au tableau |
| Inscription par la cascade DRENA → établissement → niveau → classe | **Modifié** | Gardée, mais seulement derrière « Je n'ai pas de code » : elle reste la voie de secours |
| Inscription par le lien de classe (classe préremplie) | **Gardé** | C'est la voie WhatsApp, la plus naturelle pour le pilote |
| Connexion par numéro et code secret, code oublié | **Gardé** | Socle, déjà recetté |
| Message « Utilisez Lnclass Teacher » si un prof se connecte à l'app élève | **Gardé** | Évite le cul-de-sac le plus fréquent entre les deux apps |
| Exercice du jour proposé par Lnclass | **Gardé** | Donne du travail à l'élève dont le prof n'est pas encore sur Lnclass |
| Session d'exercice (mode concentré, correction immédiate) | **Gardé** | Le cœur du produit |
| Résultat de session : note sur 20, badge, progrès, effet sur la fiche | **Gardé** | La récompense qui fait revenir |
| Cours par matière et lecture d'une fiche (formules, images) | **Gardé** | Ouvert depuis les cases de la grille ; c'est la révision |
| Fiches à revoir | **Modifié** | Gardées, mais intégrées comme lignes de « À faire ensuite » : une information dite une seule fois |
| Ma classe (classe, enseignants, inviter son enseignant) | **Gardé** | Accessible par le menu ; ce n'est plus la carte du haut |
| Historique (notes sur 20, par mois, période de chaque classe) | **Gardé** | La preuve de progression, celle qu'on montre aux parents |
| Annonces de l'équipe et de la direction, lecture audio, masquer | **Gardé** | Le canal de l'équipe pour accompagner les testeurs |
| Inviter (case de la grille : partager Lnclass) | **Gardé** | La croissance du pilote passe par le bouche-à-oreille WhatsApp |
| Profil : nom, photo, code secret, se déconnecter | **Gardé** | Socle |
| Changer de classe depuis le profil | **Masqué** | Cas rare en 5 jours de pilote ; une ligne de moins dans le profil |
| Mode sombre | **Modifié** | Gardé, mais déplacé de l'en-tête vers le menu de l'avatar : l'en-tête garde aide et avatar seulement |
| Installer l'app (bandeau PWA) | **Gardé** | Secours si l'élève ne peut pas rejoindre le test fermé Play Store |
| App Android Lnclass Student (test fermé Play Store) | **Gardé** | Le pilote est le test fermé ; essai sur un vrai téléphone avant le 27 |
| Carte d'aide et FAQ, lien WhatsApp prêt | **Gardé** | Seul support du pilote |
| Paiement et abonnement Mobile Money | **Reporté** | Lancement gratuit ; aucun code n'existe |
| Hors ligne | **Reporté** | Non construit |
| Notifications poussées | **Reporté** | Non construites |
| Consentement WhatsApp sur le profil | **Reporté** | Décision encore « Proposé » (UDR-0122), dépend de `verification-whatsapp` |

## Enseignant — Lnclass Teacher

| Fonctionnalité | Décision | Pourquoi |
|---|---|---|
| Inscription par code d'établissement ou lien d'invitation, matières | **Gardé** | Déjà recettée en deux voies |
| Connexion, code oublié | **Gardé** | Socle |
| Accueil | **Modifié** | Réordonné autour de « ce que mes élèves ont fait » ; voir la carte des écrans |
| Mes classes : déclarer, modifier, archiver | **Gardé** | Sans classe, pas de boucle |
| Code de classe à 6 caractères affiché sur la page de classe, à dicter ou partager | **Construit** | Contrepartie enseignant du code tapé par l'élève |
| Partager le lien de classe sur WhatsApp | **Gardé** | La voie d'inscription élève la plus sûre |
| Catalogue et assignation d'un exercice avec date limite | **Gardé** | Premier geste du prof |
| Rapport d'un exercice et prochain geste | **Gardé** | Ce que le prof vient voir après avoir assigné |
| Liste des élèves par note sur 20, fiche d'un élève | **Gardé** | Décision du porteur : le suivi par élève |
| Fiches à revoir de la classe | **Gardé** | Décision du porteur |
| Plusieurs établissements, établissement courant | **Gardé** | Invisible pour qui n'a qu'une école, indispensable aux autres |
| Retirer un élève de sa classe | **Gardé** | Protège la classe d'un inscrit par erreur |
| Inviter un collègue, page Croissance | **Gardé** | Croissance du pilote ; déjà en production |
| Annonces rédigées par l'enseignant | **Masqué** | Double WhatsApp, que les profs utilisent déjà ; un onglet de moins (4 → 3) |
| Profil, photo, code secret, mode sombre | **Gardé** | Socle |
| App Android Lnclass Teacher (test fermé Play Store) | **Gardé** | Même règle que l'app élève |
| Validation des comptes enseignants en attente | **Reporté** | Déjà en pause (ADR-0073) |
| Notifications poussées, résumé quotidien | **Reporté** | Non construites |

## Autres rôles

| Rôle | Décision | Pourquoi |
|---|---|---|
| Direction d'établissement | **Gardé, hors recette** | Aucune direction invitée avant le 2 novembre |
| Équipe Lnclass | **Gardé, hors recette** | Crée le contenu et suit le pilote ; ses écrans ne sont pas montrés aux testeurs |
| Parent | **Reporté** | Retiré du plan le 2026-09-22 |
