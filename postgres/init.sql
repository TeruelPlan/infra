-- Création des bases de données PlanTogether
-- Exécuté automatiquement au premier démarrage de PostgreSQL

CREATE DATABASE plantogether_trip;
CREATE DATABASE plantogether_poll;
CREATE DATABASE plantogether_destination;
CREATE DATABASE plantogether_expense;
CREATE DATABASE plantogether_task;
CREATE DATABASE plantogether_chat;
CREATE DATABASE plantogether_notification;
CREATE DATABASE keycloak;

-- L'utilisateur postgres a déjà tous les droits sur ces bases.
-- En production, créer des utilisateurs dédiés par service.
