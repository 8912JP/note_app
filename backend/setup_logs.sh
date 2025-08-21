#!/bin/bash

# Erstelle logs Verzeichnis falls es nicht existiert
mkdir -p logs

# Setze Berechtigungen
chmod 755 logs

echo "Logs-Verzeichnis erstellt: $(pwd)/logs"
