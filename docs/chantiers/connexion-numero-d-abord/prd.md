# PRD — Connexion et inscription « numéro d'abord »

## 1. Contexte

La connexion demande d'abord le numéro seul ; le numéro décide de la suite : un compte → le code secret ; pas de compte → la création du compte, numéro repris. Le code secret d'un nouveau compte (élève ou enseignant) se tape une seule fois. L'inscription enseignant suit l'ordre de l'élève : numéro, code secret, profil.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur | Savoir si un numéro a un compte (débit borné) ; créer un compte élève ou enseignant | Lire le nom, le rôle ou la classe d'un compte ; créer un second compte sur un numéro |
| Élève, enseignant, direction, équipe | Se connecter : numéro, puis code secret (puis second facteur s'il l'a) | Contourner le verrouillage par numéro ou le plafond des codes faux |

Pas de policy : l'acteur n'existe pas encore (ADR-0028, comme l'entrée élève).

## 3. Parcours utilisateur

### Chemin nominal

1. `/login` : le numéro seul, « Continuer ».
2. Le numéro a un compte : le numéro affiché, « Ce n'est pas mon numéro », le code secret, « Se connecter ».
3. Le numéro n'a pas de compte : « Ce numéro n'a pas encore de compte », le numéro, deux boutons « Élève » et « Enseignant(e) », « Ce n'est pas mon numéro ».
4. « Élève » : « Nouveau sur Lnclass », « Entre ton code secret » (pavé, une seule fois), puis l'inscription élève (numéro et code gardés).
5. « Enseignant(e) » : l'inscription enseignant s'ouvre à l'étape 2 « Votre code secret » (numéro repris), puis l'étape 3 « Votre profil » (nom, prénoms, genre, établissement choisi dans la liste, matière).
6. `/student` suit la même logique : numéro seul ; compte → code ; pas de compte → « Nouveau sur Lnclass ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Code faux sur un numéro inscrit | « Code secret incorrect. » sous le champ, « Code secret oublié ? », numéro gardé |
| Trop de codes faux depuis une adresse (5 par minute) | « Trop de tentatives », même avec le bon code |
| Plus de 120 envois par minute ou 600 par heure depuis une adresse (connexion et entrée élève confondues) | 429 « Trop de tentatives » |
| Numéro et code envoyés ensemble (coque, gestionnaire de mots de passe) | Connexion comme avant, message unique sur un échec |
| Entrée expirée | Retour au numéro, message « a expiré » |
| Numéro qui a reçu un compte entre-temps | Jamais de second compte : le code est essayé comme une connexion |
| Inscription enseignant ouverte directement | Étape 1 « Votre numéro » |
| Lien `/i/<jeton>` | Étapes 1, 2, 3 ; l'établissement du lien est rappelé à l'étape 3, sans recherche |

## 4. Critères d'acceptation

```gherkin
CA-1 Étant donné un compte sur un numéro
Quand on envoie ce seul numéro sur /login
Alors la page affiche le numéro et le champ du code secret, sans nom ni rôle

CA-2 Étant donné un numéro sans compte
Quand on l'envoie sur /login
Alors la page dit « Ce numéro n'a pas encore de compte », affiche le numéro et propose « Élève » et « Enseignant(e) »

CA-3 Étant donné l'écran « pas de compte » de /login
Quand on choisit « Élève »
Alors « Nouveau sur Lnclass » demande « Entre ton code secret » une seule fois, puis l'inscription élève s'ouvre sans redemander le numéro

CA-4 Étant donné l'écran « pas de compte » de /login
Quand on choisit « Enseignant(e) »
Alors l'inscription enseignant s'ouvre à l'étape du code secret, numéro repris, et le compte se crée sans confirmation du code

CA-5 Étant donné un numéro inscrit à l'étape du code de /login
Quand on envoie un code faux
Alors « Code secret incorrect » et « Code secret oublié ? » s'affichent, et l'échec compte pour le verrouillage du numéro

CA-6 Étant donné une adresse qui a envoyé 5 codes faux dans la minute (connexion et entrée élève confondues)
Quand elle envoie le bon code
Alors elle reçoit « Trop de tentatives »

CA-7 Étant donné une adresse qui a envoyé 120 numéros dans la minute sur /login et /student confondus
Quand elle en envoie un 121e
Alors elle reçoit 429

CA-8 Étant donné un numéro et un code envoyés ensemble sur /login
Quand le code est faux
Alors le message reste « Numéro ou code secret incorrect »

CA-9 Étant donné /student
Quand un nouveau numéro est envoyé puis son code tapé une fois
Alors l'inscription élève s'ouvre, numéro et code gardés, sans écran de confirmation

CA-10 Étant donné un numéro devenu inscrit entre l'écran « Nouveau » et l'envoi du code
Quand le code est envoyé
Alors aucun second compte n'est créé : c'est une connexion

CA-11 Étant donné l'inscription enseignant ouverte directement
Quand l'enseignant remplit numéro, code (une fois) et profil sans code d'établissement
Alors le compte est créé dans l'établissement choisi, voie standard

CA-12 Étant donné un lien /i/<jeton> valable
Quand l'enseignant s'inscrit
Alors il est rattaché à l'établissement du lien, comme avant

CA-13 Étant donné l'écran du code ou « pas de compte »
Quand on touche « Ce n'est pas mon numéro »
Alors l'entrée est oubliée et le numéro revient, modifiable
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `UseCases::Identity::EnterByNumber` (remplace `EnterAsStudent`, numéro seul ou numéro + code) ; `Dtos::Identity::NumberEntryInput` (code facultatif) ; aucun port nouveau (`users#find_by_contact`, `Authenticate`) |
| Infrastructure | rien |
| Delivery | `Identity::SessionsController` (étapes), `Identity::StudentEntriesController`, `Identity::TeacherRegistrationsController` ; concern `NumberEntryLimit` (compteurs partagés) ; `StudentEntrySession` garde `known` |
| UI | `identity/sessions/new`, `identity/student_entries/new`, `identity/teacher_registrations/_form` et `new` |

## 6. Décisions rattachées

- ADR-XXXX-connexion-revele-un-numero-inscrit — amende ADR-0141 §4.1 (« `/login` garde son message unique ») et ADR-0050.
- UDR-XXXX-connexion-numero-d-abord — amende UDR-0176 (§3.2, §3.5), UDR-0180 (code une seule fois) et UDR-0135/UDR-0079 pour l'enseignant.
