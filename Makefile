build:
	bash gits.sh install
	gits help

rebuild:
	gits uninstall
	bash gits.sh install
	gits help
	
delete:
	gits uninstall