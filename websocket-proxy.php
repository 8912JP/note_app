<?php
// WebSocket-Proxy für die Anwendung
header('Content-Type: text/plain');

// Prüfe ob es sich um eine WebSocket-Upgrade-Anfrage handelt
if (!isset($_SERVER['HTTP_UPGRADE']) || strtolower($_SERVER['HTTP_UPGRADE']) !== 'websocket') {
    http_response_code(400);
    die('Keine WebSocket-Upgrade-Anfrage');
}

// Prüfe Connection-Header
if (!isset($_SERVER['HTTP_CONNECTION']) || strpos(strtolower($_SERVER['HTTP_CONNECTION']), 'upgrade') === false) {
    http_response_code(400);
    die('Kein Connection: Upgrade Header');
}

// Prüfe Sec-WebSocket-Key
if (!isset($_SERVER['HTTP_SEC_WEBSOCKET_KEY'])) {
    http_response_code(400);
    die('Kein Sec-WebSocket-Key');
}

// Prüfe Sec-WebSocket-Version
if (!isset($_SERVER['HTTP_SEC_WEBSOCKET_VERSION']) || $_SERVER['HTTP_SEC_WEBSOCKET_VERSION'] !== '13') {
    http_response_code(400);
    die('Unsupported WebSocket version');
}

// Hole den WebSocket-Key
$secWebSocketKey = $_SERVER['HTTP_SEC_WEBSOCKET_KEY'];

// Generiere die Accept-Antwort
$secWebSocketAccept = base64_encode(sha1($secWebSocketKey . '258EAFA5-E914-47DA-95CA-C5AB0DC85B11', true));

// Sende die WebSocket-Upgrade-Antwort
header('HTTP/1.1 101 Switching Protocols');
header('Upgrade: websocket');
header('Connection: Upgrade');
header('Sec-WebSocket-Accept: ' . $secWebSocketAccept);

// Flushe die Header
if (function_exists('fastcgi_finish_request')) {
    fastcgi_finish_request();
} else {
    ob_end_flush();
    flush();
}

// Hole den Token aus der URL und bestimme den WebSocket-Pfad
$requestUri = $_SERVER['REQUEST_URI'];
$token = null;
if (preg_match('/token=([^&]+)/', $requestUri, $matches)) {
    $token = $matches[1];
}

if (!$token) {
    die('Kein Token gefunden');
}

// Bestimme den WebSocket-Pfad basierend auf der Anfrage
$wsPath = '/ws/notes'; // Standard
if (strpos($requestUri, '/ws/crm') !== false) {
    $wsPath = '/ws/crm';
}

// Starte die WebSocket-Verbindung zu Gunicorn
$host = 'localhost'; // Gunicorn-Server
$port = getenv('GUNICORN_PORT') ?: 8000; // Port aus Umgebungsvariable oder Standard

// Erstelle eine Socket-Verbindung zum Gunicorn-Server
$socket = stream_socket_client("tcp://$host:$port", $errno, $errstr, 30);

if (!$socket) {
    error_log("WebSocket-Proxy: Fehler beim Verbinden zu $host:$port - $errstr ($errno)");
    file_put_contents('websocket-debug.log', "FEHLER: Verbindung zu $host:$port fehlgeschlagen - $errstr ($errno)\n", FILE_APPEND);
    http_response_code(500);
    die("Fehler beim Verbinden zum Gunicorn-Server: $errstr ($errno)");
}

// Debug: Log die Verbindung
error_log("WebSocket-Proxy: Verbindung zu $host:$port erfolgreich");
error_log("WebSocket-Proxy: Token: $token");
error_log("WebSocket-Proxy: Pfad: $wsPath");

// Schreibe Debug-Info in Datei
file_put_contents('websocket-debug.log', "=== WebSocket-Verbindung ===\n", FILE_APPEND);
file_put_contents('websocket-debug.log', "Zeit: " . date('Y-m-d H:i:s') . "\n", FILE_APPEND);
file_put_contents('websocket-debug.log', "Host: $host:$port\n", FILE_APPEND);
file_put_contents('websocket-debug.log', "Token: $token\n", FILE_APPEND);
file_put_contents('websocket-debug.log', "Pfad: $wsPath\n", FILE_APPEND);

// Sende HTTP-Upgrade-Anfrage an Gunicorn/FastAPI
$secWebSocketKey = base64_encode(random_bytes(16));
$upgradeRequest = "GET $wsPath?token=$token HTTP/1.1\r\n";
$upgradeRequest .= "Host: localhost:$port\r\n";
$upgradeRequest .= "Upgrade: websocket\r\n";
$upgradeRequest .= "Connection: Upgrade\r\n";
$upgradeRequest .= "Sec-WebSocket-Key: $secWebSocketKey\r\n";
$upgradeRequest .= "Sec-WebSocket-Version: 13\r\n";
$upgradeRequest .= "Origin: https://iqmedix.cloud\r\n";
$upgradeRequest .= "\r\n";

fwrite($socket, $upgradeRequest);

// Warte auf die Antwort von Gunicorn
$response = '';
while (($line = fgets($socket)) !== false) {
    $response .= $line;
    if (trim($line) === '') {
        break; // Ende der Header
    }
}

// Debug: Log die Antwort
error_log("WebSocket-Proxy: Gunicorn-Antwort: $response");
file_put_contents('websocket-debug.log', "Gunicorn-Antwort: $response\n", FILE_APPEND);

// Prüfe ob die Upgrade-Anfrage erfolgreich war
if (strpos($response, '101 Switching Protocols') === false) {
    error_log("WebSocket-Proxy: Gunicorn hat Upgrade abgelehnt: $response");
    http_response_code(500);
    die("Gunicorn hat WebSocket-Upgrade abgelehnt: $response");
}

// Bidirektionale Kommunikation
$read = [$socket, STDIN];
$write = null;
$except = null;

while (true) {
    $changed = stream_select($read, $write, $except, 0, 200000); // 0.2 Sekunden Timeout
    
    if ($changed === false) {
        break;
    }
    
    if ($changed > 0) {
        foreach ($read as $stream) {
            if ($stream === $socket) {
                // Daten vom WebSocket-Server
                $data = fread($socket, 8192);
                if ($data === false || $data === '') {
                    break 2; // Verbindung geschlossen
                }
                
                // Sende an den Client
                echo $data;
                flush();
            } elseif ($stream === STDIN) {
                // Daten vom Client
                $data = fread(STDIN, 8192);
                if ($data === false || $data === '') {
                    break 2; // Verbindung geschlossen
                }
                
                // Sende an den WebSocket-Server
                fwrite($socket, $data);
            }
        }
    }
}

// Schließe die Verbindung
fclose($socket);
?> 