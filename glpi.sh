#!/bin/bash

# Definindo variáveis
DB_NAME="glpi_db"
DB_USER="glpi_user"
DB_PASS="Senha"

# Atualizando o sistema
sudo apt update && sudo apt upgrade -y

# Instalando pacotes necessários (adicionados php-intl e php-bz2)
sudo apt install apache2 mariadb-server php php-mysql php-curl php-gd php-imap php-mbstring php-xml php-xmlrpc php-cli php-ldap php-zip php-bcmath php-intl php-bz2 unzip wget -y

# Habilitando e iniciando serviços
sudo systemctl enable apache2 --now
sudo systemctl enable mariadb --now

# Baixando GLPI 10.0.18
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/10.0.18/glpi-10.0.18.tgz

# Extraindo e movendo para o diretório do Apache
tar -xvzf glpi-10.0.18.tgz
sudo mv glpi /var/www/html/

# Ajustando permissões
sudo chown -R www-data:www-data /var/www/html/glpi
sudo chmod -R 755 /var/www/html/glpi

# Criando banco de dados e usuário no MariaDB usando as variáveis
sudo mysql -u root <<EOF
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Configurando o Apache para o GLPI
sudo cat > /etc/apache2/sites-available/glpi.conf << 'EOL'
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/html/glpi/public
    
    <Directory /var/www/html/glpi/public>
        Require all granted
        RewriteEngine On
        
        # Ensure authorization headers are passed to PHP
        # Some Apache configurations may filter them and break usage of API, CalDAV, ...
        RewriteCond %{HTTP:Authorization} ^(.+)$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
        
        # Redirect all requests to GLPI router, unless file exists
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/glpi_error.log
    CustomLog ${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOL

# Configurando session.cookie_httponly = on no php.ini
sudo sed -i 's/;session.cookie_httponly =/session.cookie_httponly = on/g' /etc/php/8.1/apache2/php.ini

# Habilitando o site GLPI e o módulo rewrite
sudo a2ensite glpi.conf
sudo a2dissite 000-default.conf
sudo a2enmod rewrite
sudo systemctl restart apache2

echo "Instalação do GLPI 10.0.18 finalizada!"
echo "Acesse http://seu_servidor/ para concluir a configuração via web."
