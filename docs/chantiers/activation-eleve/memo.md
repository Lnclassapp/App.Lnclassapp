# Memo — Activation de l'élève : de l'inscription au premier exercice réussi

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-16 |
| **Branche** | `feature/activation-eleve` |
| **Programme** | — |
| **Issue** | #624 « Réutiliser « Prochain exercice » dans l'activation après l'inscription (moment « aha ») » |

---

## Le problème

Les élèves s'inscrivent, mais l'activation et la rétention sont à 0 : aucun élève n'a fait plus de 2 exercices (constat du porteur, 2026-11-16).

L'état des lieux du 2026-11-16 montre où le chemin casse. L'inscription aboutit : l'élève a un compte et une classe. Il arrive alors sur un accueil qui lui montre **sa classe et huit matières, et rien qui le pousse vers un exercice**. Pour en atteindre un, il lui reste 3 à 5 taps et autant de choix (matière, leçon, fiche, exercice) qu'il n'a aucune raison de faire. La carte qui faisait ce travail (« Prochain exercice ») a été retirée des écrans par le chantier `simplification-ecrans-eleve`, son code gardé exprès pour ce chantier-ci.

Et celui qui a commencé un exercice sans le finir ne le retrouve nulle part sur l'accueil : l'historique ne montre que les copies terminées, et ne propose de refaire que celles sous 14/20. Rien ne le fait revenir sur ce qu'il a touché.

## Pour qui

L'**élève**, à deux moments :

1. **Juste après l'inscription**, jusqu'à son premier exercice réussi (le moment « aha », décision du porteur). Deux cas, traités distinctement :
   - **l'élève seul** : il a choisi sa classe lui-même dans la liste (DRENA → établissement → niveau → classe). Personne ne l'accompagne, sa classe n'a souvent pas d'enseignant sur Lnclass : l'écran doit tout faire ;
   - **l'élève amené par sa classe** : il est entré par le lien ou le code que son enseignant (ou son établissement) a donné. Son enseignant attend de lui ce qu'il a donné à faire.
2. **Quand il revient** : depuis l'historique de l'accueil, il reprend l'exercice qu'il a laissé en cours, ou refait celui qu'il a terminé.

## Pourquoi maintenant

L'activation est à 0 : chaque inscription perdue l'est pour de bon, et les relances WhatsApp que l'équipe prépare (chantier séparé) n'ont rien vers quoi renvoyer l'élève tant que l'accueil ne lui montre pas d'exercice.

## Hors périmètre

- **Aucun envoi hors de l'app** : ni SMS, ni WhatsApp automatique, ni courriel, ni job de relance. Les relances se font à la main, par WhatsApp, dans un chantier de l'équipe.
- **Le numéro de téléphone reste à l'inscription** : l'équipe en a besoin pour ces relances, et c'est l'identifiant de connexion.
- **La mesure** : ni compteur, ni table d'événements, ni écran de croissance. Le chantier `entonnoir-aarrr` la porte le même jour ; ADR-0049 interdit tout traceur, ADR-0062 veut des indicateurs lus en direct.
- **Le formulaire d'inscription** ne change pas de champs : la classe est obligatoire (un élève sans classe n'a pas d'accueil), le genre et le numéro aussi (règles d'identité existantes), le PIN et sa confirmation protègent un compte sans mot de passe. Le chemin se raccourcit **après** l'inscription, là où il cassait.
- Les parents, l'établissement (`SchoolStaff`) et l'équipe (`Team`) ne voient rien de nouveau.
- L'enseignant ne voit rien de nouveau : il voit déjà les copies de ses élèves.
- La page de résultat et le lecteur d'exercice ne changent pas.
- Pas de parcours guidé en plusieurs écrans, pas de pop-up de bienvenue, pas de tutoriel.

## Ce que le grill a révélé

