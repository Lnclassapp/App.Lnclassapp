# Memo — Finitions UX

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision |
| **Ouvert le** | 2026-09-29 |
| **Branche** | `feature/finitions-ux` |
| **Programme** | — |

---

## Le problème

Le porteur a relevé le 2026-09-29 sept finitions qui manquent ou varient d'un écran à l'autre : les **liens de retour**, l'**auto-focus** du premier champ, les **infobulles** d'aide, le bouton **« Copier »** des liens et codes à partager, l'**envoi automatique** de quelques gestes clés (acceptation d'une invitation, second facteur, codes de secours), la **recherche pendant la frappe** et le **titre de page**. Il a ajouté le même jour le **caching**.

L'[audit](audit.md) montre qu'aucune de ces finitions n'a de brique commune. Chaque UDR d'écran a tranché pour elle-même. On trouve donc trois motifs de retour, deux contrôleurs qui copient de la même façon, 14 formulaires avec `autofocus` posé à la main et 12 sans, un seul `title=` en guise d'infobulle et des titres de page de trois formes différentes. Trois UDR ont écarté exprès le bouton « Copier » (0011, 0019, 0020), et l'ADR-0062 a écarté le cache des indicateurs.

En chiffres (audit) : ≈ 19 écrans pour le retour, ≈ 13 pour l'auto-focus, ≈ 14 pour les infobulles, 5 à 8 pour la copie, 4 pour l'envoi automatique, ≈ 5 pour la recherche, 16 titres à ajouter et ≈ 58 à harmoniser.

## Pour qui

- **Équipe** : c'est elle qui a le plus de listes, de modales et de liens d'invitation, et elle seule a le second facteur et les codes de secours.
- **Enseignant** : partage du code et du lien de classe, recherche d'un élève dans sa classe, retour depuis « Inviter un collègue ».
- **Direction** : lecture des indicateurs (« Taux de rendu », « Moyenne », « — »).
- **Élève et public** : parcours d'entrée (`/join`, `/c/<code>`, inscriptions, connexion). L'auto-focus et le retour à l'accueil public y jouent.

## Pourquoi maintenant

La V1 et la direction simple sont en production. Ces écarts sont les premiers que voit un nouvel utilisateur, surtout au téléphone. Deux constats relevés en passant touchent aussi la sécurité : la page des codes de secours et la clé TOTP n'ont ni `no-store` ni exemption du cache Turbo, et l'enrôlement du second facteur n'a pas de sortie (audit, 5c et 1).

## Hors périmètre

