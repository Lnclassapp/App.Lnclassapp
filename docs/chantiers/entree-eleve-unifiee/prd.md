# PRD — Une seule entrée pour l'élève : numéro et code secret

## 1. Contexte

« Je suis élève » ouvre un seul formulaire, numéro et code secret : un numéro inscrit est connecté, un numéro inconnu continue la création de son compte sans retaper ni l'un ni l'autre (D2). L'inscription enseignant commence par « Êtes-vous bien enseignant ? », avec une sortie vers l'entrée élève (D1). Voir le [memo](memo.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur | Ouvrir l'entrée élève ; se connecter avec un numéro inscrit et son code ; commencer un compte élève avec un numéro inconnu | Créer un compte sur un numéro déjà inscrit ; savoir à qui appartient un numéro inscrit |
| Compte existant (élève, enseignant, direction, équipe) | Se connecter par l'entrée élève, avec les mêmes règles qu'à `/login` (verrouillage, coque Android) | — |
| Élève connecté | — (l'entrée le renvoie à son accueil) | — |

Pas de policy : l'acteur n'existe pas encore (ADR-0028, comme `Authenticate` et `RegisterStudent`).

## 3. Parcours utilisateur

### Chemin nominal — nouvel élève

1. Accueil → « Je suis élève » → formulaire numéro + code secret.
2. Numéro inconnu → « Ce numéro n'a pas encore de compte » : le numéro est montré, l'élève confirme son code.
3. Inscription : « Ta classe » (code ou cascade), puis « Toi » (nom, prénoms, genre) → compte créé, accueil élève.

### Chemin nominal — élève inscrit

1. Accueil → « Je suis élève » → numéro + bon code → accueil élève.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Code secret qui n'a pas exactement 4 chiffres | « Le code secret compte 4 chiffres », rien n'est cherché |
| Numéro inscrit, mauvais code | « Code secret incorrect », lien « Code secret oublié ? » ; l'échec compte pour le verrouillage du numéro |
| Numéro verrouillé | Message de verrouillage de `/login` |
| Confirmation du code différente | « Les deux codes secrets ne sont pas identiques », on reste sur l'écran |
| « Corriger mon numéro » | Retour au formulaire, numéro pré-rempli, code vide |
| Lien de classe `/c/<jeton>`, visiteur | L'entrée, avec le bandeau de la classe ; nouveau : l'inscription saute « Ta classe » ; inscrit (élève) : retour au lien |
| Compte non élève par l'entrée | Connecté, envoyé vers son accueil |
| Entrée expirée (30 min) ou absente à l'envoi de l'inscription en mode entrée | Retour à l'entrée |
| Numéro pris entre l'entrée et l'inscription | Refus de l'inscription, aucun compte créé |
| Trop d'envois (120/min ou 600/h par adresse à l'entrée ; 60/min pour l'inscription qui suit) | « Trop de tentatives », rien n'est révélé |
| `/teacher-signup` | « Êtes-vous bien enseignant ? » : « Oui » ouvre le formulaire, « Non, je suis élève » l'entrée élève |

## 4. Critères d'acceptation

```gherkin
Scénario: CA-1 Le bouton de l'accueil ouvre l'entrée
  Étant donné l'accueil public
  Quand le visiteur touche « Je suis élève »
  Alors il voit le formulaire numéro + code secret

Scénario: CA-2 Numéro inscrit et bon code
  Étant donné un élève inscrit
  Quand il envoie son numéro et son code dans l'entrée
  Alors il est connecté et arrive sur son accueil

Scénario: CA-3 Un compte d'un autre rôle se connecte aussi
  Étant donné un enseignant inscrit
  Quand il envoie son numéro et son code dans l'entrée
  Alors il est connecté et arrive sur l'accueil enseignant

Scénario: CA-4 Numéro inscrit, mauvais code
  Quand un élève inscrit envoie un code faux
  Alors il lit « Code secret incorrect » et le lien « Code secret oublié ? »
  Et aucune session n'est ouverte, l'échec est compté pour son numéro

Scénario: CA-5 Numéro inconnu : confirmer puis s'inscrire sans retaper
  Quand un visiteur envoie un numéro inconnu et un code
  Alors il lit « Ce numéro n'a pas encore de compte » et son numéro
  Quand il confirme le même code
  Alors l'inscription s'ouvre sans champ numéro ni code secret
  Quand il choisit sa classe et donne nom, prénoms et genre
  Alors son compte élève est créé avec ce numéro et ce code, et il est connecté

Scénario: CA-6 Confirmation différente
  Quand le visiteur confirme un autre code
  Alors il lit que les deux codes ne sont pas identiques et rien n'est gardé

Scénario: CA-7 Jamais de compte sur un numéro existant
  Étant donné une entrée confirmée pour un numéro
  Et ce numéro inscrit entre-temps par un autre compte
  Quand l'inscription est envoyée
  Alors elle est refusée et aucun compte n'est créé

Scénario: CA-8 Le lien de classe garde sa classe
  Quand un visiteur ouvre /c/<jeton>
  Alors il voit l'entrée avec le nom de la classe
  Quand il envoie un numéro inconnu et confirme son code
  Alors l'inscription s'ouvre à l'étape « Toi », la classe du lien rappelée
  Et l'élève créé est dans cette classe

Scénario: CA-9 Élève inscrit par le lien de classe
  Quand un élève inscrit sans classe s'identifie dans l'entrée ouverte par /c/<jeton>
  Alors il revient sur la page du lien, connecté

Scénario: CA-10 Une classe sur un même wifi
  Quand 40 élèves passent par l'entrée en une minute depuis la même adresse
  Alors aucun ne lit « Trop de tentatives »
  Et le 121e envoi de la minute à l'entrée est refusé

Scénario: CA-11 Entrée expirée
  Étant donné une entrée confirmée il y a plus de 30 minutes
  Quand l'inscription est ouverte
  Alors le visiteur revient à l'entrée

Scénario: CA-12 Confirmation enseignant
  Quand un visiteur ouvre /teacher-signup
  Alors il lit « Êtes-vous bien enseignant(e) ? » et ne voit pas encore le formulaire
  Quand il touche « Non, je suis élève »
  Alors il arrive sur l'entrée élève
  Quand il revient et touche « Oui, je suis enseignant(e) »
  Alors le formulaire d'inscription enseignant s'ouvre
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Dtos::Identity::StudentEntryInput` ; use case `UseCases::Identity::EnterAsStudent` (s'appuie sur `Authenticate` et le port `users#find_by_contact`, existants) |
| Infrastructure | rien de nouveau (aucune table, aucun port) |
| Delivery | `GET/POST /student` → `Identity::StudentEntriesController` ; concern `StudentEntrySession` (l'entrée en session) ; `Classroom::StudentRegistrationsController` (mode entrée) ; `Classroom::JoinsController#new` (visiteur → entrée) ; `Identity::TeacherRegistrationsController#new` (question) |
| UI | `identity/student_entries/new` ; `identity/teacher_registrations/confirm` ; inscription élève en mode entrée ; bouton de l'accueil ; lien de `/login` |

## 6. Décisions rattachées

- ADR-XXXX-entree-eleve-revele-un-numero-inscrit — l'entrée révèle si un numéro est inscrit, débit et garde du code en session.
- UDR-XXXX-entree-eleve-unique — l'écran d'entrée, l'écran « pas encore de compte », l'inscription en mode entrée, la question enseignant.
- Pas de nouveau port : `EnterAsStudent` compose `Authenticate` et `users#find_by_contact`.
