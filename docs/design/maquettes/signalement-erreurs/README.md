# Lnclass — Signalement d'erreurs

Ce module permet à un enseignant de cocher des mots ou des expressions erronés sur une fiche. Il envoie ensuite le signalement à l'équipe Lnclass.

## Fonctionnement
1. L'enseignant clique sur le bouton **« Signaler une erreur »**, en bas à droite de la fiche.
2. En mode relecture, il clique sur un mot ou sélectionne une expression : le passage est surligné et ajouté à la liste. Un nouveau clic le retire.
3. Pour chaque élément, il peut proposer une correction. Il peut aussi ajouter un commentaire général, ainsi que son nom et son établissement.
4. Le bouton **« Signaler à l'équipe Lnclass »** envoie le rapport. Ce rapport contient le texte coché, la page et la section, la phrase de contexte et la correction proposée.

Sur téléphone, le panneau s'ouvre en tiroir en bas de l'écran.

## Intégration
Ajouter une ligne avant `</body>` :

```html
<script src="lnclass-signalement.js"
        data-email="contact@lnclass.com"
        data-fiche="La propriété de Thalès (Maths 3e)"
        data-zone="main"></script>
```

| Attribut | Rôle |
|---|---|
| `data-email` | Adresse qui reçoit les signalements |
| `data-fiche` | Nom de la fiche, repris dans le rapport |
| `data-zone` | Sélecteur CSS de la zone que l'enseignant peut relire (par défaut : `body`) |
| `data-endpoint` | Facultatif : URL de l'API Lnclass. Si elle est renseignée, le rapport est envoyé en `POST` JSON. Sinon, la messagerie s'ouvre et le rapport est copié dans le presse-papiers. |

Exemple de JSON envoyé à `data-endpoint` :
```json
{ "fiche": "...", "url": "...", "enseignant": "...", "commentaire": "...",
  "elements": [{ "texte": "sécantes", "emplacement": "1. L'énoncé", "contexte": "...", "correction": "..." }],
  "rapport": "texte complet" }
```

Le module expose aussi une API JavaScript : `window.LnclassSignalement.open()`, `.close()` et `.getReport()`.

Le module n'a aucune dépendance. Ouvrez `demo.html` pour le tester.
