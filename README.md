## Tic-Tac-Toe API
  My first pet project developed with Elixir programming language
  
  Available on the http://tttoe.xyz (frontend part made with Unity by my buddy)
  
  To have a look on it locally first of all install Ansible, and then you can use:
  
  1. Docker and docker-compose
  
    make app-setup; make app
    
  2. Mix (you have to install Elixir and Erlang VM first)
  
    make app-setup in /
    
    cd services/app; make install; make start

 In this repo there are also few ansible playbooks and terraform files for creating enviroment files,
    setting up infrastructure, and deploying app. It's mostly for internal use
