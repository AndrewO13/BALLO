<?php
declare(strict_types=1);

function ballo_share_preview(string $videoId): void
{
    $url = 'https://dcpltazuzyyhxtkpbuiu.supabase.co/functions/v1/share'
        . '?v=' . rawurlencode($videoId) . '&og=1';

    $html = ballo_fetch($url);
    if ($html === null || $html === '') {
        header('Content-Type: text/html; charset=utf-8');
        readfile(__DIR__ . '/index.html');
        return;
    }

    header('Content-Type: text/html; charset=utf-8');
    header('Cache-Control: private, no-store');
    header('X-LiteSpeed-Cache-Control: no-cache');
    echo $html;
}

function ballo_fetch(string $url, string $accept = 'text/html'): ?string
{
    if (function_exists('curl_init')) {
        $curl = curl_init($url);
        curl_setopt_array($curl, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_CONNECTTIMEOUT => 3,
            CURLOPT_TIMEOUT => 5,
            CURLOPT_HTTPHEADER => ['Accept: ' . $accept],
        ]);
        $body = curl_exec($curl);
        $status = (int) curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);
        if (is_string($body) && $status >= 200 && $status < 300) {
            return $body;
        }
        return null;
    }

    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'timeout' => 5,
            'header' => "Accept: {$accept}\r\n",
        ],
    ]);
    $body = @file_get_contents($url, false, $context);
    return is_string($body) ? $body : null;
}

function ballo_share_json(string $videoId): ?string
{
    $url = 'https://dcpltazuzyyhxtkpbuiu.supabase.co/functions/v1/share'
        . '?v=' . rawurlencode($videoId) . '&format=json';
    $raw = ballo_fetch($url, 'application/json');
    if ($raw === null || $raw === '') {
        return null;
    }
    $decoded = json_decode($raw, true);
    if (!is_array($decoded) || empty($decoded['video_url'])) {
        return null;
    }
    return json_encode($decoded, JSON_HEX_TAG | JSON_HEX_AMP | JSON_UNESCAPED_SLASHES);
}

if (isset($_GET['v']) && realpath((string) ($_SERVER['SCRIPT_FILENAME'] ?? '')) === realpath(__FILE__)) {
    $id = trim((string) $_GET['v']);
    if (preg_match('/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/', $id)) {
        ballo_share_preview($id);
    }
}

