# PRD — Page profil de chaque utilisateur

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'entrée « Mon profil » du menu du compte est grisée dans les quatre rôles : aucune page n'existe. Chaque utilisateur connecté doit pouvoir voir ce que la plateforme sait de lui, corriger son nom, changer son numéro et changer son PIN, sans SMS. Les changements sensibles exigent le PIN actuel, coupent les autres sessions et laissent une trace d'audit ([memo](memo.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Élève | voir son profil (nom, numéro, classe principale, date d'inscription) ; modifier son nom et son prénom ; changer son numéro ; changer son PIN | voir ou modifier le profil d'un autre compte ; changer de classe depuis le profil |
| Enseignant | idem, avec son établissement et sa matière | idem ; changer d'établissement ou de matière depuis le profil |
| Équipe | idem, avec son rôle d'équipe et « Second facteur : actif » | gérer son second facteur depuis le profil (hors périmètre, lot B8) |
| school_admin (en attente) | idem, avec la mention « Compte en attente » | — |

Règle d'autorisation : `Identity::UpdateSelfPolicy` (existe, sans appelant jusqu'ici) — un acteur ne lit et ne modifie que son propre compte. Un compte d'équipe sans second facteur vérifié n'atteint pas la page (garde existante de l'authentification).

## 3. Parcours utilisateur

### Chemin nominal

1. L'utilisateur ouvre le menu du compte et choisit « Mon profil » : la page `Mon profil` s'ouvre dans le shell de son rôle.
2. Il lit ses informations (§2) dans une carte « Mes informations ».
3. **Nom** : « Modifier » ouvre une modale avec nom et prénom ; il enregistre ; la carte se met à jour sans rechargement, un toast confirme.
4. **Numéro** : « Changer mon numéro » ouvre une modale : PIN actuel, nouveau numéro, confirmation du nouveau numéro ; il enregistre ; ses autres sessions sont fermées, sa session est renouvelée ; un toast confirme.
5. **PIN** : « Changer mon PIN » ouvre une modale : PIN actuel, nouveau PIN, confirmation ; il enregistre ; ses autres sessions sont fermées, sa session est renouvelée ; un toast confirme.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| PIN actuel faux (numéro ou PIN) | 422 dans la modale, « PIN incorrect. » ; l'échec compte comme un échec de connexion (verrouillage de l'ADR-0025) ; rien n'est écrit |
| Compte verrouillé par ces échecs | la session en cours est fermée ; l'utilisateur revient à la connexion avec le message de verrouillage |
| Confirmation différente (numéro ou PIN) | 422, erreur sous le champ de confirmation ; les champs PIN sont vidés, le numéro saisi est conservé |
| Nouveau numéro mal formé | 422, message de format (même règle que l'inscription) |
| Nouveau numéro déjà utilisé par un autre compte | 422, message neutre « Ce numéro ne peut pas être utilisé. », sans révéler l'existence du compte |
| Nouveau numéro identique à l'actuel, ou nouveau PIN identique à l'actuel | 422, « C'est déjà votre numéro. » ou « C'est déjà votre PIN. » ; rien n'est écrit |
| Nom ou prénom vide, trop long, ou seulement des espaces | 422, mêmes limites que l'inscription |
| Autre onglet ouvert après un changement de numéro ou de PIN | sa session est révoquée : la requête suivante ramène à la connexion |
| Requête sans Turbo | repli HTML : redirection vers `Mon profil` avec le toast |

## 4. Critères d'acceptation

```gherkin
Scénario: [PR-01] Lire son profil, dans son rôle
  Étant donné un élève connecté, inscrit dans la classe « Tle D 1 »
  Quand il ouvre « Mon profil » depuis le menu du compte
  Alors il voit son nom, son numéro groupé par deux chiffres, « Tle D 1 » et sa date d'inscription
  Et l'entrée « Mon profil » du menu est active et marquée comme page courante
  Et un enseignant voit son établissement et sa matière ; un membre de l'équipe voit son rôle et « Second facteur : actif »

Scénario: [PR-02] Personne ne lit le profil d'un autre
  Alors la page ne prend aucun identifiant : elle affiche toujours le compte de la session
  Et un visiteur non connecté est renvoyé vers la connexion

Scénario: [PR-03] Modifier son nom, sans rechargement, avec une trace
  Quand l'élève remplace son prénom par « Aya Marie » et enregistre
  Alors la carte affiche « Aya Marie » sans rechargement de page, et un toast confirme
  Et son enseignant voit « Aya Marie » dans la liste de la classe
  Et le journal d'audit contient « profile.name_changed » avec l'ancien et le nouveau nom
  Et un nom vide ou de plus de 50 caractères, ou un prénom de plus de 80, est refusé en 422

Scénario: [PR-04] Changer son numéro
  Quand l'élève saisit son PIN actuel, puis deux fois « 07 11 22 33 44 », et enregistre
  Alors il peut se connecter avec le nouveau numéro, plus avec l'ancien
  Et ses autres sessions sont fermées, et la sienne est renouvelée
  Et le journal d'audit contient « contact.changed », sans aucun PIN
  Et la page d'arrivée « Mon profil » est rechargée (session renouvelée, nouveau nonce CSP, ADR-0049 ; UDR-0041), un toast confirme

Scénario: [PR-05] Numéro refusé
  Alors un PIN actuel faux donne « PIN incorrect. » et compte un échec de connexion
  Et une confirmation différente, un format invalide ou le numéro actuel sont refusés en 422
  Et un numéro déjà pris par un autre compte donne « Ce numéro ne peut pas être utilisé. », comme un numéro libre mal saisi n'en révélerait rien
  Et dans tous ces cas, rien n'est écrit

Scénario: [PR-06] Changer son PIN
  Quand l'enseignant saisit son PIN actuel, puis deux fois un nouveau PIN, et enregistre
  Alors il se connecte avec le nouveau PIN, plus avec l'ancien
  Et ses autres sessions sont fermées, la sienne est renouvelée
  Et le journal d'audit contient « pin.changed »
  Et un PIN actuel faux, une confirmation différente, un PIN hors format ou identique à l'actuel sont refusés en 422

Scénario: [PR-07] Verrouillage
  Étant donné un élève qui saisit un PIN actuel faux autant de fois que le seuil de verrouillage
  Alors son compte est verrouillé comme après autant d'échecs de connexion
  Et il est renvoyé vers la connexion
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | use cases `Identity::UpdateOwnName`, `Identity::ChangeOwnContact`, `Identity::ChangeOwnPin` (policy `UpdateSelfPolicy`, `Shared::Result`) ; DTO d'entrée des trois formulaires ; actions d'audit `profile.name_changed`, `contact.changed`, `pin.changed` ; méthodes de port `UserRepositoryPort#update_name`, `#update_contact`, `SessionRepositoryPort#destroy_all_except` |
| Infrastructure | adaptateurs de ces méthodes ; `Queries::Identity::ProfileQuery` (lecture du profil selon le rôle) ; aucune migration |
| Delivery | `resource :profile` et trois sous-ressources (nom, numéro, PIN) ; contrôleurs sous `Identity::` ; renouvellement de session par `start_session` (ADR-0049, ADR-0050) |
| UI | `identity/profiles/show`, trois modales, `*.turbo_stream.erb` ; l'entrée « Mon profil » du menu devient active (plus de lien inactif) |

## 6. Décisions rattachées

- ADR-0055 — Profil : modification de son propre compte, révocation des autres sessions
- UDR-0041 — Page profil

## 7. Mesures

Sans objet (pas d'enjeu de performance).