> Grill adverse mené par la session contre l'état des lieux du porteur et le code, la session étant autonome (contrat de session : zéro question). Chaque choix réversible est aussi écrit dans `## À trancher` du journal.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| « Réussi », c'est quoi ? 14/20 (maîtrise) ou 10/20 ? | 10/20, la moyenne : la note que l'élève reconnaît comme « réussi ». La maîtrise (14/20) reste le seuil de « Refaire » ailleurs. | Un élève est **activé** dès qu'une copie terminée atteint 10/20 arrondi (seuil `PASS` de la notation existante). Pas de colonne : lu en direct dans les copies. |
| Le guidage s'arrête quand ? | Au premier exercice réussi, pour de bon. Un élève activé retrouve l'accueil minimaliste de la simplification. | La carte n'existe que tant que l'élève n'est pas activé. Les élèves déjà inscrits qui n'ont rien réussi la voient aussi : c'est voulu (activation à 0). |
| Quel exercice proposer à l'élève seul ? | Le premier exercice de sa première matière, dans l'ordre du programme ; s'il en a un en cours, celui-là d'abord. | On réutilise la règle « Prochain exercice » existante (reprise, sinon le suivant du dernier terminé), matière par matière dans l'ordre de la grille. Aucune nouvelle règle de choix. |
| Et à l'élève amené par sa classe ? | Ce que son enseignant a donné : le premier exercice de « À faire ». Sans devoir, le même choix que l'élève seul. | Le mode d'entrée dans la classe (lien, code ou liste) départage. Un élève seul dont la classe a des devoirs les garde dans « À faire » ; sa carte reste la porte du programme. |
| La carte et « À faire » proposent le même devoir : deux portes ? | Oui, c'est interdit (règle 3 des écrans Wave). | Le devoir mis en carte est retiré de « À faire » ; s'il était seul, « À faire » disparaît. |
| La carte « reprendre » et l'historique « reprendre » montrent la même copie ? | Même problème. | La copie en cours mise en carte est retirée de l'historique. |
| Un élève qui a commencé sans finir revient : que voit-il ? | Aujourd'hui, rien. | L'historique liste aussi les copies **en cours** (« Reprendre »), et « Refaire » s'offre sur toute copie terminée, plus seulement sous 14/20, hors pause de « Recommencer » (ADR-0115). |
| Élève sans classe active (archivée, retiré) ? | Il n'a pas d'accueil de classe ; il voit « Choisis ta classe ». | Pas de carte d'activation dans cette branche : rejoindre une classe est son premier pas. Hors périmètre. |
| Élève dans deux classes ? | Une seule classe principale fait l'accueil. | Le mode d'entrée est celui de la classe principale active. |
| Aucun exercice publié à son niveau (6e à 4e, 2nde, dit le chantier `eleve-sans-prof`) ? | Rien à proposer. | Pas de carte : jamais de section vide ni de phrase « rien à faire ». |
| Période gratuite finie, sans abonnement ? | Démarrer un exercice est refusé (contexte billing). | La carte s'affiche comme les autres portes ; le refus est celui qui existe déjà au démarrage. |
| L'élève en pause de « Recommencer » ? | La règle ADR-0115 tient. | Pas de bouton « Refaire » pendant la pause ; la ligne mène au résultat. |
| L'en-tête du contrôleur d'accueil dit les sections « jamais vides », la vue les retire : qui a raison ? | La vue (UDR-0173 règle 2 : une section vide est absente). | L'en-tête du contrôleur est corrigé. |

## Cas limites identifiés

- Zéro exercice publié au niveau : pas de carte.
- Un exercice en cours hors de son niveau (classe changée) : ignoré, comme partout sur l'accueil (filtre d'audience).
- La copie en cours mise en carte, puis terminée sous 10/20 : la carte propose l'exercice suivant de la même matière.
- Un devoir retiré par l'enseignant : il n'est plus dans « À faire », la carte passe au programme.
- Mille copies : l'historique reste à 3 lignes puis « Voir plus (n) » vers Mon historique.
- Double clic sur « Commencer » : l'index « une copie ouverte par exercice » renvoie la même copie (existant).

## Questions encore ouvertes

- Voir `## À trancher` du journal : seuil de « réussi », « Refaire » sur toute copie terminée.
