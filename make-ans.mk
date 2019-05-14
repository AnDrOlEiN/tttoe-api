ans-development-setup-env:
	ansible-playbook ansible/development.yml -i ansible/development -vv

ans-get-docker-role:
	ansible-galaxy install nickjj.docker

ans-vaults-encrypt:
	ansible-vault encrypt ansible/production/group_vars/all/vault.yml ansible/group_vars/all/vault.yml

ans-vaults-decrypt:
	ansible-vault decrypt ansible/production/group_vars/all/vault.yml ansible/group_vars/all/vault.yml

ans-trf-vars:
	ansible-playbook ansible/terraform.yml -i ansible/development --ask-vault-pass
