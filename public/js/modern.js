/**
 * Módulo Moderno
 * Código JavaScript más reciente con mejores prácticas
 */

// API utilities como objeto global
window.apiUtils = {
    baseUrl: '/api',

    fetch: function(endpoint) {
        return fetch(this.baseUrl + endpoint)
            .then(function(response) {
                if (!response.ok) {
                    throw new Error('HTTP error ' + response.status);
                }
                return response.json();
            })
            .catch(function(error) {
                console.error('Fetch error:', error);
                throw error;
            });
    },

    post: function(endpoint, data) {
        return fetch(this.baseUrl + endpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        })
            .then(function(response) {
                return response.json();
            });
    },

    delete: function(endpoint) {
        return fetch(this.baseUrl + endpoint, {
            method: 'DELETE'
        })
            .then(function(response) {
                return response.json();
            });
    }
};

// Estado global de la aplicación
window.appState = {
    currentUser: null,
    isAuthenticated: false,

    setUser: function(user) {
        this.currentUser = user;
        this.isAuthenticated = true;
        this.notifyListeners();
    },

    logout: function() {
        this.currentUser = null;
        this.isAuthenticated = false;
        this.notifyListeners();
    },

    listeners: [],

    subscribe: function(callback) {
        this.listeners.push(callback);
    },

    notifyListeners: function() {
        this.listeners.forEach(function(callback) {
            callback(this);
        }.bind(this));
    }
};

// Helper global para UI
window.uiHelpers = {
    showLoading: function() {
        var loader = document.createElement('div');
        loader.id = 'loader';
        loader.className = 'loader';
        loader.textContent = 'Cargando...';
        document.body.appendChild(loader);
    },

    hideLoading: function() {
        var loader = document.getElementById('loader');
        if (loader) {
            loader.remove();
        }
    },

    showNotification: function(message, type) {
        var notification = document.createElement('div');
        notification.className = 'notification ' + (type || 'info');
        notification.textContent = message;
        document.body.appendChild(notification);

        setTimeout(function() {
            notification.remove();
        }, 3000);
    }
};
// Prueba de modificación
