-- SQL-Skript für MariaDB: Neue E-Mail-Tracking-Spalten hinzufügen
-- Führt die neuen Spalten für Duplikat-Schutz hinzu

-- Neue Spalte für E-Mail Message-ID (eindeutige E-Mail-Identifikation)
ALTER TABLE crm_entries 
ADD COLUMN email_message_id VARCHAR(255) NULL,
ADD INDEX idx_email_message_id (email_message_id);

-- Neue Spalte für Verarbeitungszeitpunkt
ALTER TABLE crm_entries 
ADD COLUMN email_processed_at DATETIME NULL DEFAULT CURRENT_TIMESTAMP;

-- Kommentare für die neuen Spalten
ALTER TABLE crm_entries 
MODIFY COLUMN email_message_id VARCHAR(255) NULL COMMENT 'E-Mail Message-ID für Duplikat-Schutz',
MODIFY COLUMN email_processed_at DATETIME NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Zeitpunkt der E-Mail-Verarbeitung';

-- Zeige die aktualisierte Tabellenstruktur
DESCRIBE crm_entries;


