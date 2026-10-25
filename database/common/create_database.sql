-- =====================================================================
-- common/create_database.sql
-- Creates a fresh warranty_engine database. Run first.
-- Creates a fresh database for the Warranty Management and Service Engine.
-- =====================================================================
DROP DATABASE IF EXISTS warranty_engine;
CREATE DATABASE warranty_engine
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE warranty_engine;
