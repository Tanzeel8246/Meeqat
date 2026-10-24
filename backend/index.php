<?php
// Al-Meeqat Web Suite - Automatic Entry Point
if (file_exists(__DIR__ . '/public/index.php')) {
    header('Location: public/index.php');
    exit;
}
echo "Al-Meeqat Islamic Astronomical Suite Backend is Running.";
