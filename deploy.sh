#!/bin/bash
az group create --location westeurope --name mz-nestedHyperV
az deployment group create --resource-group mz-nestedHyperV --template-file azure-deploy.json 