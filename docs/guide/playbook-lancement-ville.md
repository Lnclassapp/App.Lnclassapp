# Playbook — Lancer Lnclass dans une ville

> Écrit après la journée de terrain au collège Notre-Dame de la Paix de Tiassalé (2026-11-20). Programme : [`retours-terrain-tiassale`](../chantiers/retours-terrain-tiassale/memo.md).
> Une ville se lance en **3 semaines**, établissement par établissement. Le but de chaque visite : **une classe entière inscrite, et un premier exercice réussi par élève, avant de quitter la salle.**

---

## Les chiffres qui disent si ça marche

| Étape | Mesure (espace équipe) | Seuil pour passer à la suite |
|---|---|---|
| Enseignants | enseignants inscrits par établissement | ≥ 3 par établissement visité |
| Classes | classes avec au moins 10 élèves | ≥ 1 par enseignant inscrit |
| Activation | élèves avec un premier exercice réussi | ≥ 60 % des inscrits du jour |
| Rétention | élèves actifs la semaine suivante | ≥ 30 % |
| Referral (k-factor) | élèves venus par l'invitation d'un autre élève ou par le QR, par inscrit | ≥ 0,5 à J+14 |

Les chiffres se lisent dans l'entonnoir AARRR et l'entonnoir des classes. On ne passe pas à la ville suivante avant que la première tienne ses seuils.

---

## Semaine −2 : préparer

1. **Choisir la DRENA** et 3 à 5 établissements proches (un établissement « vitrine » où l'on connaît la direction, puis ses voisins).
2. **Vérifier les données** : les établissements sont actifs dans le référentiel, la DRENA est importée, les classes générées ont les bons niveaux.
3. **Contacter la direction** (CRM écoles : une fiche par établissement, rendez-vous noté). Obtenir : un créneau en classe, une salle où le réseau passe, l'accord pour l'affiche.
4. **Identifier deux enseignants relais** par établissement (matières à exercices : mathématiques, physique-chimie, SVT, français).
5. **Points relais** : repérer une boutique ou un point Wave près de l'établissement pour les cartes d'activation.
6. **Matériel** : kit d'affiche (A4, QR de chaque classe), un téléphone de démonstration chargé, un partage de connexion de secours (forfait data), une liste papier pour noter les élèves bloqués.

## Semaine −1 : les enseignants d'abord

1. **Réunion de 30 minutes** avec la direction et les enseignants relais : démonstration sur le téléphone, puis chaque enseignant s'inscrit **devant nous** (code ou lien d'établissement).
2. Chaque enseignant **coche ses classes** et repart avec le **QR de chaque classe** imprimé.
3. Chaque enseignant **assigne un premier exercice court** (5 questions, une notion déjà vue en classe) pour le jour J.
4. Les enseignants relais transfèrent le lien de parrainage à leurs collègues (k-factor enseignant).

## Jour J : la classe s'inscrit (45 minutes)

| Minute | Ce qu'on fait | Pièges vus à Tiassalé |
|---|---|---|
| 0–5 | Présentation en une phrase : « Lnclass, ce sont les exercices de ton prof sur ton téléphone. » | — |
| 5–10 | Le QR de la classe est **affiché au tableau**. Les élèves le scannent ; ceux sans appareil photo tapent le lien court. | Ne pas laisser les élèves passer par l'accueil : le QR les mène directement à leur classe, sans choisir d'école. |
| 10–20 | Inscription : « Je suis élève », numéro, code secret à 4 chiffres. | Répéter : **« Tu es élève : jamais Enseignant. »** Des élèves ont choisi « Enseignant(e) ». Des élèves sans compte ont cliqué « Se connecter » : avec l'entrée élève unique, ils continuent leur inscription. Faire noter le code secret dans le cahier. |
| 20–35 | **Premier exercice** assigné, fait en classe. On circule, on débloque. | C'est le moment « aha » : personne ne sort sans un exercice réussi. |
| 35–40 | « Invite tes camarades absents » : le bouton d'invitation envoie le lien de la classe sur WhatsApp. | Le faire faire en classe, pas « ce soir ». |
| 40–45 | L'affiche est posée en classe ou au tableau d'affichage, QR visible. | — |

Réseau : 40 élèves sur un même wifi ou un même partage de connexion passent (correctif `inscription-classe-meme-wifi`). Si le réseau tombe, l'élève garde son écran et réessaie ; on ne recommence pas l'inscription.

## Semaine +1 : tenir

1. **J+1** : message WhatsApp aux enseignants : nombre d'élèves inscrits et actifs de leur classe.
2. **J+3** : chaque enseignant assigne un deuxième exercice. On relance ceux qui n'ont rien assigné.
3. **J+7** : revue des chiffres par établissement (tableau ci-dessus). Une classe sous 30 % de rétention : on revient en classe.
4. **J+14** : k-factor par classe et par établissement. Les classes au-dessus de 0,5 : on demande à leur enseignant de présenter Lnclass à ses collègues.

## Semaines +2 et +3 : s'étendre

- Les établissements voisins sont visités avec la preuve de l'établissement vitrine (chiffres, témoignage d'un enseignant).
- Le kit d'affiche est laissé à la direction pour les classes non visitées.
- **Revue de fin de lancement** : ce qui a bloqué devient un chantier (`/bugfix` ou `/feature`), comme ceux de Tiassalé.

---

## Liste de contrôle du jour J

- [ ] Créneau confirmé avec la direction la veille
- [ ] Enseignant inscrit, classe cochée, premier exercice assigné
- [ ] QR de la classe imprimé (et affiché au tableau)
- [ ] Téléphone de démonstration chargé, partage de connexion de secours
- [ ] Liste papier des élèves bloqués (nom, problème) — détruite après saisie, jamais photographiée
- [ ] Chiffres du jour relevés le soir dans l'espace équipe
