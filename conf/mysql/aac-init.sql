CREATE DATABASE aac;

CREATE USER 'ac'@'%' IDENTIFIED BY 'ac';
GRANT ALL PRIVILEGES ON aac.* TO 'ac'@'%';

FLUSH PRIVILEGES;
