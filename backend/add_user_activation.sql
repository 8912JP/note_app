-- SQL-Migration: is_active Feld zur users Tabelle hinzufügen
-- Ausführung: Führen Sie dieses Skript in Ihrer Datenbank aus

-- Neues Feld hinzufügen
ALTER TABLE users ADD COLUMN is_active BOOLEAN DEFAULT FALSE;

-- Kommentar für das neue Feld
COMMENT ON COLUMN users.is_active IS 'Benutzer-Aktivierung: FALSE = inaktiv (kann sich nicht einloggen), TRUE = aktiv';

-- Bestehende Benutzer aktivieren (optional - nur wenn du möchtest)
-- UPDATE users SET is_active = TRUE WHERE username = 'julian';  -- Deaktiviert - nur bei Bedarf aktivieren

-- Bestätigung
SELECT 'is_active Feld erfolgreich zur users Tabelle hinzugefügt' as status;
SELECT 'Alle neuen Benutzer sind standardmäßig inaktiv' as info;
SELECT 'Aktivieren Sie Benutzer manuell in HeidiSQL mit: UPDATE users SET is_active = TRUE WHERE username = "benutzername";' as instruction;





