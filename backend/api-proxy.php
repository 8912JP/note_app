<?php
// API Proxy für FastAPI Backend
// Unterstützt sowohl HTTP als auch WebSocket-Verbindungen

// Error Reporting aktivieren
error_reporting(E_ALL);
ini_set('display_errors', 1);

// OPTIONS Preflight Request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    header('Access-Control-Allow-Origin: https://iqmedix.cloud');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, Upgrade, Connection, Sec-WebSocket-Key, Sec-WebSocket-Version, Sec-WebSocket-Protocol');
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Max-Age: 86400');
    exit;
}

// WebSocket Upgrade erkennen
if (isset($_SERVER['HTTP_UPGRADE']) && strtolower($_SERVER['HTTP_UPGRADE']) === 'websocket') {
    // WebSocket-Verbindung
    handleWebSocket();
} else {
    // HTTP-Verbindung
    handleHttp();
}

function handleHttp() {
    try {
        // Originale URL extrahieren
        $request_uri = $_SERVER['REQUEST_URI'];
        
        // /api/ entfernen und an FastAPI weiterleiten
        $api_path = preg_replace('/^\/api\//', '/', $request_uri);
        
        // FastAPI Server URL
        $fastapi_url = 'http://127.0.0.1:8000' . $api_path;
        
        // Request-Methode
        $method = $_SERVER['REQUEST_METHOD'];
        
        // Headers sammeln
        $headers = [];
        foreach ($_SERVER as $key => $value) {
            if (strpos($key, 'HTTP_') === 0) {
                $header_name = str_replace('HTTP_', '', $key);
                $header_name = str_replace('_', '-', strtolower($header_name));
                $headers[$header_name] = $value;
            }
        }
        
        // Content-Type und Authorization weiterleiten
        if (isset($_SERVER['CONTENT_TYPE'])) {
            $headers['content-type'] = $_SERVER['CONTENT_TYPE'];
        }
        
        // cURL Request vorbereiten
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $fastapi_url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 10);
        curl_setopt($ch, CURLOPT_HTTPHEADER, array_map(function($key, $value) {
            return "$key: $value";
        }, array_keys($headers), $headers));
        
        // Body für POST/PUT/PATCH
        if (in_array($method, ['POST', 'PUT', 'PATCH'])) {
            $input = file_get_contents('php://input');
            curl_setopt($ch, CURLOPT_POSTFIELDS, $input);
        }
        
        // Response Headers sammeln
        $response_headers = [];
        curl_setopt($ch, CURLOPT_HEADERFUNCTION, function($ch, $header) use (&$response_headers) {
            $response_headers[] = trim($header);
            return strlen($header);
        });
        
        // Request ausführen
        $response = curl_exec($ch);
        $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curl_error = curl_error($ch);
        curl_close($ch);
        
        // Fehlerbehandlung
        if ($response === false) {
            http_response_code(500);
            echo json_encode(['error' => 'FastAPI connection failed: ' . $curl_error]);
            return;
        }
        
        // Response Headers senden
        header('Access-Control-Allow-Origin: https://iqmedix.cloud');
        header('Access-Control-Allow-Credentials: true');
        foreach ($response_headers as $header) {
            if (!empty($header) && !str_starts_with($header, 'HTTP/')) {
                header($header);
            }
        }
        
        // HTTP Status Code setzen
        http_response_code($http_code);
        
        // Response Body senden
        echo $response;
        
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['error' => 'PHP Proxy Error: ' . $e->getMessage()]);
    }
}

function handleWebSocket() {
    try {
        // WebSocket Key aus Headers extrahieren
        $ws_key = $_SERVER['HTTP_SEC_WEBSOCKET_KEY'] ?? '';
        $ws_version = $_SERVER['HTTP_SEC_WEBSOCKET_VERSION'] ?? '';
        
        if (empty($ws_key)) {
            http_response_code(400);
            return;
        }
        
        // WebSocket Accept Key generieren
        $ws_accept = base64_encode(sha1($ws_key . '258EAFA5-E914-47DA-95CA-C5AB0DC85B11', true));
        
        // WebSocket Upgrade Response
        header('HTTP/1.1 101 Switching Protocols');
        header('Upgrade: websocket');
        header('Connection: Upgrade');
        header('Sec-WebSocket-Accept: ' . $ws_accept);
        
        // Token aus Query-Parameter extrahieren
        $token = $_GET['token'] ?? '';
        
        // FastAPI WebSocket URL mit Token
        $ws_path = '/ws/notes';
        if (!empty($token)) {
            $ws_path .= "?token=$token";
        }
        
        // WebSocket-Verbindung zu FastAPI aufbauen
        $context = stream_context_create();
        $socket = stream_socket_client('tcp://127.0.0.1:8000', $errno, $errstr, 30, STREAM_CLIENT_CONNECT, $context);
        
        if (!$socket) {
            http_response_code(500);
            return;
        }
        
        // WebSocket Handshake zu FastAPI senden
        $handshake = "GET $ws_path HTTP/1.1\r\n";
        $handshake .= "Host: 127.0.0.1:8000\r\n";
        $handshake .= "Upgrade: websocket\r\n";
        $handshake .= "Connection: Upgrade\r\n";
        $handshake .= "Sec-WebSocket-Key: " . $ws_key . "\r\n";
        $handshake .= "Sec-WebSocket-Version: " . $ws_version . "\r\n";
        $handshake .= "\r\n";
        
        fwrite($socket, $handshake);
        
        // Response von FastAPI lesen
        $response = '';
        while (!feof($socket)) {
            $response .= fread($socket, 1024);
            if (strpos($response, "\r\n\r\n") !== false) {
                break;
            }
        }
        
        // Bidirektionale Kommunikation
        $client_socket = fopen('php://input', 'r');
        
        // Non-blocking I/O
        stream_set_blocking($socket, false);
        stream_set_blocking($client_socket, false);
        
        // Proxy-Loop
        while (true) {
            // Von Client zu FastAPI
            $data = fread($client_socket, 1024);
            if ($data !== false && strlen($data) > 0) {
                fwrite($socket, $data);
            }
            
            // Von FastAPI zu Client
            $data = fread($socket, 1024);
            if ($data !== false && strlen($data) > 0) {
                echo $data;
                flush();
            }
            
            // Kurze Pause
            usleep(10000); // 10ms
        }
        
        fclose($socket);
        
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['error' => 'WebSocket Error: ' . $e->getMessage()]);
    }
}
?>