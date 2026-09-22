<?php
declare(strict_types=1);

$id = isset($_GET['v']) ? trim((string) $_GET['v']) : '';
$play = isset($_GET['play']) ? (string) $_GET['play'] : '';
$ua = (string) ($_SERVER['HTTP_USER_AGENT'] ?? '');
$crawler = '/WhatsApp|facebookexternalhit|Facebot|Twitterbot|Slackbot|TelegramBot|Discordbot|LinkedInBot|Pinterest|Googlebot|bingbot|Applebot|Iframely|Embedly|SkypeUriPreview|vkShare|redditbot|Slack-ImgProxy/i';

if (
    $play !== '1'
    && $id !== ''
    && preg_match('/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/', $id)
    && preg_match($crawler, $ua)
) {
    require __DIR__ . '/share-preview.php';
    ballo_share_preview($id);
    exit;
}

header('Content-Type: text/html; charset=utf-8');
readfile(__DIR__ . '/index.html');
