# Memo — Lnclass hors connexion

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-12 |
| **Branche** | `feature/hors-connexion` |
| **Programme** | — |

---

## Le problème

Un élève sans données mobiles, ou dans une zone sans réseau, ne peut rien faire dans Lnclass : la moindre page affiche « Pas de connexion ». Même la leçon qu'il a lue la veille, ou l'exercice qu'il a ouvert en classe, ne s'ouvre plus. Il ne peut ni réviser ni s'entraîner. Le réseau est cher et intermittent pour une grande partie des élèves visés. L'enseignant, lui, ne peut pas relire ses classes ni les résultats en dehors d'une connexion.

## Pour qui

- **L'élève d'abord** : il relit hors ligne les leçons et les exercices qu'il a déjà ouverts en ligne, rend des copies, voit sa note tout de suite, et ses copies partent seules au retour du réseau.
- **L'enseignant ensuite** : il relit hors ligne les pages de ses classes qu'il a déjà ouvertes (liste des classes, page de classe, fiche d'un élève, suivi d'un exercice, résultat d'une copie).

Décisions du porteur, non rouvertes : élève et enseignant (élève d'abord dans le plan) ; tout hors ligne pour l'élève, correction comprise, corrigé gardé sur le téléphone et lisible par l'élève ; copies synchronisées sans doublon, sans perte, avec l'heure d'origine ; site installable (PWA) dont profite l'app Android ; seules les pages déjà ouvertes en ligne sont gardées, rien n'est téléchargé d'avance.

## Pourquoi maintenant

La bêta recrute des élèves en ce moment (chantier `acces-beta`). Le hors connexion est ce qui distingue Lnclass auprès d'élèves dont le forfait s'épuise en milieu de mois ; un bêta-testeur qui voit « Pas de connexion » sur une leçon déjà lue ne revient pas.

## Hors périmètre

- **Télécharger d'avance** une matière, un chapitre, une classe ou « tout ». Seul ce qui a été ouvert en ligne est gardé.
- **Écrire hors ligne pour l'enseignant** : ni assigner, ni annoncer, ni créer de classe, ni corriger. Il n'existe aujourd'hui aucune correction manuelle (ADR-0115, option E) : l'enseignant n'a rien à écrire hors ligne, donc **aucun conflit de synchronisation côté enseignant**.
- **Démarrer hors ligne un exercice jamais ouvert**, même assigné.
- Les annonces, la messagerie, les audios, le blog, la boutique, la facturation, l'activation de carte, le profil, l'inscription et la connexion hors ligne.
- **Parent, direction (`SchoolStaff`), équipe (`Team`)** : rien n'est gardé pour eux. Leurs pages restent réseau seul (mêmes données sensibles, aucun besoin exprimé).
- Les images téléversées des questions et des articles (servies `no-store`) : hors ligne, l'image manque et son texte de remplacement s'affiche. Suite possible.
- La synchronisation en arrière-plan quand l'app est fermée (`Background Sync`, absent de Safari) : la file part à l'ouverture suivante ou au retour du réseau, page ouverte.
- L'iPhone dans le navigateur sans installation : marche, mais Safari peut tout effacer après 7 jours sans visite ; on ne le contourne pas.
- Une app Android qui détecte le réseau en natif : la coque affiche le site, et le programme d'arrière-plan fait le travail.
- La note en points d'une réponse rédigée ou d'un travail sur cahier : jamais notée, en ligne comme hors ligne.

## Ce que le grill a révélé

> Grill joué par l'orchestrateur sur la base du code (porteur indisponible : options prudentes, reportées dans `## À trancher` du journal).

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Aujourd'hui, le corrigé arrive-t-il sur le téléphone ? | Non. La note est calculée **seulement sur le serveur** ; la page de la copie, du sujet et de la leçon ne portent jamais la bonne réponse (ADR-0119, requête de la copie) | Il faut **un paquet de corrigé** par exercice, servi à part, et **un correcteur JavaScript** qui rejoue les règles du domaine. L'ADR amende l'ADR-0119 (« jamais `correct` dans la page ») pour le seul paquet |
| Deux correcteurs (Ruby et JavaScript) peuvent-ils diverger ? | Oui, c'est sûr à terme | La note locale est **provisoire**, remplacée par celle du serveur au retour. Une **table de cas partagée** (JSON) est jouée par les tests Ruby et par les tests JavaScript : un écart casse la CI |
| L'enseignant a-t-il quelque chose à écrire hors ligne ? | Non : pas de correction manuelle aujourd'hui | Enseignant = **lecture seule** ; pas de conflit à résoudre ; son lot ne touche ni la file ni la synchronisation |
| Deux élèves sur un même téléphone ? | Cas courant (fratrie) ; le cookie de session vit 30 jours | **Clé d'appareil opaque par compte**, purge au changement de compte et à la déconnexion, durée de vie de 30 jours pour toute page gardée (menace P1–P4) |
| Une copie hors ligne, puis l'élève se déconnecte en ligne avant l'envoi ? | La déconnexion purgerait la copie | La déconnexion **envoie d'abord la file**, puis purge ; une copie refusée est annoncée avant la purge |
| L'horloge du téléphone peut mentir. Quelle heure fait foi ? | Le porteur veut l'heure d'origine | Heure d'origine **gardée mais bornée** (pas dans le futur, pas plus de 30 jours, pas avant l'ouverture du paquet) ; l'heure de réception est gardée à côté ; l'enseignant voit « rendue hors ligne » |
| L'accès bêta ou l'abonnement prend fin entre la copie et l'envoi ? | Le serveur est la référence | Droits **rejoués à la réception** ; refusée, la copie reste en file 30 jours avec son motif |
| L'exercice change entre l'ouverture et l'envoi ? | Les questions peuvent ne plus correspondre | Empreinte de version dans le paquet ; copie `:stale` refusée, montrée « non comptée » (option prudente, à trancher) |
| Un élève multi-classes, ou qui change d'établissement ? | La copie est attachée à l'élève et à l'exercice, pas à la classe | Rien de spécial : même règle que la copie en ligne |
| Turbo passe-t-il par la navigation que le programme intercepte ? | Non : une visite Turbo est un `fetch`, pas une navigation | Le programme doit traiter les `GET` HTML de Turbo aussi, sinon une visite hors ligne échoue sans page |
| Le WebView Android exécute-t-il le programme d'arrière-plan ? | Non établi dans le dépôt | Vérification sur téléphone au challenger (Lot A) ; si non, chantier de suivi Android, pas de blocage de l'élève web |
| Quota du navigateur, iPhone ? | Safari : quota bas, effacement après 7 jours sans visite hors app installée | Au plus **60 pages** gardées par compte (les plus anciennes sortent d'abord), `navigator.storage.persist()` demandé, purge à 30 jours. On écrit le cas iPhone dans l'aide, on ne le contourne pas |

## Cas limites identifiés

- Zéro page ouverte : hors ligne, la page « Pas de connexion » (UDR-0078) dit en plus que seules les pages déjà ouvertes sont lisibles.
- La file contient 0, 1 ou 20 copies ; au-delà de 20, l'envoi se fait par paquets de 20.
- Une copie envoyée deux fois (réseau qui coupe pendant la réponse) : une seule copie en base.
- Une copie dont l'exercice a été dépublié, ou dont l'élève a été anonymisé : refusée, sans écrire.
- Changement de compte avec une file non vide : la file de l'ancien compte reste sur l'appareil, jamais envoyée sous un autre compte ; elle part quand l'auteur se reconnecte, ou disparaît à 30 jours.
- Stockage plein : l'enregistrement d'une page ou d'une copie échoue ; une copie qui ne peut pas être gardée est **dite à l'élève** (« Copie non gardée : libère de la place »), jamais avalée.
- Réponse rédigée et travail sur cahier : rendus hors ligne, jamais notés, comme en ligne.
- Le programme d'arrière-plan d'une ancienne version : la clé de version des caches purge les anciens.

## Questions encore ouvertes

Toutes tranchées par l'option prudente et listées dans `journal.md` § À trancher (heure d'origine bornée, copie `:stale`, accès rejoué à la réception, 60 pages, 30 jours, enseignant sans écriture).
