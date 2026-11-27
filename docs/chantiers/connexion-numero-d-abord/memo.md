# Memo — Connexion et inscription « numéro d'abord »

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-26 |
| **Branche** | `feature/connexion-numero-d-abord` |
| **Programme** | — |

---

## Le problème

La page de connexion demande numéro et code secret ensemble et répond « Numéro ou code secret incorrect » à quelqu'un qui n'a pas de compte : il ne sait pas qu'il doit s'inscrire. L'entrée « Je suis élève » fait taper le code deux fois à un nouvel élève (« Retape ton code secret »). L'inscription enseignant suit un autre ordre (établissement, identité, code tapé deux fois) que celle de l'élève.

## Pour qui

- Élève, enseignant, direction, équipe : quiconque se connecte, sur téléphone, souvent sur le wifi de l'école.
- Élève et enseignant qui créent leur compte.

## Pourquoi maintenant

Demande du porteur (2026-11-26), après l'entrée élève unifiée (Tiassalé) : le même principe « le numéro décide de la suite » doit valoir pour tout le monde, et l'enseignant doit retrouver le parcours de l'élève.

## Hors périmètre

- Le second facteur des comptes équipe et direction : inchangé.
- L'inscription de la direction (code d'établissement, invitation) : inchangée.
- Le lien d'invitation enseignant et le lien de classe : ils marchent comme avant, sans nouvel écran.
- La récupération du code secret (WhatsApp) : inchangée, seulement proposée.
- Parent : pas de compte, rien à voir.
- Les coques Android : elles envoient numéro et code ensemble ; ce cas reste accepté tel quel.
- Le choix du rôle par la direction ou l'équipe sur l'écran « pas de compte » : seuls Élève et Enseignant(e) y figurent (la direction s'inscrit par invitation ou code).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Révéler qu'un numéro a un compte, pour tous les rôles, ouvre-t-il l'énumération des comptes équipe ? | Oui ; le porteur l'accepte (décision 2), sans nom, rôle ni classe, second facteur inchangé | Nouvel ADR qui amende ADR-0141 ; revue sécurité obligatoire |
| Les essais de numéros sur la connexion et sur l'entrée élève se cumulent-ils ? | Ils doivent partager les mêmes compteurs par adresse, sinon le plafond double | Un seul compteur (minute et heure) pour les deux pages |
| Une classe entière se connecte derrière un wifi : la limite actuelle de 5 envois par minute sur la connexion la bloque | Elle passe aux limites de l'entrée élève ; les codes faux restent à 5 par minute et par adresse, le verrouillage par numéro reste | La connexion n'a plus de plafond à 5 envois ; le plafond des codes faux la remplace |
| Le gestionnaire de mots de passe ou la coque Android envoie numéro et code en un seul geste | Ce geste doit continuer de marcher, avec le message unique d'avant | Un envoi numéro + code reste accepté et garde son message |
| Un numéro inconnu sur la connexion : on ne sait pas si c'est un élève ou un enseignant | Deux boutons, Élève / Enseignant(e), numéro repris | La connexion garde le numéro le temps de l'inscription (30 min, comme l'entrée élève) |
| Le code tapé une seule fois : une faute de frappe crée un compte avec un code inconnu | Rattrapée par « Code secret oublié ? » (WhatsApp) | Plus de confirmation ; le lien « Code secret oublié ? » sous chaque code faux |
| Un numéro qui reçoit un compte entre l'écran « pas de compte » et la fin de l'inscription | Jamais de second compte (ADR-0141 §4.4) | Revérifié à l'envoi du code et à la création |
| L'enseignant avec un code d'établissement ? | Correction du porteur : plus de code dans l'inscription enseignant ; l'établissement se choisit dans la liste (voie sans code, déjà la seule existante) | Aucun champ de code ajouté ; droits inchangés |
| Multi-appartenance, plusieurs établissements | Sans objet : la connexion ne lit que le numéro ; le rattachement ne change pas | Rien |

## Cas limites identifiés

- Numéro hors format : erreur sur le champ, jamais cherché.
- Numéro verrouillé (trop de codes faux) : message de verrouillage, comme aujourd'hui.
- Entrée gardée expirée (30 min) : retour au numéro, avec un message.
- « Ce n'est pas mon numéro » : l'entrée est oubliée, le numéro revient dans le champ.
- Compte d'un autre rôle dans une coque Android : refus actuel, inchangé.
- Compte équipe ou direction : code juste, puis second facteur comme avant.

## Questions encore ouvertes

- Voir `## À trancher` du journal.
