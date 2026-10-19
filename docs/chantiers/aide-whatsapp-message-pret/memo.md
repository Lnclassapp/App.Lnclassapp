# Memo — Message prêt dans le lien WhatsApp de la carte d'aide

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-10-16 |
| **Branche** | `feature/aide-whatsapp-message-pret` |
| **Programme** | — |

---

## Le problème

La ligne « Chatter avec le support » de la carte d'aide ouvre WhatsApp sur une conversation vide. La personne écrit « bonjour », le support doit demander qui elle est, sa classe, son école : la vraie question n'arrive qu'au troisième message. Le porteur, le 2026-10-16 : « je peux avoir un lien du type wa.me/0584258085 avec un texte pour introduire les informations de la personne qui nous écrit ».

## Pour qui

- **Élève** connecté, depuis l'en-tête (dès 700 px) ou le menu de l'avatar.
- **Enseignant(e)** connecté, depuis l'en-tête.
- **Direction** connectée, depuis son en-tête, qui gagne « Besoin d'aide ? ».
- **Visiteur** sur la connexion et l'inscription élève.
- **Support Lnclass**, qui reçoit le message et retrouve le compte.

## Pourquoi maintenant

Demande directe du porteur, au moment où les premières écoles arrivent et où le support répond seul sur WhatsApp. Ce lien remplace à court terme le chantier [`canal-whatsapp`](../canal-whatsapp/memo.md), gelé : ses « Réponses du porteur (2026-10-16) » séparent les deux besoins (l'utilisateur nous écrit ici ; Lnclass envoie des avis là-bas, après les démarches Meta).

## Hors périmètre

- Donner la carte d'aide à l'équipe : l'équipe, c'est le support.
- La page d'où la personne écrit : aucune page ne pose de titre lisible, et une adresse porterait des identifiants.
- Enregistrer la fonction d'un membre de la direction (proviseur, censeur…) : la donnée n'existe pas ; c'est la V2 complète (`espace-direction`).
- Un formulaire de contact, un ticket, un suivi des demandes, un service tiers (ADR-0049).
- Le lien d'appel (`tel:`), inchangé.
- Plusieurs matières de l'enseignant (chantier `enseignant-plusieurs-matieres`, en cours) : le message prend la matière que l'en-tête montre déjà.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| `wa.me/0584258085` marche-t-il ? | Non : wa.me exige le format international sans « + » ni zéro de tête. | La configuration a déjà `2250584258085` ; le test de la configuration refuse désormais un numéro qui commence par 0. |
| Faut-il le numéro de la personne dans le message ? | Non : WhatsApp le transmet avec le message. | Jamais de numéro, de code secret ni de code dans le message ; testé. |
| Faut-il un identifiant, même public ? | Non : le porteur exclut tout identifiant interne ; le `public_id` (ADR-0029) n'a aucun sens pour la personne. | Nom, rôle, établissement seulement ; testé. |
| Une requête de plus sur chaque page ? | La carte est rendue partout ; l'en-tête lit déjà nom, classe, matière, établissement. | Le message réutilise cette lecture : zéro requête de plus, le genre est une colonne de plus de la même requête. |
| « au Lycée », « à l'École », « à la Cité » ? | L'article dépend du nom de l'établissement, non enregistré. | L'établissement suit après une virgule. **À confirmer par le porteur.** |
| Qui voit la carte aujourd'hui ? | Élève et enseignant (en-tête), visiteur (connexion, inscription élève) ; pas la direction ni l'équipe. | La direction la reçoit dans son en-tête (le porteur demande ses captures) ; un test d'intégration par rôle, un test système à 390 px pour la direction. |
| Un élève sans classe active, un enseignant sans établissement ? | Les éléments absents sont omis. | « élève », « enseignant » seuls ; jamais « élève de , ». |

## Choix de texte faits sur recommandation — à confirmer par le porteur

1. **Établissement après une virgule** : « élève de Tle D 1, Lycée moderne de Cocody » plutôt que « au Lycée moderne de Cocody ».
2. **« enseignant » / « enseignante »** selon le genre du compte, plutôt que « enseignant(e) ».
3. **Direction : « membre de la direction »**, la fonction n'étant pas enregistrée.
4. **Équipe : le message simple** du visiteur, « Bonjour Lnclass, ma question : ».
5. **« Ma question : » suivi d'une espace**, pour écrire à la suite.

## Cas limites identifiés

- Nom ou établissement avec apostrophe, accent ou « & » : encodage en pourcent, testé.
- Élève dont la seule classe est archivée : pas de classe ni d'établissement (ADR-0088).
- Page rendue par le shell sans données (page de démonstration du design) : message simple.
- Numéro WhatsApp vide dans la configuration : pas de ligne WhatsApp (inchangé, UDR-0061 §3.4).

## Questions encore ouvertes

- Les cinq choix de texte ci-dessus.
