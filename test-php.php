<?php
// Einfacher PHP-Test
echo "PHP funktioniert!\n";
echo "Zeit: " . date('Y-m-d H:i:s') . "\n";
echo "Verzeichnis: " . getcwd() . "\n";

// Teste Datei-Schreibrechte
$testFile = 'test-write.log';
file_put_contents($testFile, "Test erfolgreich: " . date('Y-m-d H:i:s') . "\n");
echo "Datei-Schreibtest: " . (file_exists($testFile) ? "ERFOLGREICH" : "FEHLGESCHLAGEN") . "\n";

// Teste Socket-Verbindung
$host = 'localhost';
$port = 8000;
$socket = @stream_socket_client("tcp://$host:$port", $errno, $errstr, 5);
if ($socket) {
    echo "Gunicorn-Verbindung: ERFOLGREICH\n";
    fclose($socket);
} else {
    echo "Gunicorn-Verbindung: FEHLGESCHLAGEN - $errstr ($errno)\n";
}
?> 