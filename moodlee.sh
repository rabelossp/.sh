#!/bin/bash

# Variáveis
VERSAO="403"
DOMAIN="hml-cuidandodofuturo.fazeducacao.com.br"
CERTIFICADO="fazeducacao.com.br"
SENHADB="6yReVsn@63&5"
upload_max_filesize="2G"
post_max_size="2G"
memory_limit="2G"

# Alterando a prioridade de confirmação
echo "debconf/priority select critical" | sudo debconf-set-selections

# Atualize o sistema
sudo apt update
sudo apt upgrade -yqq

# Instale o servidor web Apache
sudo apt install apache2 -yqq

# Instale o banco de dados MySQL e PHP
sudo apt install mysql-server php8.1 php8.1-cli php8.1-gd php8.1-mysql php8.1-curl php8.1-zip php8.1-soap php8.1-xml php8.1-mbstring php8.1-intl php8.1-ldap php8.1-apcu libapache2-mod-php unzip git -yqq

# Habilitar módulos do Apache
sudo systemctl restart apache2

# Crie um banco de dados MySQL para o Moodle
sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS moodle_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -u root -e "CREATE USER IF NOT EXISTS 'moodle_user'@'localhost' IDENTIFIED BY '$SENHADB';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON moodle_db.* TO 'moodle_user'@'localhost';"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

# Clone o repositório do Moodle do Git
sudo git clone -b MOODLE_"$VERSAO"_STABLE git://git.moodle.org/moodle.git /var/www/html/moodle

# Criando a pasta moodledata
sudo mkdir /var/www/html/moodledata
sudo chown -R www-data:www-data /var/www/html/moodledata /var/www/html/moodle
sudo chmod -R 777 /var/www/html/moodledata /var/www/html/moodle

# Instalando certificado ssl
sudo a2enmod rewrite
sudo a2enmod ssl
sudo apt install openssl ssl-cert -yqq

# Adicione parâmetro ao weblib.php
sudo sed -i '/encodedurl = preg_replace.*href=\"\([^"]*\)\".*/d' /var/www/html/moodle/lib/weblib.php

# Adicione parâmetro ao php.ini
sudo sed -i "s/^;upload_max_filesize = .*/upload_max_filesize = $upload_max_filesize/" /etc/php/8.1/apache2/php.ini
sudo sed -i "s/^;max_file_uploads = .*/max_file_uploads = 200/" /etc/php/8.1/apache2/php.ini
sudo sed -i "s/^;post_max_size = .*/post_max_size = $post_max_size/" /etc/php/8.1/apache2/php.ini
sudo sed -i "s/^;memory_limit = .*/memory_limit = $memory_limit/" /etc/php/8.1/apache2/php.ini
sudo sed -i "s/^;max_input_vars = .*/max_input_vars = 5000/" /etc/php/8.1/apache2/php.ini
sudo sed -i "s/^;max_input_time = .*/max_input_time = 600/" /etc/php/8.1/apache2/php.ini
sudo sed -i "s/^;max_execution_time = .*/max_execution_time = 300/" /etc/php/8.1/apache2/php.ini

# Criando a configuração do apache2
sudo bash -c "cat <<EOF >/etc/apache2/sites-enabled/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/moodle

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    <Directory /var/www/html/moodle>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>

<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerAdmin suporte@vitaebrasil.com.br
    ServerName $DOMAIN
    DocumentRoot /var/www/html/moodle

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    SSLEngine on

    SSLCertificateFile /etc/apache2/ssl/$CERTIFICADO.pem
    SSLCertificateKeyFile /etc/apache2/ssl/$CERTIFICADO.key

    <FilesMatch \".(cgi|shtml|phtml|php)\">
        SSLOptions +StdEnvVars
    </FilesMatch>

    <Directory /usr/lib/cgi-bin>
        SSLOptions +StdEnvVars
    </Directory>
</VirtualHost>
</IfModule>
EOF"

# Concluído
echo "Instalação do Moodle concluída!"
