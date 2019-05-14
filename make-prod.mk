production-setup:
	ansible-playbook ansible/site.yml -i ansible/production  --ask-vault-pass

production-env-update:
	ansible-playbook ansible/site.yml -i ansible/production --tag env --ask-vault-pass

production-deploy:
	ansible-playbook ansible/deploy.yml -i ansible/production --ask-vault-pass

production-deploy-app:
	ansible-playbook ansible/deploy.yml -i ansible/production --tag app --ask-vault-pass
