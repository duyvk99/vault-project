#!/bin/bash

export VAULT_ADDR="https://vault.dtsdemo.com/"
export VAULT_TOKEN=""
project="project"
env="uat"
path="secret"


for file in ${project}-${env}/*.json
do
    service=$(echo $file | sed 's/.json//g' | sed "s/${project}-${env}\///g")
    echo $service
    vault kv put -mount=$path $project/$env/$service  @$file
done
