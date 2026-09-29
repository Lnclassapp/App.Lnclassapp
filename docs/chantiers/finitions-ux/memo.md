# Memo — Finitions UX

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
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

- **Le caching** (point 8 de l'audit) : il demande un chantier `optimize` séparé, qui mesure avant d'optimiser (ADR-0062).
- Tout changement d'authentification sans décision d'architecture : l'ouverture de session dès l'acceptation d'une invitation touche l'ADR-0050.
- Une refonte de la navigation (UDR-0006) ou un fil d'Ariane complet sur toutes les pages.
- Une combobox d'établissements à l'inscription enseignant.
- Les textes d'aide eux-mêmes : le chantier fournit l'emplacement, le porteur valide les définitions.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- Second facteur : un code de secours (base58) peut commencer par 6 chiffres ; chaque envoi automatique d'un mauvais code consomme un essai (limite de 5 par minute, paliers de verrouillage).
- Codes de secours : ils ne sont stockés qu'en empreinte, donc le fichier ne peut être produit que par le navigateur. Un téléchargement sans geste de l'utilisateur peut être bloqué (iOS).
- Infobulles : l'API `popover` exige Safari 17, alors que le plancher de l'ADR-0051 est Safari 16.4.
- Recherche dynamique : `LIKE '%…%'` sans index sur les établissements et les comptes ; `advance` à chaque frappe remplit l'historique.
- Auto-focus : au téléphone, il ouvre le clavier sur les pages publiques ; après un 422, il doit viser le champ en erreur.
- Retour : la page d'une classe est ouverte par l'enseignant et par l'équipe, qui n'arrivent pas du même endroit.

## Questions encore ouvertes

Questions au porteur, une par ligne, avec la recommandation de l'audit. Aucune n'est tranchée ici.

1. **Périmètre** : les huit points en un seul chantier, ou un lot par point, livrés un par un ? — *Recommandation : un chantier, un lot par brique, dans cet ordre : titre, retour, copie, auto-focus, infobulles, recherche, envoi automatique.*
2. **Forme** : une UDR « finitions » unique, qui amende UDR-0005, 0006 et 0036, ou un amendement par UDR d'écran ? — *Recommandation : une UDR unique, plus des amendements d'une ligne là où une UDR d'écran contredit la règle.*
3. **Retour** : quel motif pour tout le monde, le lien `chevron-left` discret (8 écrans) ou le bouton `arrow-left` (2 écrans) ? — *Recommandation : le lien discret, via un partial `back_link` ou un emplacement `back:` dans `ui_page_header`.*
4. **Retour depuis la page d'une classe** : pour l'équipe, retour à la fiche établissement plutôt qu'à « Accueil » ? — *Recommandation : oui, cible selon le rôle.*
5. **Pages publiques** (`/login`, `/join`, `/c/<code>`, inscriptions, invitation) : lien retour vers la landing, ou logo cliquable ? — *Recommandation : logo cliquable, plus « Retour » là où il y a un parcours.*
6. **Enrôlement du second facteur** : ajouter « Se déconnecter », comme sur la vérification ? — *Recommandation : oui.*
7. **Auto-focus** : sur toutes les pages publiques, y compris au téléphone où le clavier cache l'accueil ? — *Recommandation : oui dans les modales ; sur les pages publiques, seulement pour les formulaires à un champ (connexion, `/join`, second facteur).*
8. **Auto-focus après une erreur** : focus sur le premier champ en erreur plutôt que sur le premier champ ? — *Recommandation : oui, partout.*
9. **Confirmations** (désactiver, supprimer) : focus sur « Annuler » plutôt que sur ✕ ? — *Recommandation : oui.*
10. **Infobulles** : qui écrit et valide les définitions (taux de rendu, moyenne, « — », k enseignant, badges, codes) ? — *Recommandation : le chantier propose les textes et le porteur les valide avant le lot.*
11. **Infobulles, forme** : `<details>` ouvert au toucher (compatible Safari 16.4) ou `popover` avec repli ? — *Recommandation : `<details>`, sans JS.*
12. **Copier, code de l'élève** : lever l'UDR-0011, qui interdit le bouton sur « Ma classe » ? — *Recommandation : non, garder l'interdiction.*
13. **Copier, code de récupération du PIN** : lever l'UDR-0020 (« fait pour être dicté ») ? — *Recommandation : non.*
14. **Copier, liens d'invitation équipe et direction** : ajouter « Copier », et WhatsApp comme pour le parrainage ? — *Recommandation : « Copier » oui (UDR-0019 le prévoyait) ; WhatsApp à trancher, le lien donnant accès à un compte.*
15. **Copier, lien de classe `/c/<code>`** : ajouter « Copier le lien » à côté de « Copier » le code ? — *Recommandation : oui, comme sur la fiche établissement.*
16. **Contrôleur de copie** : fusionner `classroom--join-code-copy` et la copie d'`identity--share` en un contrôleur `clipboard` générique ? — *Recommandation : oui, avec amendement de l'UDR-0027.*
17. **Invitation acceptée** : que veut dire « auto-submit » ? Ouvrir la session tout de suite (ADR-0050 à amender) ou pré-remplir le numéro sur `/login` ? — *Recommandation : pré-remplir et placer le focus sur le PIN ; l'ouverture directe demande une ADR.*
18. **Second facteur** : envoi automatique au 6ᵉ chiffre sur la vérification, ou seulement sur l'enrôlement, où les codes de secours ne sont pas acceptés ? — *Recommandation : les deux, avec une bascule « J'utilise un code de secours » sur la vérification et sans nouvel envoi automatique après un échec.*
19. **Codes de secours** : téléchargement automatique à l'affichage, ou seulement les boutons « Télécharger », « Copier » et « Imprimer » ? — *Recommandation : boutons seulement ; le téléchargement automatique n'est pas fiable et ne doit jamais bloquer « C'est noté ».*
20. **Sécurité de la page des codes de secours** (`no-store`, exemption du cache Turbo) : dans ce chantier ou en correctif séparé ? — *Recommandation : correctif séparé et prioritaire (`/bugfix`).*
21. **`/join`** : envoi automatique au 5ᵉ caractère valide du code de classe ? — *Recommandation : oui, c'est le même contrôleur que pour le second facteur.*
22. **Recherche dynamique** : sur quelles listes ? — *Recommandation : établissements, recherche du pilotage, élèves d'une classe et classes de l'enseignant (filtre dans le navigateur). Le catalogue seulement si on lui ajoute un champ texte.*
23. **Catalogue** : ajouter une recherche par nom et une pagination ? — *Recommandation : la recherche oui ; la pagination après mesure.*
24. **Filtres en liste déroulante** (catalogue, DRENA du pilotage) : envoi au changement, sans bouton « Filtrer » ? — *Recommandation : oui, en gardant le bouton sans JS.*
25. **Titre de page** : format unique « Page · Contexte · Lnclass » pour tous, espaces connectés compris ? — *Recommandation : oui, via un helper `page_title` et un test qui vérifie que chaque page pose un titre.*
26. **Titres des accueils** : « Accueil » identique pour trois rôles, faut-il les distinguer (« Accueil élève », « Accueil équipe ») ? — *Recommandation : oui.*
27. **Caching** : ouvrir tout de suite un chantier `optimize` séparé (mesure du pilotage, de la croissance, des établissements, du catalogue et des pages de la direction), ou attendre un signal de lenteur en production ? — *Recommandation : l'ouvrir, en commençant par une mesure. La recherche dynamique en dépend (index des recherches `LIKE`), et l'ADR-0062 a déjà écarté le cache du pilotage.*
