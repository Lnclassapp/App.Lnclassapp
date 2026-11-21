# Memo — Une seule entrée pour l'élève : numéro et code secret

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-20 |
| **Branche** | `feature/entree-eleve-unifiee` |
| **Programme** | `retours-terrain-tiassale` (décisions D1 et D2 du porteur, [memo](../retours-terrain-tiassale/memo.md)) |

---

## Le problème

À Tiassalé (2026-11-20), en classe, sur téléphone :

- des élèves sans compte touchent « Se connecter » dans la modale « Je suis élève » et restent bloqués devant « Numéro ou code secret incorrect » ;
- des élèves qui ont déjà un compte recommencent une inscription, et se heurtent au refus du numéro ;
- des élèves prennent « Enseignant(e) » sur l'accueil et créent un compte enseignant.

L'élève doit choisir entre « se connecter » et « créer un compte » avant d'avoir fait quoi que ce soit : c'est ce choix qu'il rate.

## Pour qui

- **L'élève** (Student), au premier geste : accueil, page de connexion, lien de classe `/c/<jeton>`.
- **L'enseignant** (Teacher) qui ouvre l'inscription enseignant : une question de plus, une seule fois.
- **Tout compte existant** (enseignant, direction, équipe) qui passerait par l'entrée élève : il est connecté normalement.

## Pourquoi maintenant

Retour de terrain direct du porteur, pendant les lancements en classe. Chaque élève inscrit comme enseignant est un compte à nettoyer à la main, et chaque élève bloqué devant « Se connecter » est un élève perdu pour la séance.

## Hors périmètre

- Le choix de l'établissement dans l'inscription élève (sélecteur DRENA → établissement) : chantier `recherche-etablissement`, en parallèle. Rien n'y est touché.
- L'accueil pour l'enseignant et l'établissement : inchangé (D1). Seul le bouton « Je suis élève » change.
- La connexion générale `/login` : inchangée, sauf son lien « Créer mon compte » qui mène à l'entrée élève.
- Les inscriptions enseignant par invitation (`/i/<jeton>`) et direction : sans question de confirmation (un lien d'invitation vise déjà un enseignant).
- L'inscription élève directe `/student-signup`, encore liée par les pages publiques d'établissement : elle reste en trois étapes (voir `## À trancher` du journal).
- Parent : pas de compte parent aujourd'hui, rien à faire. Équipe (Team) et direction (SchoolStaff) : n'ont rien de nouveau à voir ; s'ils tapent leur numéro dans l'entrée élève, ils sont connectés comme à `/login`.
- Le débit de la vérification d'un code de classe (10 par minute) : inchangé.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Un élève tape son numéro avec une faute : l'entrée lui dit « pas de compte » et il en crée un second ? | Oui, si on enchaîne sans rien dire. | Écran intermédiaire « Ce numéro n'a pas encore de compte » qui **montre le numéro** et propose « Corriger mon numéro ». |
| Le code tapé une seule fois devient le code du compte : une faute de frappe, et l'élève ne peut plus revenir. | L'inscription actuelle demande une confirmation. | La confirmation du code est demandée sur l'écran « pas encore de compte », pas dans l'inscription. |
| Où vit le code secret entre l'entrée et la fin de l'inscription (classe, nom) ? Le repli sans JavaScript de la cascade recharge la page en GET. | Ni dans l'adresse, ni dans un champ caché. | Gardé côté serveur dans la session chiffrée, 30 minutes, effacé à la connexion : écrit dans l'ADR. |
| Quarante élèves sur le wifi de l'école passent par l'entrée en deux minutes : la connexion est limitée à 5 par minute et par adresse. | Ils seraient bloqués. | L'entrée a son propre compteur, large (120 par minute, 600 par heure, par adresse) ; la protection du code reste le verrouillage progressif par numéro (ADR-0050). L'inscription qui suit l'entrée a son compteur (60 par minute). |
| L'entrée dit si un numéro est inscrit : un tiers peut tester des numéros. | Décision du porteur, assumée. | ADR dédiée ; plafond horaire par adresse ; aucun nom ni rôle révélé, seulement « inscrit / pas inscrit ». |
| Un enseignant ou une direction tape son numéro dans l'entrée élève ? | Il a un compte : il est connecté, quel que soit son rôle (D2). | La règle de la coque Android (une app par rôle) s'applique comme à `/login`. |
| L'élève arrive par le lien de sa classe `/c/<jeton>` : passe-t-il par l'entrée ? | Oui, sinon un élève inscrit refait une inscription. | Le lien ouvre l'entrée avec le bandeau de la classe ; connecté, il revient sur le lien (rejoindre ou changer de classe) ; nouveau, il s'inscrit dans **cette** classe, sans l'étape « Ta classe ». |
| Un numéro inconnu au moment de l'entrée est pris par quelqu'un d'autre avant la fin de l'inscription ? | Rare, mais possible. | L'inscription refuse le numéro pris (contrainte existante) : jamais de second compte. |
| Un élève verrouillé (trop de codes faux) passe par l'entrée ? | Même verrouillage qu'à `/login`. | L'entrée réutilise la connexion existante, sans chemin parallèle. |

## Cas limites identifiés

- Numéro hors format (pas `01`, `05`, `07` + 8 chiffres) : erreur sur le numéro, rien n'est cherché.
- Code qui n'a pas exactement 4 chiffres (le porteur, 2026-11-20 : « 4 chiffres obligatoirement ») : erreur sur le code, rien n'est cherché ; le navigateur le bloque aussi.
- Retour arrière du navigateur après l'écran « pas de compte » : l'écran se rouvre tant que l'entrée tient (30 min).
- Entrée expirée (plus de 30 min) au moment d'envoyer l'inscription : retour à l'entrée, rien n'est créé.
- Lien de classe devenu invalide entre l'entrée et l'inscription : voie standard (choix de la classe), comme aujourd'hui.
- Classe complète par le lien : la page du lien le dit, sans formulaire (inchangé).

## Questions encore ouvertes

Aucune bloquante ; les choix réversibles sont dans `## À trancher` du [journal](journal.md).
