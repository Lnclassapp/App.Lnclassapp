
# Identité
[user]
	name = "user"
	email = "user email"

# Branche par défaut
[init]
	defaultBranch = main

# Pull avec rebase (évite les merge commits inutiles)
[pull]
	rebase = true

# Éditeur VS Code
[core]
	editor = code --wait

# Coloration terminal
[color]
	ui = auto

# Aliases
[alias]
	st = status
	co = checkout
	br = branch
	sw = switch

	# Logs lisibles
	lg = log --oneline --graph --decorate --all
	last = log -1 HEAD --stat

	# Add + Commit en une commande
	ac = !git add -A && git commit -m

	# Corriger dernier commit
	amend = commit --amend --no-edit

	# Push branche courante
	psh = push origin HEAD

	# Pull rebase
	pl = pull --rebase origin

	# Undo dernier commit (garde les fichiers)
	undo = reset HEAD~1 --mixed

	# Fichiers modifiés seulement
	changed = diff --name-only

	# Stash rapide
	ss = stash save
	sp = stash pop

	# Nettoyer branches mergées
	cleanup = !git branch --merged | grep -v -E \"^[*+]|^ *(main|master|Develop|develop|Staging|staging)$\" | xargs -r git branch -d

	# Nouvelle branche depuis main à jour
	nb = !git switch main && git pull --rebase origin main && git switch -c

	# Revenir sur la branche main simplement
	com = !git checkout main
	# Revenir sur la branche Develop simplement
	cod = !git checkout Develop
	# Nouvelle branche simplement
	chout = !git checkout -b
	# Nouvelle branche depuis develop à jour + push immédiat
	cob = "!f() { git switch Develop && git pull --rebase --autostash origin Develop && git switch -c \"$1\" && git push -u origin \"$1\"; }; f"
	
	# Supprimer une branche en local
	brd = !git branch -d 

	# Supprimer une branche en remote
	brrd = !git push origin --delete 
	gpull = !git pull && graphify update .
