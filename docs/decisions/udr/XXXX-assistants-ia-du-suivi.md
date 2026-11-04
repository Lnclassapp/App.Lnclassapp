# UDR-XXXX : Assistants IA du suivi — briefing, brouillon WhatsApp, rapport pour la direction, compte rendu dicté
<!-- index
titre: Assistants IA du suivi
statut: Proposé
adr-lie: XXXX-acces-aux-modeles-ia-par-openrouter
problematique: comment présenter quatre réponses d'IA lentes et faillibles comme des brouillons que l'humain relit, sur téléphone
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/crm-ecoles` |
| **ADR lié** | ADR-XXXX-acces-aux-modeles-ia-par-openrouter, ADR-XXXX-compte-rendu-dicte-fichier-son, ADR-XXXX-rapport-direction-en-pdf |
| **Remplacé par** | — |

---

## 1. Contexte

Une réponse de modèle prend de 3 à 60 secondes, peut échouer, et peut se tromper. Sur le terrain, la connexion est irrégulière. Les quatre assistants ne doivent ni bloquer la fiche, ni faire croire qu'un texte d'IA est un fait enregistré.

## 2. Décision

- **Un panneau par assistant, ouvert sur demande**, jamais au chargement de la fiche : un appel coûte.
- **Un seul motif d'attente pour les quatre** : un Turbo Frame qui interroge la demande toutes les 2 s (contrôleur Stimulus `ai-request`), au lieu d'une diffusion Action Cable (ADR lié, §3).
- **Chaque sortie est marquée « Brouillon IA — à relire »**, et le seul moyen de la rendre durable est un geste humain : copier, enregistrer le formulaire, télécharger.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Bloc « Assistants » de la fiche (`teams/relationships/_assistants.html.erb`)

- `ui_card title: "Assistants"`, `icon: "sparkles"`. Quatre boutons secondaires (`ui_button variant: :secondary`, icône, pleine largeur sur téléphone, grille 2×2 à partir de 768 px) :

| Bouton | Icône | Action |
|---|---|---|
| « Briefing » | `document-magnifying-glass` | `POST /teams/schools/:school_id/ai_requests` `purpose=briefing` |
| « Brouillon WhatsApp » | `chat-bubble-bottom-center-text` | ouvre la modale §3.4 |
| « Rapport direction » | `document-text` | ouvre la modale §3.5 |
| « Dicter le compte rendu » | `microphone` | ouvre la modale §3.6 |

- Sous les boutons, `text-xs text-mute` : « Les assistants envoient des données de l'école à un service d'IA externe, qui ne les conserve pas. »
- Cible unique des réponses : `turbo-frame id="relationship_assistant"`, placée sous la carte. Un nouveau panneau remplace le précédent.

### 3.2 Panneau d'attente commun (`teams/ai_requests/_pending.html.erb`)

- `<turbo-frame id="relationship_assistant">` contenant `ui_card` avec `ui_loading_state variant: :skeleton, lines: 4, label: "Préparation du briefing…"` (libellé selon l'usage).
- `data-controller="ai-request"`, `data-ai-request-url-value="/teams/ai_requests/:public_id"`, `data-ai-request-interval-value="2000"`, `data-ai-request-max-value="45"`. Le contrôleur fait `frame.src = url` à chaque intervalle tant que la réponse est `_pending`, et s'arrête au premier panneau final ou après 45 essais (il affiche alors l'état d'erreur `timeout` de §3.7).
- `aria-busy="true"` sur le frame pendant l'attente, et un `role="status"` texte masqué « Préparation en cours ».
- Bouton « Annuler » (lien qui vide le frame, la demande continue côté serveur).

### 3.3 Briefing (`_briefing.html.erb`)

- `ui_card` titre « Briefing — Lycée X », badge `ui_badge "Brouillon IA — à relire", tone: :warning, size: :sm`.
- Texte rendu en paragraphes et listes à partir d'un **Markdown restreint** (titres `##`, listes `-`, gras) converti côté serveur par une fonction qui échappe tout le reste ; jamais de HTML du modèle.
- Pied : « Généré le 4 nov., 14:20 », bouton « Régénérer » (nouvelle demande), bouton `ui_copy_button` « Copier ».

### 3.4 Brouillon WhatsApp (`ui_modal id: "whatsapp_draft_modal"`)

