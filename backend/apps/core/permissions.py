from rest_framework.permissions import BasePermission

class EsAdmin(BasePermission):
    def has_permission(self, request, view):
        return getattr(request.user, "rol", None) == "admin"

class EsPrestador(BasePermission):
    def has_permission(self, request, view):
        return getattr(request.user, "rol", None) == "prestador"

class EsCliente(BasePermission):
    def has_permission(self, request, view):
        return getattr(request.user, "rol", None) == "cliente"
