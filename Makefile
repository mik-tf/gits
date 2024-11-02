build:
	bash gits.sh install

rebuild:
	gits uninstall
	bash gits.sh install
	
delete:
	gits uninstall