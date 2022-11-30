init:
	python3 -m venv .venv

update_deps:
	pip3 freeze > requirements.txt

install_deps:
	yarn global add ganache
	yarn install
	pip3 install -r requirements.txt

setup: install_deps
	brownie init --force

test:
	brownie test

compile:
	yarn run hardhat compile

fmt:
	yarn run prettier --write '{contracts,libraries,interfaces}/**/*.sol' && black tests

lint:
	yarn run prettier --list-different '{contracts,libraries,interfaces}/**/*.sol'
	black --check tests

generate_proofs:
	yarn run ts-node ./scripts/proof.ts

.PHONY: init update_deps install_deps setup test compile
