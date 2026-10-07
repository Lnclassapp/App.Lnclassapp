# Memo — Amélioration du parcours d'inscription des enseignants

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-07 |
| **Branche** | `feature/inscription-enseignant` |
| **Programme** | — |

---

## Le problème

Un enseignant peut aujourd'hui s'inscrire de **trois** façons :

1. avec le **code d'établissement**, saisi ou reçu dans un lien ;
2. **sans code**, en choisissant sa DRENA, puis son établissement, puis sa matière ;
3. par le **lien d'invitation** d'un collègue.

Trois entrées pour un même acteur, c'est trop : le parcours est confus. Le porteur veut n'en garder que **deux** (2026-10-07) :

- **L'inscription standard, « à froid »** : l'enseignant découvre Lnclass, arrive sur le site ou dans l'application, choisit « Je suis enseignant », puis sélectionne sa DRENA, son établissement et sa matière, et saisit son nom complet, son genre, son contact et son code secret personnel. Il valide.
- **L'inscription par le lien d'invitation d'un collègue.**

La voie « code d'établissement » disparaît.

Constat de l'exploration : le lien « Inviter un collègue » est aujourd'hui **le lien du code d'établissement**, augmenté d'une marque de parrainage. L'équipe (fiche de l'établissement) et la direction (« lien de l'établissement ») partagent aussi ce même lien. Retirer la voie « code » touche donc ces trois liens.

## Pour qui

- **L'enseignant (Teacher)** qui découvre Lnclass seul : l'inscription standard.
- **L'enseignant invité par un collègue** : l'inscription par le lien.
- **Le collègue qui invite**, la **direction** et l'**équipe**, qui partagent aujourd'hui un lien d'établissement : à cadrer.

## Pourquoi maintenant

Constats du porteur (2026-10-07) :

- **Le code d'établissement est introuvable** : les enseignants ne l'ont pas, personne ne le leur transmet, et ils restent bloqués.
- **Le parcours est confus** : trois entrées, l'enseignant ne sait pas laquelle prendre.
- **Trop d'informations sont demandées.**

## Hors périmètre

- **L'inscription de la direction** (voie standard, liens d'invitation vers la direction, plafond, retrait) et la **suppression définitive du code d'établissement** : chantier suivant `inscription-direction-sans-code` (Q5–Q8). Ici, la direction s'inscrit encore avec le code.
- **Rejoindre un second établissement** par un lien d'invitation : un enseignant connecté qui ouvre un lien est renvoyé vers son accueil (Q12).
- **L'élève et le parent** : rien ne change pour eux ici. Le retrait du code de classe et les deux flux d'inscription de l'élève (porteur, Q20) font l'objet du chantier suivant `inscription-eleve-sans-code`.
- Le nettoyage en direct du numéro et la vérification en direct de la confirmation du code secret sur les autres formulaires (élève, direction, invitation, changement de code) : à reprendre ailleurs si elle plaît.
- La vérification du numéro par WhatsApp (chantier `verification-whatsapp`, au backlog).

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. Pourquoi maintenant ? | Code introuvable, parcours confus, trop d'informations demandées. | Le chantier ne se limite pas à retirer une entrée : il doit aussi alléger ce qui est demandé (à préciser, Q2). |
| Q2. Comment alléger ce qui est demandé ? | Supprimer le code d'établissement ; **un seul champ « nom complet »** au lieu de nom + prénoms, séparé ensuite par une règle ; **réordonner** les informations dans l'ordre du parcours (DRENA → établissement → matière → nom complet, genre, contact → code secret). | Une règle de découpage du nom complet est à fixer (Q3). Les données enregistrées restent « nom » et « prénoms » séparés. Le formulaire change d'ordre : UDR obligatoire. |
| Q3. Quelle règle sépare le nom complet ? | **Premier mot = nom, le reste = prénoms**, affiché en aperçu (« Nom : … · Prénoms : … ») sous le champ ; l'enseignant peut corriger avant de valider. | Un nom en deux mots se corrige à la main. Le découpage doit aussi se faire côté serveur (l'aperçu n'est qu'un confort) ; la correction donne deux champs séparés. Un nom complet d'un seul mot est refusé (« Saisissez votre nom et vos prénoms. ») — confirmé par le porteur le 2026-10-07. |
| Q4. Par le lien d'un collègue, que remplit l'enseignant ? | L'établissement est **déjà choisi** : DRENA et établissement préremplis et affichés, avec « Ce n'est pas votre établissement ? » (retour à l'inscription standard). Il saisit matière, nom complet, genre, contact, code secret. | Le lien doit continuer d'identifier l'établissement **et** le collègue qui invite (parrainage). Ce qu'il porte (code d'établissement ou autre) est à trancher (Q5). |
| Q5. Le code d'établissement disparaît-il seulement de l'inscription enseignant ? | **Non : partout.** | Disparaissent aussi : le « lien de l'établissement » de la direction et de l'équipe (et leur geste « Régénérer »), et le code comme clé de l'inscription de la direction. Le lien d'un collègue doit identifier l'établissement autrement que par ce code. L'inscription de la direction doit trouver une autre voie (Q6). ADR obligatoire : le code d'établissement est un contrat posé par des ADR antérieurs. |
| Q6. Sans code, comment une direction s'inscrit-elle ? | Comme l'enseignant, deux voies : **l'inscription standard** (DRENA → établissement → identité → code secret) ou **un lien d'invitation** envoyé par un enseignant, l'équipe ou une autre direction de l'établissement. | La direction aussi passe de « code » à « standard + lien ». Nouveaux émetteurs d'invitation vers la direction (enseignant, direction). Sans preuve, le plafond de 3 et le retrait par une autre direction restent la seule protection : à confirmer (Q7). Le périmètre double : découpage à trancher (Q8). |
| Q7. Quelle protection pour une direction inscrite par la voie standard ? | Les règles actuelles, reprises : **au plus 3 directions par la voie standard** (les invitées ne comptent pas), retrait par une autre direction ou par l'équipe, et un nouvel arrivant ne retire personne pendant 7 jours. | Le plafond compte désormais « inscrite par la voie standard » au lieu de « inscrite par le code » ; les directions déjà inscrites par le code sont comptées comme standard. Risque accepté par le porteur : sans preuve, un imposteur peut occuper une place et voir le travail des élèves jusqu'à son retrait. |
| Q8. Un seul chantier ou deux ? | **Deux.** Celui-ci : l'enseignant. Le suivant, `inscription-direction-sans-code` : la direction (voie standard, liens d'invitation vers la direction, plafond et retrait repris, Q6–Q7) et le retrait définitif du code d'établissement. | Q6 et Q7 sont transmises au chantier suivant. Ici, le code d'établissement survit en coulisse pour la direction ; il ne sert plus du tout à l'enseignant. |
| Q9. Que devient le bloc « Lien d'inscription des enseignants » de la direction et de l'équipe ? | Il **devient un lien d'invitation** : « Copier » et « WhatsApp » restent, le code n'est plus affiché ; le lien ouvre l'inscription enseignant avec l'établissement déjà choisi. | Trois émetteurs du même type de lien : collègue (avec parrainage), direction, équipe (sans parrain). Le lien ne doit plus contenir le code d'établissement. |
| Q10. Garde-t-on « Changer le lien » (direction) et « Régénérer » (équipe) ? | **Les retirer** : le lien est stable et ne protège plus rien. | « Changer le lien » disparaît de l'espace direction. Nuance de l'agent : côté équipe, « Régénérer le code » protège encore l'inscription de la direction jusqu'au chantier suivant ; il est retiré **avec** le code, dans `inscription-direction-sans-code`. |
| Q11. Les anciens liens `/e/<code>` déjà partagés ? | **Aucun lien n'a été partagé** pour l'instant. | Pas de compatibilité à garder : l'adresse `/e/<code>` est retirée côté enseignant sans redirection. |
| Q12. Un enseignant inscrit (A) ouvre le lien d'un collègue de B ? | **Renvoi vers son accueil**, comme aujourd'hui pour une personne connectée. | Rejoindre un second établissement par un lien sort du chantier (écrit dans `Hors périmètre`). Non connecté, il tombe sur l'inscription : son numéro est refusé (« déjà un compte ») avec un lien « Se connecter ». |
| Q13. Enregistre-t-on la voie d'arrivée de chaque enseignant ? | **Oui** : standard, lien d'un collègue (lequel), lien de la direction, lien de l'équipe. L'enseignant est rattaché tout de suite dans tous les cas. | Une donnée nouvelle par enseignant (ADR). Les enseignants déjà inscrits reçoivent une voie d'après leur histoire : « code » (valeur historique), « standard » (ancienne voie sans code), « collègue » (parrainage). La demande en attente validée automatiquement n'a plus lieu d'être pour les nouvelles inscriptions. |
| Q14. Un lien d'invitation devenu invalide (établissement désactivé, collègue retiré ou supprimé) ? | **Inscription standard, avec un message neutre** : « Ce lien n'est plus valable. Choisissez votre établissement. » | Un seul message pour toutes les causes (on ne dit pas pourquoi). La voie enregistrée est alors « standard ». |
| Q15. Une page ou des étapes ? | **Une page réordonnée**, dans l'ordre du parcours, en blocs titrés : établissement (DRENA, établissement, matière) → vous (nom complet, genre, contact) → code secret. | Pas d'assistant multi-étapes ni d'état intermédiaire à garder. |
| Q16. Ordre des champs ? | Porteur : ordre présenté accepté (Établissement : DRENA, établissement, matière → Vous : nom complet, genre, numéro → Code secret : code, confirmation ; par lien, l'établissement est déjà affiché). Il ajoute une **vérification en direct de la confirmation** : une icône dans le champ confirmation et un court message dessous disent si les deux codes concordent. | Nouveau comportement côté navigateur (aucun n'existe pour la confirmation). Le serveur garde sa vérification : sans JavaScript, l'erreur arrive au renvoi (422). Limité à l'inscription enseignant ; les autres formulaires à code secret (élève, direction, invitation, changement de code) restent tels quels. |
| Q17. L'écran d'attente d'un enseignant sans établissement (retiré) rejoint par le code : que devient-il ? | **DRENA → établissement**, comme l'inscription standard ; rattachement immédiat. | Le code ne sert plus du tout à l'enseignant. La règle existante tient : l'établissement qui l'a retiré refuse, avec la même erreur neutre que pour un établissement absent de la liste. Sa voie d'arrivée ne change pas (elle décrit l'inscription). Le code national disparaît aussi de l'inscription (retrait confirmé par le porteur le 2026-10-07). |
| Q18. Le champ du numéro ? | **Chiffres seulement, 10 au plus** ; un `+225`, `(+225)`, `00225` ou des espaces saisis ou collés sont **retirés en direct**. | Nouveau comportement côté navigateur. Le serveur le fait déjà à l'enregistrement : il reste la garantie sans JavaScript. Un numéro ivoirien commence par 0 : un `225` ou `00225` en tête est toujours l'indicatif. Limité à l'inscription enseignant, comme Q16. |
| Q19. Le bouton « Inviter » de la section « Cours » de l'accueil enseignant ? | Il doit **ouvrir directement WhatsApp** pour inviter un collègue (aujourd'hui, il ouvre la page « Inviter un collègue »). Le lien d'une classe, lui, est destiné aux élèves. | Le bouton devient un lien WhatsApp sortant portant le message et le lien d'invitation `/i/<jeton>`, et le partage est compté (canal `whatsapp`), comme le bouton WhatsApp de la page « Inviter un collègue ». Rattaché au Lot B. |
| Q20. Retirer aussi le code de classe pour les élèves (deux flux, comme l'enseignant) ? | **Oui, mais dans un chantier séparé**, `inscription-eleve-sans-code`, avec son propre grill. | Écrit dans `Hors périmètre`. Ici, le code et le lien de classe des élèves ne changent pas. |
| Q21. Le tableau des établissements de l'équipe (`/teams/schools`) ? | **Retirer la recherche par code national et la colonne « Code d'établissement ».** La recherche se fait par nom ou sigle. | Lot E, après le Lot D. La recherche d'un établissement par code national disparaît aussi du code (plus d'appelant). Le code national reste une donnée de l'établissement (import, modification, fiche) ; le code d'établissement reste sur la fiche, pour la direction. |
| Q22. (phase 5, revue sécurité) Un inscrit sans preuve se déclare dans une classe et lit les numéros des élèves, mineurs : que peut-il faire jusqu'à la certification ? | **Numéros masqués.** Un enseignant arrivé par la voie standard, le lien de la direction ou le lien de l'équipe voit ses élèves et leur travail, assigne des exercices, mais les numéros des élèves lui sont masqués (« 07 •• •• •• 04 »). Arrivé par le lien d'un collègue (ou par l'ancien code), il voit tout. | Règle nouvelle, portée par la liste de classe de l'enseignant ; annonces inchangées. La certification lèvera le masque. Corrigé au Lot F. **Remplacée par Q23.** |
| Q23. Masquer les numéros seulement pour les inscrits sans preuve ? | **Non : pour tous les enseignants.** « Dans la classe, masque le numéro des élèves, sinon les filles peuvent être harcelées par certains enseignants en ayant leur contact. » | La liste de classe ne sort plus jamais le numéro complet d'un élève, quelle que soit la voie d'arrivée de l'enseignant, et la certification ne le lèvera pas. Seule l'équipe Lnclass garde le numéro complet (support). Plus de distinction « avec ou sans preuve » à coder. Lot F. |

