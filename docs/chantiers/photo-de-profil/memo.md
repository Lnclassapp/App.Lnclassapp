# Memo — Photo de profil

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/photo-de-profil` |
| **Programme** | — |

---

## Le problème

Chaque compte n'est représenté que par ses initiales dans un rond coloré. Un enseignant qui a quarante élèves ne reconnaît pas « A K » d'« A K » ; l'équipe qui débloque un compte ne peut pas vérifier qu'elle parle bien à la bonne personne ; l'élève ne peut pas personnaliser son espace. Demande du porteur du 2026-09-28 : « ajoute l'option photo de profil aux users ».

## Pour qui

Les quatre rôles du shell (élève, enseignant, équipe, school_admin en attente), depuis « Mon profil ». Ceux qui **voient** la photo : la personne elle-même (menu du compte, carte du profil), l'enseignant pour ses élèves (liste de la classe), l'équipe pour le compte qu'elle retrouve (déblocage).

Public cible : téléphone d'entrée de gamme, souvent partagé, réseau lent et facturé au Mo.

## Pourquoi maintenant

La page « Mon profil » vient d'être livrée (ADR-0055, UDR-0041) : c'est le bon endroit, et le composant avatar accepte déjà une image. Le stockage objet existe depuis les imports (ADR-0047).

## Hors périmètre

- Retoucher la photo (rotation, zoom, choix du cadrage) : le cadrage est automatique, centré, carré.
- Changer la photo d'un **autre** compte (l'enseignant ou l'équipe pour un élève) ; modérer ou signaler une photo.
- Afficher la photo ailleurs que là où un avatar existe déjà : menu du compte (en-tête et barre latérale), carte « Mes informations », liste d'une classe, compte retrouvé par l'équipe. La liste des enseignants d'un établissement reste en initiales (voir la dette du journal).
- Des tailles d'image multiples produites par le serveur (aucune dépendance de traitement d'image en production).
- La photo dans les courriels, les exports, les impressions.
- Les parents et le personnel d'établissement au-delà de ce que leur shell montre déjà.

## Ce que le grill a révélé

> Grill conduit par l'agent sur la demande du porteur ; faute de porteur joignable dans la journée, chaque réponse est une **décision par défaut**, à contester en recette.

| Question posée | Réponse (décision par défaut) | Conséquence sur le chantier |
|---|---|---|
| Qui voit la photo d'un élève ? Un camarade de classe ? | Lui-même, les enseignants de sa classe, l'équipe. Jamais un autre élève, jamais un visiteur | L'image n'a **pas** d'adresse publique : chaque lecture repasse par la session et par la règle de lecture d'un compte existante |
| Une photo de téléphone pèse 3 à 8 Mo ; que paie l'élève en données ? | Le navigateur recadre et réduit **avant** l'envoi : carré de 512 px, compressé, quelques dizaines de Ko | Le travail d'image se fait sur le téléphone ; le serveur ne fait que vérifier |
| Le serveur peut-il redimensionner ? | Non : la bibliothèque d'image n'est pas dans l'image de production, et l'y ajouter a déjà cassé une construction | Aucun redimensionnement serveur ; le serveur **refuse** ce qui dépasse |
| Que refuse le serveur ? | Tout ce qui n'est pas une vraie image JPEG, PNG ou WebP (le contenu fait foi, pas le nom), plus de 1 Mo, plus de 1024 px de côté | Un message clair par cas ; rien n'est stocké ni tracé |
| Une photo prise au téléphone contient la position GPS ; que devient-elle ? | Le recadrage dans le navigateur ne la recopie pas. Si une image arrive quand même avec ces métadonnées (navigateur sans recadrage), le serveur les **retire** avant de la stocker *(révisé en phase 4 : la première réponse était « refusée » ; voir le journal)* | Lecture et retrait des segments de métadonnées côté serveur, sans bibliothèque |
| Faut-il forcer l'appareil photo ? | Non : forcer la caméra retire la galerie sur Android. Le sélecteur d'image du téléphone propose déjà « Appareil photo » et « Galerie » | Un seul champ « image » sans `capture` |
| Et si le téléphone ne sait pas recadrer (très vieux navigateur, format illisible) ? | Le fichier part tel quel et le serveur tranche : une petite image propre passe, une grosse est refusée avec un message qui l'explique | Le parcours marche aussi sans JavaScript |
| Retirer sa photo : confirmation ? | Pas de confirmation séparée : « Retirer ma photo » est dans la fenêtre de la photo, donc déjà à deux gestes, et l'action se rattrape en remettant une photo | Le fichier est effacé du stockage, pas seulement détaché |
| Faut-il tracer ? | Oui, comme le nom : `profile.photo_changed` (format, poids, dimensions ; jamais l'image) et `profile.photo_removed` | Deux actions d'audit nouvelles |
| Un enseignant voit-il la photo d'un élève d'une classe archivée ? | Oui tant que l'élève y est présent : c'est la même règle que la liste nominative | La règle « enseigne cet élève » ne regarde pas le statut de la classe |
| Le changement de photo doit-il se voir tout de suite dans le menu du compte ? | Oui, sans rechargement complet | La page se rafraîchit par Turbo après l'enregistrement |
| Un téléphone partagé : la photo reste-t-elle en cache après déconnexion ? | Cache **privé** du navigateur seulement, jamais d'un intermédiaire ; adresse changée à chaque nouvelle photo | Compromis assumé : le cache économise les données |

## Cas limites identifiés

- Fichier PDF, texte ou image renommée en `.jpg` : refus (« Choisissez une photo JPEG, PNG ou WebP. »).
- Image de plus de 1 Mo après recadrage (ou sans recadrage) : refus.
- Image très large (panorama) : recadrée au centre par le navigateur ; sans recadrage, refusée au-delà de 1024 px.
- Aucun fichier choisi puis « Enregistrer » : refus « Choisissez une photo. ».
- Retirer alors qu'il n'y a pas de photo : rien ne se passe, aucune trace.
- Remplacer une photo : l'ancienne est effacée du stockage.
- Deux onglets : le dernier enregistrement gagne.
- Un enseignant qui n'enseigne plus la classe, un autre élève, un visiteur : l'adresse de l'image répond « introuvable » ou « interdit », jamais l'image.

## Questions encore ouvertes

- Aucune bloquante. À confirmer par le porteur en recette : la liste des enseignants d'un établissement vue par l'équipe doit-elle aussi montrer les photos ?
