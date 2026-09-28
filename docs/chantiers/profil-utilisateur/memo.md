# Memo — Page profil de chaque utilisateur

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-09-27 |
| **Branche** | `feature/profil-utilisateur` |
| **Programme** | — |

---

## Le problème

Le menu du compte propose « Mon profil » aux quatre rôles, mais la page n'existe pas : l'entrée est grisée. Un utilisateur ne peut ni voir ni corriger ce que la plateforme sait de lui (nom, numéro), ni changer son PIN autrement qu'en le perdant.

## Pour qui

Tout compte connecté, dans les quatre rôles du shell (élève, enseignant, équipe, school_admin en attente), depuis l'entrée « Mon profil » du menu du compte. Surtout l'élève et l'enseignant, qui se connectent avec leur numéro et leur PIN sur un téléphone parfois partagé.

## Pourquoi maintenant

La V1 part en production : une entrée de menu grisée dans les quatre rôles donne une impression d'application inachevée, et la seule façon de changer un PIN aujourd'hui est de le perdre puis de demander un code de récupération. Décision du porteur du 2026-09-27.

## Hors périmètre

- Gérer le second facteur (TOTP, codes de secours) depuis le profil : il reste géré par l'enrôlement et le déblocage par un admin.
- Photo de profil, genre, date de naissance ou toute autre donnée nouvelle : le profil n'expose que ce que le compte contient déjà.
- Changer d'établissement, de classe ou de matière depuis le profil : l'élève passe par un code de classe, l'enseignant par la déclaration de ses classes.
- Supprimer son compte ; exporter ses données.
- Vérifier le nouveau numéro par SMS.
- Un profil pour les rôles Parent et SchoolStaff au-delà de ce que leur shell affiche déjà : ils n'ont pas de parcours en V1.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que peut faire un utilisateur sur sa page profil ? | Voir ses informations, changer son PIN, modifier nom et prénom, changer son numéro | Quatre parcours à spécifier ; le changement de numéro touche l'identifiant de connexion (unicité, audit) |
| Comment protéger le changement de numéro ou de PIN, sans SMS ? | PIN actuel exigé, et double saisie du nouveau numéro ou du nouveau PIN | Chaque écriture sensible revérifie le PIN (compte les échecs comme la connexion, ADR-0025) ; le déblocage par l'équipe (lot B8) reste le recours |
| Que deviennent les autres sessions après un changement de PIN ou de numéro ? | Toutes déconnectées, sauf la session en cours, qui est renouvelée | Il faut révoquer les sessions d'un utilisateur en une fois (probable méthode de port à ajouter côté identité) |
| Un élève peut-il changer son nom, vu par son enseignant ? | Oui, librement, mais chaque changement est tracé (ancien et nouveau nom) | Événement d'audit à ajouter pour le nom, le numéro et le PIN ; aucune validation par l'enseignant |
| Le second facteur de l'équipe se gère-t-il depuis le profil ? | Non en V1 : le profil affiche seulement qu'il est actif | Hors périmètre ; la réinitialisation reste le déblocage par un admin (lot B8) |
| Et si le nouveau numéro appartient déjà à un autre compte ? | Refus, avec un message neutre qui ne révèle pas l'existence du compte | Même règle de non-divulgation que la connexion ; test dédié |

## Cas limites identifiés

- PIN actuel faux au changement de numéro ou de PIN : l'échec compte comme un échec de connexion, et le verrouillage s'applique.
- Nouveau numéro identique à l'actuel, ou nouveau PIN identique à l'actuel : refus clair, rien n'est écrit.
- Nouveau numéro mal formé ou déjà pris : refus neutre, sans divulgation.
- Double saisie qui ne correspond pas : erreur sous le champ de confirmation, saisie conservée sauf les PIN.
- Nom ou prénom vide, trop long, ou seulement des espaces.
- Deux onglets ouverts : le second enregistrement après un changement de PIN trouve sa session révoquée et ramène à la connexion.
- Compte d'équipe sans second facteur vérifié : il n'atteint pas le profil (garde existante).

## Questions encore ouvertes

- Aucune question bloquante. À confirmer en phase 2 : les limites de longueur du nom et du prénom reprennent celles de l'inscription.
