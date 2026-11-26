# Memo — Notifications poussées aux élèves (Web Push)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-16 |
| **Branche** | `feature/notifications-push` |
| **Programme** | — |

---

## Le problème

L'application ne peut joindre aucun élève en dehors d'une visite : ni courriel, ni SMS, ni notification. Un élève qui ferme l'application n'a plus de raison d'y revenir, sauf si son enseignant lui en parle en classe. L'entonnoir le montre : aucun élève n'a fait plus de deux exercices. Un devoir donné, une annonce publiée, une médaille gagnée restent invisibles jusqu'à la prochaine ouverture, qui ne vient pas.

## Pour qui

**L'élève** (Student), seul destinataire : après sa première réussite à un exercice, quand il décroche, la veille d'une échéance, à la publication d'une annonce de l'équipe, quand il gagne une médaille, quand il laisse un exercice en plan.

## Pourquoi maintenant

Activation et rétention à zéro. Le Web Push est le seul canal sortant gratuit : il n'y a ni SMS, ni serveur de courriel, et WhatsApp est facturé au message.

## Hors périmètre

- **La coque Android ne reçoit pas le Web Push ; elle relèvera d'un chantier FCM séparé (ADR-0070).**
- **Enseignants, direction, équipe, parents** : aucune notification. L'équipe voit seulement des nombres agrégés dans son pilotage.
- **WhatsApp, SMS, courriel** : autres chantiers.
- **iPhone** : reçoit seulement si le PWA est installé sur l'écran d'accueil (iOS 16.4 et plus) ; aucun effort de plus.
- **Préférences motif par motif** : l'élève active ou coupe tout.
- **Notification riche** (image, boutons d'action) : texte et lien seulement.
- **Calendrier des interrogations saisi par l'enseignant** : aucune table ne date une interrogation ; le chantier n'en crée pas (grill, question 2).
- **Vacances et jours fériés** : ignorés, comme les échéances (ADR-0072).

## Ce que le grill a révélé

> Le porteur a donné ses décisions le 2026-11-16 et demandé une session sans question. Le grill a donc été mené contre le code et les décisions en place. Quand le porteur n'a pas tranché une réponse, sa version prudente est appliquée et inscrite dans `## À trancher` du journal.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Qui reçoit, et sur quoi ? | Les **navigateurs et le PWA installé**, en Web Push | Un seul transport, derrière un port d'envoi du contexte `communication` |
| « Préparer une interrogation » : sur quoi se déclenche-t-il, alors qu'aucune table ne date une interrogation ? | Sur ce qui existe : une **feuille « Prépare interros » reçue**. C'est un envoi de 1 ou 2 exercices assignés, pas encore tous rendus, dont l'échéance tombe **demain**. Cette échéance est la prochaine séance de l'enseignant | Aucune table nouvelle. Le motif se distingue du « devoir à rendre bientôt », qui vise une feuille « Prépare devoirs » (3 exercices ou plus). Une interrogation surprise n'est jamais annoncée |
| « Terminer un exercice commencé » : qu'est-ce qu'un exercice commencé ? | Une **session d'exercice ouverte et jamais close**, sans réponse depuis 24 h, commencée il y a moins de 7 jours | Un rappel par session, une seule fois. Il n'en part aucun si l'élève a clos la session entre-temps |
| « Résultat ou médaille » : qui publie un résultat ? | Personne. La note est calculée à la clôture, sous les yeux de l'élève | Le motif ne vaut que pour ce que l'élève n'a pas vu : une copie rendue hors ligne et corrigée à la synchronisation, ou une médaille sans visite depuis 2 h |
| La permission après la première réussite empêche-t-elle de relancer les inactifs ? | **Oui.** L'élève qui décroche avant sa première réussite ne s'abonne jamais. Or c'est celui qu'on veut relancer, et aujourd'hui 0 élève a réussi un exercice | La tension est chiffrée dans le PRD. Le choix du porteur est appliqué. L'alternative « après le premier exercice commencé » est dans `## À trancher` |
| « Pas de plafond » avec six motifs : une rafale est-elle possible ? | **Oui** : une échéance, une interro, une médaille et une annonce peuvent tomber le même soir | Garde-fou retenu : pas de doublon par motif et par objet, **4 h au moins** entre deux envois au même élève. Le motif le plus urgent part d'abord, les autres attendent la fenêtre suivante |
| « Rien la nuit, rien pendant les heures de classe » : quelles heures ? | Aucune table ne porte d'horaire de cours, et les jours de séance n'ont pas d'heure. Appliqué, à l'heure d'Abidjan : **de 12 h à 14 h et de 17 h à 20 h du lundi au samedi, de 9 h à 20 h le dimanche** | Une fenêtre fixe, en configuration. Une notification hors fenêtre attend la suivante ou expire |
| Un téléphone partagé entre deux frères ? | Les notifications vont **au dernier compte connecté** sur le navigateur. La déconnexion supprime l'abonnement | L'abonnement suit la connexion. Une adresse déjà connue change de propriétaire |
| Un navigateur ne redemande jamais la permission après un refus : comment sortir, ou revenir ? | Par un **interrupteur dans le profil** | Une ligne « Notifications » sur le profil : activer, couper, ou expliquer le blocage par le navigateur |
| Un élève dans deux classes, ou sans classe principale ? | Les motifs liés à une classe ne lisent que la **classe principale active**, comme « Ma classe » | Pas de doublon d'un devoir. Sans classe, ces motifs ne s'appliquent pas |
| Que montre la notification sur un écran verrouillé ? | **Un texte sobre** : ni nom, ni note, ni contenu d'annonce. Par exemple « Un devoir de Maths est à rendre demain » | Des gabarits fermés et traduits. Un test vérifie qu'aucune donnée de l'élève n'entre dans le texte |
| L'élève dont la session a expiré au bout de 30 jours ? | L'abonnement **reste**. Toucher la notification ramène à la connexion | Le motif « inactif » a une fin : **3 relances au plus** (J+3, J+7, J+14), puis plus rien sans nouvelle activité |
| Le programme d'arrière-plan est en cours de modification par le chantier `hors-connexion` | Ce chantier ajoute deux écouteurs (`push`, `notificationclick`) et ne touche à aucun cache | Ordre de fusion imposé dans le plan |

## Cas limites identifiés

- Élève anonymisé : ses abonnements et ses envois sont supprimés, et rien ne lui est plus envoyé.
- Abonnement refusé par le service push (404 ou 410) : il est supprimé au premier refus.
- Permission refusée dans le navigateur : la carte d'invitation ne revient plus ; le profil explique comment la rétablir.
- Navigateur sans API Push (iPhone sans PWA, vieux Android, coque Android) : aucune invitation.
- Annonce retirée ou archivée avant l'envoi différé : rien ne part.
- Devoir archivé, exercice rendu ou session close avant l'envoi : rien ne part, car le motif est relu au moment de l'envoi.
- Échéance un lundi : la veille est un dimanche, dans la fenêtre du dimanche.
- Plusieurs motifs le même soir : un seul envoi par passage, le plus urgent.
- Élève abonné sur trois navigateurs : un envoi par navigateur, compté pour un seul motif.
- Clés VAPID absentes : l'adaptateur répond « non configuré », l'élève ne voit aucune erreur.

## Questions encore ouvertes

- Le moment de l'invitation : après la première réussite ou après le premier exercice commencé.
- Les fenêtres horaires, l'intervalle minimal, les auteurs d'annonce retenus et les paliers d'inactivité (appliqués par défaut).