- Champs : interlocuteur (prérempli avec le dernier interlocuteur du journal), objet (`ui_radio_group` : « Relance après démo », « Relance d'inactivité », « Prise de rendez-vous », « Autre » + texte libre ≤ 200). Bouton « Rédiger ».
- Résultat dans `#relationship_assistant` : textarea éditable (8 lignes, ≤ 1 000 caractères, compteur), badge brouillon, `ui_copy_button` « Copier le message » (toast « Message copié »). **Aucun bouton d'envoi**, aucun lien `wa.me`.

### 3.5 Rapport pour la direction (`ui_modal id: "director_report_modal"`, `size: :lg`)

- Étape 1 : période (`ui_radio_group` : « 30 derniers jours » par défaut, « Ce trimestre », « Cette année scolaire »). Bouton « Préparer le rapport ».
- Étape 2, dans `#relationship_assistant` (pleine largeur) : formulaire `POST /teams/schools/:school_id/director_report.pdf` avec quatre textareas éditables, préremplis, chacune avec son titre : « Synthèse », « Usage par classe », « Élèves à suivre », « Recommandations » (total ≤ 20 000 caractères, compteur global). Avertissement `bg-warning-soft` : « Ce rapport cite des élèves. Ne le transmettez qu'à la direction de l'école. »
- Bouton primaire « Télécharger le PDF » (`data-turbo="false"`, le navigateur reçoit le fichier) ; après l'envoi, un `ui_toast` « Rapport gardé dans le journal » et le journal se recharge (lien Turbo Frame).

### 3.6 Compte rendu dicté (`ui_modal id: "dictation_modal"`)

- Texte : « Enregistrez votre compte rendu avec l'enregistreur du téléphone (3 minutes au plus), puis choisissez le fichier. »
- `input type="file" accept="audio/mpeg,audio/mp4,audio/x-m4a,.mp3,.m4a" capture` dans `ui_field`, `hint: "MP3 ou M4A, 5 Mo et 3 minutes au plus"`.
- Contrôle navigateur (Stimulus `audio-recorder` : taille, durée lue par un élément `<audio>`), message inline avant envoi ; le serveur mesure toujours (ADR lié).
- Bouton « Transcrire » → demande `purpose=dictation` ; attente §3.2 avec « Transcription… ».
- Résultat : la modale « Noter un échange » (UDR-XXXX-suivi-des-ecoles §3.7) **pré-remplie**, ouverte dans `#relationship_assistant` en formulaire en ligne. Bandeau `bg-warning-soft` « Pré-rempli par l'IA — vérifiez chaque champ avant d'enregistrer », et chaque champ rempli par l'IA est entouré `ring-1 ring-warning` jusqu'à ce que l'utilisateur le touche. Rien n'est enregistré avant « Enregistrer ».

### 3.7 États obligatoires

| État | Rendu |
|---|---|
| Vide | Pas de panneau : le frame `#relationship_assistant` est vide tant qu'on n'a rien demandé |
| Chargement | §3.2 |
| Erreur `unavailable` / `refused` | `ui_error_state title: "L'assistant ne répond pas", message: "Le suivi fonctionne sans lui. Réessayez dans un moment."`, bouton « Réessayer » (nouvelle demande, même paramètres) |
| Erreur `timeout` | même composant, `title: "L'assistant a mis trop de temps"` |
| Erreur `budget_exhausted` | `ui_error_state title: "Budget du mois atteint"`, sans « Réessayer » ; texte « Prévenez un administrateur. » |
| Quota du jour | `ui_error_state title: "Limite du jour atteinte"`, « Revenez demain. » sans « Réessayer » |
| Fichier son refusé (422) | erreur inline sous le champ fichier, motif exact (« Fichier de plus de 3 minutes »…), `aria-invalid` |
| Sortie illisible (dictée) | `ui_toast type: :error` « Le compte rendu n'a pas pu être lu, notez l'échange à la main » et formulaire d'échange vide ouvert |
| Succès | §3.3 à §3.6 |

### 3.8 Accessibilité

- Boutons ≥ 48 px de haut ; les quatre boutons ont un libellé texte (pas d'icône seule).
- Pendant l'attente : `aria-busy`, `role="status"` ; à l'arrivée du résultat, focus déplacé sur le titre du panneau (`tabindex="-1"`).
- Le badge « Brouillon IA — à relire » est du texte, pas une couleur seule.
- Champs pré-remplis par l'IA : `aria-describedby` vers le bandeau d'avertissement.

### 3.9 Textes

`config/locales/fr.yml` sous `teams.assistants.*`, `teams.ai_requests.*`, `teams.dictations.*`, `teams.director_reports.*`.

## 4. Conséquences

- Tout futur assistant IA réutilise le panneau d'attente §3.2, le badge brouillon et la table d'états §3.7.
- Aucune sortie d'IA n'est rendue comme HTML brut, nulle part.
- Le compte rendu dicté dépend du formulaire d'échange de l'UDR-XXXX-suivi-des-ecoles : ce dernier doit accepter des valeurs initiales.
