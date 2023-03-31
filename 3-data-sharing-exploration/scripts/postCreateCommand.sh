#!/bin/bash
python -m pip install --upgrade pip
pip install -r src/requirements.txt

sudo curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo touch /etc/apt/sources.list.d/mssql-release.list
sudo chmod 777 /etc/apt/sources.list.d/mssql-release.list
sudo curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list

sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql17
sudo ACCEPT_EULA=Y apt-get install -y unixodbc-dev