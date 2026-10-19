# UDR-0100 : Un enseignant partagé vu par chaque direction — sa seule part dans « Enseignants », « Enseignants retirés » et l'activité, une phrase sous le lien d'invitation
<!-- index
titre: Un enseignant partagé vu par chaque direction — sa seule part dans « Enseignants », « Enseignants retirés » et l'activité, une phrase sous le lien d'invitation
statut: Accepté *(porteur, 2026-10-16)*
adr-lie: [0094](../adr/0094-enseignant-multi-etablissements-et-etablissement-courant.md)
problematique: Aucune mention d'un autre établissement dans les écrans de la direction (consigne négative, testée) ; « Enseignants retirés » montre aussi l'enseignant parti ailleurs, « Réintégrer » le rattache en plus de ses autres établissements, refus au plafond par un toast neutre ; phrase d'aide sous le lien d'invitation de la direction ; badge « Établissement secondaire » de la fiche équipe inchangé. Amende UDR-0056 §3.3, §3.4 et UDR-0079 §3.7
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16) |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/multi-etablissements-enseignant`](../../chantiers/multi-etablissements-enseignant/prd.md) — critères ME-17 à ME-22 |
| **ADR lié** | [ADR-0094](../adr/0094-enseignant-multi-etablissements-et-etablissement-courant.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Un enseignant de deux établissements apparaît chez deux directions. Chacune doit le gérer comme aujourd'hui (le voir, le retirer, le réintégrer) **sans rien apprendre de l'autre établissement** : ni son nom, ni ses classes, ni ses devoirs. Deux écrans de la direction supposent aujourd'hui un seul établissement :

- « Enseignants retirés » cache un enseignant dès qu'il a un établissement ailleurs, et « Réintégrer » le refuse (ADR-0071) ;
- le lien d'invitation de la direction (UDR-0079 §3.7) ne dit pas qu'il sert aussi à un enseignant déjà inscrit ailleurs : la direction pense devoir demander un nouveau compte.

## 2. Décision

- **Rien ne change à l'écran pour un enseignant partagé** dans « Accueil », « Enseignants », la confirmation du retrait et l'activité : il est un enseignant de l'établissement, avec ses classes de l'établissement. Pas de badge « partagé » : il dirait qu'il existe un autre établissement, ce que le porteur ne veut pas montrer (memo, question 4).
- **« Enseignants retirés » liste tous les départs ouverts**, que l'enseignant ait un autre établissement ou non. La ligne ne change pas.
- **Une phrase sous le lien d'invitation** suffit à faire comprendre le nouveau parcours ; aucun bouton ni écran nouveau pour la direction.

## 3. Règles d'implémentation

> Contrat d'exécution. Clés de locale sous `school_admin.*` existantes.

### 3.1 Consigne négative (tous les écrans de la direction)

Dans `school_admin/**` (accueil, niveaux, classes, « Enseignants », confirmation « Retirer », « Enseignants retirés », activité, établissement), **aucun** élément ne nomme, ne compte ni ne signale un autre établissement d'un enseignant. Les classes affichées pour un enseignant sont celles de l'établissement de la direction, de l'année, actives (`SchoolTeachersQuery`, inchangée). Un test système par écran le vérifie (ME-17 à ME-19).

### 3.2 « Enseignants » et « Retirer » — UDR-0056 §3.3 inchangée

- La ligne, le menu ⋮ et la modale de confirmation restent ceux de l'UDR-0056 §3.3. Le texte « <Prénom> ne verra plus l'établissement ni ses classes » reste exact : il garde ses autres établissements sans que la direction le sache.

### 3.3 « Enseignants retirés » — amende l'UDR-0056 §3.4

- La liste montre **chaque départ ouvert** de l'établissement dont l'enseignant n'est pas anonymisé et n'est plus rattaché à cet établissement, **qu'il ait ou non un autre établissement**. La ligne (nom, matière, « Retiré le … », « Réintégrer ») ne change pas.
- « Réintégrer » :
  - **succès** : comme aujourd'hui (toast « <Nom> est de nouveau dans l'établissement et doit redéclarer ses classes. », `school_admin.teacher_reinstatements.create.done`) ;
  - **plafond atteint** (`:conflict` `schools_limit`) : toast `:error` « <Prénom> ne peut pas être réintégré pour l'instant : il a atteint le nombre d'établissements autorisé. », la ligne reste.

### 3.4 Lien d'invitation de la direction — amende l'UDR-0079 §3.7

Dans `school_admin/schools/_link`, sous le lien (`#school_link_value`) et avant les boutons :

```
p#school_link_hint.mt-2.text-sm.text-mute
  → « Un enseignant déjà inscrit dans un autre établissement l'ouvre aussi pour vous rejoindre, sans nouveau compte. »
```

Le message de partage WhatsApp ne change pas.

### 3.5 Activité de l'établissement

- Un enseignant qui **rejoint** l'établissement par « Mes établissements » ou par le lien produit l'événement `teacher_joined` existant (« <enseignant> a rejoint l'établissement », `teacher_joined`). Aucun libellé nouveau.
- Un enseignant qui **quitte** l'établissement n'y produit aucun événement (l'activité ne montre pas les départs, comme aujourd'hui pour les retraits).

### 3.6 Fiche d'un établissement côté équipe — inchangée

Le badge « Établissement secondaire » (`teams/schools/show`, UDR-0079 §3.8), déjà en place, s'affiche désormais pour un enseignant dont ce n'est pas l'établissement principal. L'équipe voit tout : aucune consigne négative de son côté.

### États obligatoires

- **Vide** (« Enseignants retirés » sans départ) : état vide existant.
- **Erreur** : toasts §3.3.
- **Succès** : toasts existants.

### Accessibilité

- `#school_link_hint` est lié au lien par `aria-describedby="school_link_hint"` sur `#school_link_value`.
- Rien d'autre ne change : les règles de l'UDR-0056 s'appliquent.

## 4. Conséquences

- La direction ne voit jamais qu'un enseignant est partagé. Elle peut donc retirer un enseignant sans savoir qu'il continue ailleurs : c'est voulu.
- Le refus « nombre d'établissements autorisé » dit qu'il en a d'autres, sans les nommer : seul écart à la consigne négative, accepté parce que la direction doit comprendre pourquoi « Réintégrer » échoue.
- Les captures du Lot C montrent « Établissement » (phrase sous le lien) et « Enseignants retirés » avec un enseignant parti ailleurs, à 390 px et sur ordinateur.
