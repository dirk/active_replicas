#!/bin/bash

mysql -u root <<SQL
  CREATE DATABASE IF NOT EXISTS active_replicas;
  USE active_replicas;

  DROP TABLE IF EXISTS users;
  CREATE TABLE users (id INTEGER PRIMARY KEY AUTO_INCREMENT, email VARCHAR(255));
SQL
