# PRD — Entrée et accueil de l'élève allégés

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Sept décisions du porteur (programme `retours-terrain-tiassale`, 2026-11-21) allègent l'entrée (`/student`), l'inscription (`/student-signup`, `/c/<jeton>`) et l'accueil (`/students`) de l'élève : moins de texte, un pavé numérique pour confirmer son code secret, un QR de l'établissement à la place du sigle, la fenêtre « Ton premier exercice » à la place de la carte, et une tuile « Inviter ». Précision de l'orchestrateur (2026-11-21) : la fenêtre revient sur chaque écran de l'élève tant qu'il n'a fait aucun exercice.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur | Ouvrir l'adresse d'un établissement (QR) : elle mène à l'entrée élève, établissement gardé ; s'inscrire comme aujourd'hui | Apprendre par cette adresse autre chose que ce que la recherche publique d'établissement dit déjà ; dépasser le débit de l'adresse |
| Student (connecté) | Voir le QR de l'établissement de sa classe principale ; inviter par la tuile ; voir la fenêtre du premier exercice tant qu'il n'a rendu aucune copie | Voir la fenêtre d'un autre élève (la fenêtre ne lit que l'élève connecté) |
| Teacher, SchoolStaff, Team (connectés) | — : l'adresse du QR les renvoie à leur accueil | — |
| Parent | — (hors périmètre) | — |

Règles d'autorisation : la page de la fenêtre est réservée au rôle `student` (`allow_roles :student`), et ne lit que `current_actor` ; l'adresse d'établissement est publique (`allow_unauthenticated_access`), comme la recherche d'établissement (ADR-0029, ADR-0050) ; l'inscription rejuge l'établissement envoyé (`RegisterStudent`, inchangé).

## 3. Parcours utilisateur

### Chemin nominal

1. Le camarade scanne le QR sur l'accueil d'un élève : l'entrée élève s'ouvre (numéro et code secret, sans phrase d'explication).
2. Numéro inconnu : l'étape « Nouveau sur Lnclass » montre son numéro, 4 cases et un pavé numérique ; « Créer mon compte » est gris.
3. Il tape 4 chiffres : au 4e, l'envoi part seul. Identiques : une coche verte, puis l'inscription s'ouvre, l'établissement déjà choisi ; il choisit niveau et classe.
4. À l'étape « Toi » : nom, prénoms, genre — plus de bloc « Ton numéro ». Son compte se crée ; il arrive sur l'accueil.
5. La fenêtre « Ton premier exercice » s'ouvre : « Commencer » ou la fermer d'un geste.
6. Sur l'accueil : la carte de la classe porte le QR de l'établissement ; sous « Mes matières », la tuile « Inviter » ouvre le partage WhatsApp de la classe.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Codes différents au 4e chiffre | « Les deux codes sont différents. » ; les 4 cases se vident ; le bouton redevient gris |
| Sans JavaScript, étape « Nouveau sur Lnclass » | Le champ de confirmation et le bouton actuels ; le serveur juge ; même message d'erreur |
| Entrée expirée pendant la confirmation | Retour à l'entrée, « Ton entrée a expiré » (inchangé) |
| Adresse d'un établissement inactif, en brouillon ou inconnu | L'entrée élève standard, sans message ni établissement gardé |
| Adresse d'établissement ouverte par un connecté (tout rôle) | Son accueil (inchangé pour toute inscription) |
| Adresse d'établissement par un visiteur qui a déjà un compte | L'entrée le connecte ; l'établissement est oublié |
| Plus de 60 ouvertures par minute de l'adresse depuis une même adresse IP | 429, page « Trop de tentatives » sans rien révéler |
| Arrivée sur `/student-signup` sans l'entrée | Trois étapes, numéro et code demandés (inchangé ; à trancher dans le journal) |
| Numéro pris entre l'entrée et l'inscription | L'erreur du numéro et « Ce n'est pas mon numéro » à l'étape « Toi » |
| Élève qui ferme la fenêtre | Elle revient au chargement de l'écran suivant ; jamais deux fois sur le même écran chargé |
| Élève qui a rendu au moins une copie | Plus jamais de fenêtre, sans requête sur les écrans suivants (drapeau de session) |
| Écran d'exercice (mode concentré) | Jamais de fenêtre |
| Élève sans exercice à proposer, sans classe, hors ligne | Pas de fenêtre |
| Élève sans classe principale active | Ni carte de classe, ni QR, ni tuile « Inviter » (inchangé) |

## 4. Critères d'acceptation

```gherkin
# CA-1 — entrée sans phrases (vue, contrôleur)
Quand un visiteur ouvre /student
Alors la page ne contient ni « Ton numéro et ton code secret : on te connecte, ou on crée ton compte. »
Et ni « Pas encore de compte ? Tape ton numéro et choisis un code secret : on le crée ensemble. »

# CA-2 — pavé numérique (système, JavaScript)
Étant donné un numéro inconnu et le code 2468 tapés à l'entrée
Quand l'étape « Nouveau sur Lnclass » s'ouvre
Alors 4 cases vides, un pavé de 10 chiffres et « Effacer » sont visibles
Et « Créer mon compte » est désactivé
Quand l'élève touche 2, 4, 6
Alors 3 cases sont remplies et le bouton est toujours désactivé

# CA-3 — codes identiques (système, JavaScript)
Quand l'élève touche 2, 4, 6, 8 sur le pavé
Alors une coche verte apparaît et l'inscription s'ouvre sans autre geste

# CA-4 — codes différents (système, JavaScript)
Quand l'élève touche 1, 1, 1, 1 sur le pavé
Alors « Les deux codes sont différents. » s'affiche
Et les 4 cases sont vides et « Créer mon compte » est désactivé

# CA-5 — sans JavaScript (contrôleur)
Quand on envoie la confirmation « 1111 » pour le code « 2468 »
Alors 422 et « Les deux codes sont différents. »
Et quand on envoie « 2468 », la réponse renvoie à l'inscription (inchangé)

# CA-6 — plus de « J'ai le code de ma classe » (vue, système)
Quand un visiteur ouvre l'inscription, avec ou sans entrée
Alors ni le lien « J'ai le code de ma classe », ni le champ du code de classe n'y sont
Et la recherche d'établissement et sa cascade y sont
Et /c/<jeton> valable ouvre toujours l'inscription de sa classe

# CA-7 — numéro non redemandé (vue, système)
Étant donné une entrée confirmée
Quand l'élève arrive à l'étape « Toi »
Alors il n'y a ni champ ni bloc « Ton numéro »
Et son compte est créé avec le numéro de l'entrée

# CA-8 — numéro pris entre-temps (contrôleur)
Étant donné une entrée confirmée dont le numéro est pris avant l'envoi
Quand l'élève envoie l'étape « Toi »
Alors l'erreur du numéro et « Ce n'est pas mon numéro » s'affichent à cette étape

# CA-9 — adresse d'établissement (contrôleur)
Quand un visiteur ouvre l'adresse d'un établissement actif
Alors il est renvoyé à /student, l'établissement gardé en session
Et quand l'adresse vise un établissement inactif, en brouillon ou inconnu
Alors il est renvoyé à /student, sans établissement gardé, par la même réponse
Et quand un connecté l'ouvre, il est renvoyé à son accueil
Et au-delà de 60 ouvertures par minute depuis une adresse, la réponse est 429

# CA-10 — établissement préchoisi après l'entrée (système)
Étant donné un visiteur arrivé par l'adresse d'un établissement
Quand il tape un numéro inconnu, son code et sa confirmation
Alors l'inscription s'ouvre, cet établissement choisi et ses niveaux proposés
Et son compte est créé dans la classe qu'il choisit

# CA-11 — QR sur la carte de classe (vue)
Étant donné un élève dans une classe principale active
Quand il ouvre l'accueil
Alors la carte de la classe porte un QR (SVG) dont l'adresse est celle de son établissement
Et le sigle n'y est plus

# CA-12 — la carte « Ton premier exercice » quitte l'accueil (vue)
Étant donné un élève qui n'a rendu aucune copie
Quand il ouvre l'accueil
Alors la carte #student_first_exercise n'y est pas
Et le cadre différé de la fenêtre y est

# CA-13 — la fenêtre (contrôleur, système)
Étant donné un élève qui vient de s'inscrire
Quand il arrive sur l'accueil
Alors la fenêtre « Ton premier exercice » s'ouvre, avec « Commencer » et la fermeture
Quand il la ferme puis ouvre une matière
Alors elle s'ouvre de nouveau
Quand il ouvre un exercice (mode concentré)
Alors elle ne s'ouvre pas

# CA-14 — fin de la fenêtre (contrôleur)
Étant donné un élève qui a rendu une copie
Quand le cadre de la fenêtre est demandé
Alors il est vide, et le drapeau de session est posé
Et les écrans suivants ne portent plus le cadre

# CA-15 — page de la fenêtre réservée (contrôleur)
Quand un enseignant ou un visiteur demande la page de la fenêtre
Alors il est refusé (règle des rôles de l'application)

# CA-16 — tuile « Inviter » (vue)
Étant donné un élève dans une classe principale active
Quand il ouvre l'accueil
Alors le bloc « Invite tes camarades » montre une tuile « Inviter » au format des matières, qui envoie vers le partage de classe
Et l'ancienne bannière « Invite tes camarades » n'y est plus
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | aucun changement (règles existantes : `EnterAsStudent`, `RegisterStudent`) |
| Infrastructure | une colonne de plus lue par la requête de l'accueil (identifiant public de l'établissement) ; une requête bornée « l'élève a-t-il rendu une copie » ; recherche d'un établissement actif par identifiant public (existante si possible) |
| Delivery | route publique de l'adresse d'établissement ; route élève de la fenêtre ; l'entrée garde l'établissement ; l'inscription le préchoisit |
| UI | entrée (pavé), inscription (sans code ni bloc numéro), carte de classe (QR), fenêtre, tuile « Inviter » |

## 6. Décisions rattachées

- ADR-0145 — l'adresse du QR de l'établissement et sa menace
- UDR-0180 — entrée et inscription allégées, pavé numérique
- UDR-0179 — QR, fenêtre « Ton premier exercice », tuile « Inviter » (remplace UDR-0174 §3 sur la place de la carte)