## Cas limites identifiés

- Nom complet d'un seul mot : refusé, avec « Saisissez votre nom et vos prénoms. ».
- Nom de famille en deux mots (« Koné Ouattara Awa ») : mal coupé par la règle, corrigé par l'enseignant dans l'aperçu.
- Nom complet avec espaces en trop ou en minuscules : espaces normalisés ; la casse saisie est gardée.
- Navigateur sans JavaScript : pas d'aperçu en direct, mais le découpage se fait côté serveur et l'enseignant peut quand même ouvrir les deux champs séparés.
- Numéro déjà inscrit (enseignant, élève ou direction) : refus « Ce numéro a déjà un compte Lnclass. », avec « Se connecter », sans révéler le rôle.
- Personne connectée qui ouvre un lien d'invitation ou l'inscription standard : renvoyée vers son accueil.
- Lien d'invitation d'un établissement désactivé, ou d'un collègue retiré ou supprimé : inscription standard + message neutre, voie « standard ».
- Enseignant retiré qui choisit, sur l'écran d'attente, l'établissement qui l'a retiré : refus neutre, comme un établissement absent de la liste.
- Ancienne adresse `/e/<code>` : n'existe plus (aucun lien partagé, Q11).
- Établissement en brouillon ou désactivé : absent de la liste de la DRENA, comme aujourd'hui.
- Enseignant « Ce n'est pas votre établissement ? » depuis un lien : il repasse à l'inscription standard, la voie enregistrée devient « standard ».
- Enseignants inscrits avant le chantier : rattachement inchangé, voie d'arrivée déduite de leur histoire.
- Demandes encore « en attente » d'avant la pause : déjà validées par `validation-enseignants-en-pause` ; rien à reprendre.

## Questions encore ouvertes

- Le chantier suivant `inscription-direction-sans-code` reprend Q5 à Q8 : inscription standard de la direction, liens d'invitation vers la direction (émis par un enseignant, la direction, l'équipe), plafond de 3, retrait définitif du code d'établissement et de « Régénérer le code ».
- Le lien d'un collègue et celui de la direction ou de l'équipe : même adresse avec un parrain en plus, ou deux formes ? (choix technique, ADR).
