<?php /* Este archivo es un template JS legacy que requiere PHP */ ?>
/**
 * Aplicación principal
 * Este archivo simula un template JS con PHP del monolito legacy
 */

window.globalInit = function() {
    console.log('Inicializando aplicación...');

    // Configuración global
    window.appConfig = {
        apiUrl: '/api',
        version: '1.0.0',
        debug: true
    };

    // Event listeners globales
    document.addEventListener('DOMContentLoaded', function() {
        console.log('DOM cargado');
        initializeComponents();
    });
};

function initializeComponents() {
    var content = document.getElementById('content');
    if (content) {
        content.innerHTML = '<p>Componentes inicializados</p>';
    }
}

// Función global para manejo de errores (patrón legacy)
window.handleError = function(error) {
    console.error('Error:', error);
    alert('Ha ocurrido un error: ' + error.message);
};

// Utilidad global legacy
window.utils = {
    formatCurrency: function(amount) {
        return '$' + amount.toFixed(2);
    },

    validateForm: function(formId) {
        var form = document.getElementById(formId);
        if (!form) return false;

        var inputs = form.getElementsByTagName('input');
        for (var i = 0; i < inputs.length; i++) {
            if (inputs[i].value === '') {
                return false;
            }
        }
        return true;
    }
};