- **Le caching** (point 8 de l'audit) : chantier `optimize` séparé, déjà en cours ; il mesure avant d'optimiser (ADR-0062). Décision du porteur, 2026-09-29.
- **Les secrets hors du cache** (`no-store` et exemption du cache Turbo sur la page des codes de secours et sur la clé du second facteur) : correctif séparé, déjà en cours (`secrets-hors-cache`). Ce chantier ne touche ni aux en-têtes HTTP ni au cache Turbo de ces pages.
- Une refonte de la navigation (UDR-0006) ou un fil d'Ariane complet sur toutes les pages.
- Une combobox d'établissements à l'inscription enseignant.
- La recherche pendant la frappe sur le pilotage (recherche d'un compte) et sur la déclaration des classes de l'enseignant : le porteur a limité la recherche dynamique à quatre listes. L'envoi au changement des filtres en liste déroulante, lui, est dans le périmètre (question 24).
- La pagination du catalogue : après mesure, dans le chantier de caching.
- Le partage des liens d'invitation par WhatsApp ou SMS : « Copier » seulement (question 14).
- La copie de la clé du second facteur (saisie manuelle) : ce n'est pas un lien, et le porteur a limité « Copier » aux liens et aux codes de secours.
- Un annuaire des comptes : « Débloquer un compte » reste une recherche par numéro entier. L'annuaire est le chantier `annuaire-equipe`.

## Ce que le grill a révélé

> Réponses du porteur du 2026-09-29, une ligne par réponse. Les questions qu'elles laissaient ouvertes sont tranchées plus bas, sur délégation.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| 1. Où lever l'interdiction de « Copier » ? | Pour les **liens seulement** : lien d'invitation (équipe et direction), lien de classe `/c/<code>`, codes de secours du second facteur. Le code de l'élève et le code de récupération du PIN restent à dicter. Un seul contrôleur de copie, qui fusionne les deux existants. | UDR-0019 amendée (le bouton prévu « à un lot ultérieur » arrive) ; UDR-0011 et UDR-0020 amendées pour confirmer l'interdiction et la fonder sur une règle commune (« un code à dicter ne se copie pas ») ; UDR-0027, 0044 et 0050 amendées : le nouveau contrôleur remplace l'ancien et la copie du partage. |
| 2. Envoi automatique du second facteur ? | Dès 6 chiffres, sur un champ `one-time-code` numérique, **une seule soumission**, annoncée aux lecteurs d'écran. Un lien « J'utilise un code de secours » bascule vers un champ séparé **sans** envoi automatique. | Le piège du code de secours qui commence par 6 chiffres disparaît : les deux saisies sont deux champs. La bascule doit marcher sans JavaScript (lien, pas bouton). Un échec n'est jamais renvoyé seul : le verrouillage (5 envois par minute) reste lisible. |
| 3. Codes de secours ? | Boutons **Télécharger, Copier, Imprimer** ; la suite ne se débloque qu'après la confirmation « Je les ai gardés ». Pas de téléchargement automatique. | Le fichier est construit par le navigateur (les codes ne sont stockés qu'en empreinte). La confirmation est une case obligatoire qui bloque la suite, même sans JavaScript. |
| 4. Acceptation d'une invitation ? | Garder le formulaire ; focus sur le premier champ, numéro pré-rempli ; après validation, **connexion immédiate**. | Vérifié le 2026-09-29 : ce n'est **pas** le cas aujourd'hui (la personne est renvoyée vers « Se connecter » et ressaisit son numéro). La connexion immédiate change le contrat de l'acceptation et le parcours de l'UDR-0019 : ADR-0068. Le numéro est montré en lecture seule, jamais envoyé ni modifiable. |
| 5. Recherche dynamique : où ? | Établissements (équipe), catalogue, élèves d'une classe (enseignant et direction), débloquer un compte (équipe). Délai, cadre Turbo, formulaire GET qui marche sans JavaScript, annonce du nombre de résultats ; index adaptés si recherche partielle, et ADR si index ou extension. | Le catalogue gagne un champ texte. Les élèves d'une classe se cherchent côté serveur (même motif partout). « Débloquer un compte » part dès que le numéro est complet, sans recherche partielle. Aucune table ne justifie un index : pas d'ADR (PRD §7, UDR-0054 §2). |
| 6. Titre de page ? | Format « Page · Espace · Lnclass » partout, modales comprises, par un seul helper. | Les trois accueils se distinguent par l'espace (question 26). Toute page, et toute modale ouverte directement par son URL, pose son titre ; un test le vérifie à la fin. |
| 7. Infobulles ? | Composant accessible sans JavaScript (base `<details>` ou équivalent compatible Safari 16.4) ; textes rédigés par le chantier, **validés par le porteur dans la PR**. | Les textes proposés sont écrits dans l'UDR-0054 ; la PR liste les textes pour validation. Le `title=` des niveaux disparaît. |
| 8. Retour ? | Une seule façon, sur les écrans listés par l'audit ; corriger les retours faux (page de classe vue par l'équipe → fiche établissement ; sortie de l'enrôlement du second facteur). | Un emplacement « retour » dans l'en-tête de page et une brique autonome pour les pages sans en-tête. Les motifs « bouton » (imports, direction) disparaissent. L'enrôlement gagne « Se déconnecter ». |
| 9. Auto-focus ? | Un contrôleur ; après une erreur, focus sur le premier champ en erreur ; dans une modale, le premier champ, pas la croix. | Les `autofocus` posés à la main disparaissent au profit d'une règle unique. Les confirmations sans champ visent « Annuler » (question 9). |
| 10. Caching et secrets hors cache ? | Hors périmètre : chantiers séparés en cours. | Aucun lot ne pose d'en-tête HTTP de cache ni d'exemption du cache Turbo. Les lots qui touchent les mêmes pages que `secrets-hors-cache` le signalent (plan, collisions entre chantiers). |

## Cas limites identifiés

- Second facteur : un code de secours (base58) peut commencer par 6 chiffres ; chaque envoi automatique d'un mauvais code consomme un essai (limite de 5 par minute, paliers de verrouillage). **Tranché** : deux champs distincts, l'envoi automatique n'existe que sur le champ à 6 chiffres, et jamais deux fois pour la même valeur.
- Codes de secours : ils ne sont stockés qu'en empreinte, donc le fichier ne peut être produit que par le navigateur. Un téléchargement sans geste de l'utilisateur peut être bloqué (iOS). **Tranché** : pas de téléchargement automatique ; sans JavaScript, seules la liste et « Imprimer » par le navigateur restent, et la confirmation « Je les ai gardés » suffit à continuer.
- Infobulles : l'API `popover` exige Safari 17, alors que le plancher de l'ADR-0051 est Safari 16.4. **Tranché** : `<details>`.
- Recherche dynamique : `LIKE '%…%'` sans index sur les établissements ; `advance` à chaque frappe remplit l'historique. **Tranché** : l'URL est remplacée pendant la frappe, pas empilée ; pas d'index (volumes, PRD §7).
- Auto-focus : au téléphone, il ouvre le clavier sur les pages publiques ; après un 422, il doit viser le champ en erreur.
- Retour : la page d'une classe est ouverte par l'enseignant et par l'équipe, qui n'arrivent pas du même endroit. **Tranché** : la cible dépend du rôle.
- Invitation : la personne invitée ouvre le lien sur un téléphone où quelqu'un d'autre est déjà connecté. La connexion immédiate remplace cette session (même règle que l'inscription enseignant).
- Invitation d'un membre de l'équipe : la session ouverte à l'acceptation n'a pas encore de second facteur ; elle ne mène qu'à l'enrôlement, comme une connexion.
- Direction : la liste de ses classes et la page d'une classe sont réécrites par le chantier `espace-direction` ; la recherche et le retour de la direction s'appliquent à la version qui sera en place.
- Double envoi : l'utilisateur tape Entrée au moment où le 6ᵉ chiffre part seul ; une seule requête doit partir.

## Questions tranchées

Les 27 questions du cadrage, chacune avec sa réponse. **Porteur** : réponse du 2026-09-29. **Délégué** : la recommandation du memo, retenue sur délégation du porteur, amendable dans la PR.

1. **Périmètre** : un seul chantier pour les sept finitions ; le caching en sort. Les lots ne suivent pas l'ordre des briques recommandé : un Lot 0 pose toutes les briques, puis un lot par espace applique les sept finitions à ses écrans, pour que deux lots ne touchent jamais la même vue. — *Délégué, adapté (collisions).*
2. **Forme** : une UDR « finitions » unique (UDR-0054), plus des amendements courts là où une UDR d'écran la contredit ou doit la mentionner. — *Porteur.*
3. **Retour, motif** : le lien discret à chevron gauche, posé par l'emplacement « retour » de l'en-tête de page ou par la brique autonome. — *Porteur (une seule façon) ; délégué (le lien discret plutôt que le bouton).*
4. **Retour depuis la page d'une classe** : l'équipe revient à la fiche de l'établissement, l'enseignant à ses classes. — *Porteur.*
5. **Pages publiques** : logo cliquable vers l'accueil public sur toutes les pages publiques ; un « Retour » en plus là où il y a un parcours (PIN oublié → connexion, inscription sans code → inscription avec code). — *Délégué.*
6. **Enrôlement du second facteur** : « Se déconnecter », comme sur la vérification. — *Porteur.*
7. **Auto-focus sur les pages publiques** : oui dans les modales ; sur les pages publiques, seulement pour les formulaires à un champ (connexion, `/join`, second facteur) et, par décision du porteur, pour l'acceptation d'une invitation. — *Délégué, plus porteur (invitation).*
8. **Auto-focus après une erreur** : premier champ en erreur, partout. — *Porteur.*
9. **Confirmations** : focus sur « Annuler ». — *Délégué.*
10. **Infobulles, textes** : le chantier les rédige, le porteur les valide dans la PR. — *Porteur.*
11. **Infobulles, forme** : `<details>`, sans JavaScript. — *Porteur.*
12. **Copier le code de l'élève** : non, l'interdiction reste. — *Porteur.*
13. **Copier le code de récupération du PIN** : non. — *Porteur.*
14. **Liens d'invitation** : « Copier » oui ; WhatsApp non (le lien donne accès à un compte, et le porteur a limité l'ajout à « Copier »). — *Porteur (Copier) ; délégué (pas de WhatsApp).*
15. **Lien de classe** : « Copier le lien » à côté de « Copier » le code. — *Porteur.*
16. **Contrôleur de copie** : un seul, générique, qui remplace les deux existants ; le partage garde WhatsApp, SMS, le partage natif et le comptage. — *Porteur.*
17. **Invitation acceptée** : la session s'ouvre à l'acceptation (ADR-0068) ; le numéro est montré pré-rempli en lecture seule sur le formulaire. — *Porteur.*
18. **Second facteur** : envoi automatique au 6ᵉ chiffre sur la vérification **et** sur l'enrôlement ; bascule « J'utilise un code de secours » sur la vérification seulement ; jamais de nouvel envoi automatique de la même valeur après un échec. — *Porteur.*
19. **Codes de secours** : boutons seulement, et la suite ne se débloque qu'après « Je les ai gardés ». — *Porteur.*
20. **Sécurité de la page des codes de secours** : correctif séparé, déjà en cours. — *Porteur.*
21. **`/join`** : envoi automatique au 5ᵉ caractère valide du code de classe (3 lettres, 2 chiffres), avec la même brique que le second facteur. — *Délégué.*
22. **Recherche dynamique, listes** : établissements, catalogue, élèves d'une classe (enseignant et direction), débloquer un compte. Ni le pilotage ni la déclaration des classes. — *Porteur.*
23. **Catalogue** : une recherche par nom ; pas de pagination dans ce chantier. — *Porteur (recherche) ; délégué (pagination après mesure).*
24. **Filtres en liste déroulante** (catalogue, établissements, DRENA du pilotage) : envoi au changement ; le bouton « Filtrer » reste pour qui n'a pas de JavaScript. — *Délégué.*
25. **Titre de page** : « Page · Espace · Lnclass », par un helper, avec un test qui vérifie que chaque page pose un titre. — *Porteur.*
26. **Titres des accueils** : distingués par l'espace (« Accueil · Élève · Lnclass », « Accueil · Équipe · Lnclass »). — *Délégué (conséquence du format du porteur).*
27. **Caching** : chantier `optimize` séparé, déjà ouvert. — *Porteur.*

## Questions encore ouvertes

Aucune ne bloque le Lot 0. À confirmer par le porteur dans la PR :

- Les textes des infobulles (UDR-0054 §3, table « Textes proposés »).
- Le numéro affiché sur la page d'acceptation : un lien d'invitation intercepté révèle désormais le numéro invité (ADR-0068, coûts consentis).
- L'ordre de fusion avec `espace-direction`, `annuaire-equipe` et `secrets-hors-cache`, qui touchent des écrans de ce chantier (plan, « Collisions avec d'autres chantiers »).
