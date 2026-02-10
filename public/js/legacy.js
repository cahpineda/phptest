<?php
// Template legacy con PHP inline
$jsConfig = ['timeout' => 5000, 'retries' => 3];
?>
/**
 * Módulo Legacy
 * Código JavaScript antiguo del monolito
 */

// Variable global legacy
window.LEGACY_MODE = true;

// Función global para AJAX legacy
window.legacyAjax = function(url, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, true);

    xhr.onreadystatechange = function() {
        if (xhr.readyState === 4) {
            if (xhr.status === 200) {
                callback(null, xhr.responseText);
            } else {
                callback(new Error('Request failed: ' + xhr.status));
            }
        }
    };

    xhr.send();
};

// Utilidades globales del sistema legacy
window.legacyUtils = {
    parseJSON: function(str) {
        try {
            return JSON.parse(str);
        } catch(e) {
            console.error('JSON parse error:', e);
            return null;
        }
    },

    getCookie: function(name) {
        var value = '; ' + document.cookie;
        var parts = value.split('; ' + name + '=');
        if (parts.length === 2) {
            return parts.pop().split(';').shift();
        }
        return null;
    },

    setCookie: function(name, value, days) {
        var expires = '';
        if (days) {
            var date = new Date();
            date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
            expires = '; expires=' + date.toUTCString();
        }
        document.cookie = name + '=' + value + expires + '; path=/';
    }
};

// Función global para debugging
window.debugLog = function(message) {
    if (window.appConfig && window.appConfig.debug) {
        console.log('[DEBUG]', message);
    }
};
