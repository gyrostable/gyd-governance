init:
	python3 -m venv .venv

update_deps:
	pip3 freeze > requirements.txt

install_deps:
	yarn global add ganache-cli
	yarn install
	pip3 install -r requirements.txt

setup: install_deps
	brownie init --force

test:
	brownie test

.PHONY: init update_deps install_deps setup test
